import AppIntents
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

/// 控制中心控件：一键归档相册中最近一张截图（配方可 B 的免设置替代）。
/// Intent 在控件扩展进程内执行，直接走共享管线入库；打开 App 即可看到新归档。
struct SnapArchiveControlIntent: AppIntent {
    static let title: LocalizedStringResource = "归档最近截图"
    static let description = IntentDescription("识别相册最近一张截图并自动归档。")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let asset = try await PhotoLibraryHelper.latestScreenshotAsset(),
              let latest = try await PhotoLibraryHelper.image(for: asset) else {
            throw SnapIntentError.noScreenshot
        }
        let outcome = try await CapturePipeline.capture(image: latest, source: .control)
        // 静默通道：按清理策略移除源截图（默认关闭，开启时由系统弹窗确认）。
        await ScreenshotCleanupPolicy.run(assetIDs: [asset.localIdentifier])
        return .result(value: String(localized: "已归档：\(outcome.entry.title)"))
    }
}

struct SnapArchiveControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.snaptext.ArchiveControl") {
            ControlWidgetButton(action: SnapArchiveControlIntent()) {
                Label("拾文·归档最近截图", systemImage: "text.viewfinder")
            }
        }
        .displayName("拾文·归档最近截图")
        .description("识别并归档相册中最近一张截图")
    }
}

/// 开箱即用的「大爆炸识别」控件：绑定到操作按钮（iOS 18 的「控制」）或控制中心，
/// 一按即拉起拾文并弹出大爆炸选取，无需在快捷指令里组装任何步骤。
struct SnapBangControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.snaptext.BangControl") {
            ControlWidgetButton(action: SnapLatestScreenshotIntent()) {
                Label("拾文·大爆炸识别", systemImage: "text.word.spacing")
            }
        }
        .displayName("拾文·大爆炸识别")
        .description("识别最近截图并打开大爆炸文字选取")
    }
}

@main
struct SnapTextWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnapBangControl()
        SnapArchiveControl()
    }
}
