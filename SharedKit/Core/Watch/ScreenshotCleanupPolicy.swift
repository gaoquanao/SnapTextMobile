import Foundation
import Photos

/// 截图清理策略：静默归档成功后，是否把相册中的源截图删除，改由拾文保管。
///
/// **适用范围（仅静默通道）**：
/// - 相册自动收集（PhotoWatchService）
/// - 控制中心控件「归档最近截图」
/// - 快捷指令「静默归档」（未传截图、由 App 自行取相册最新截图的兜底路径）
///
/// 带界面的流程（分享扩展、大爆炸选取、手动导入）不在此策略内——用户正在
/// 交互的图片不动。默认关闭，需在设置页显式开启；
/// iOS 规定删除必须经系统弹窗确认，删除后进入「最近删除」保留 30 天。
enum ScreenshotCleanupPolicy {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.autoDeleteScreenshots)
    }

    /// 对本次成功归档的相册资产执行清理；返回实际删除的数量（未开启 / 用户取消 / 失败均为 0）。
    @discardableResult
    static func run(assetIDs: [String]) async -> Int {
        guard isEnabled else { return 0 }
        let unique = Array(Set(assetIDs))
        guard !unique.isEmpty else { return 0 }
        let deleted = await PhotoLibraryHelper.deleteAssets(withLocalIdentifiers: unique)
        return deleted ? unique.count : 0
    }

    /// 组装监控运行摘要（含清理计数）。
    static func summary(archived: Int, skipped: Int, cleaned: Int) -> String {
        var text = String(localized: "新增 \(archived) 条，跳过 \(skipped) 张")
        if cleaned > 0 {
            text += " · " + String(localized: "已清理 \(cleaned) 张")
        }
        return text
    }
}
