import AppIntents
import UIKit

/// 备选路径：不依赖快捷指令「截屏」动作，直接处理相册最新一张截图并弹出大爆炸。
/// 编译进主 App 与控件扩展：控件扩展用它作为「操作按钮/控制中心」的开箱即用入口，
/// `openAppWhenRun` 使其被调用时由系统拉起主 App 执行。
struct SnapLatestScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "大爆炸识别最近截图"
    static let description = IntentDescription("读取相册中最新的一张截图进行识别，并弹出大爆炸选取界面。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let asset = try await PhotoLibraryHelper.latestScreenshotAsset(),
              let latest = try await PhotoLibraryHelper.image(for: asset) else {
            throw SnapIntentError.noScreenshot
        }
        CaptureBus.shared.enqueue(latest)
        return .result()
    }
}
