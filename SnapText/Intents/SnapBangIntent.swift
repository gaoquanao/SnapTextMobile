import AppIntents
import UIKit

/// 配方 A：快捷指令「截屏 → 拾文大爆炸截图识别」。
/// 打开 App 并在主 App 进程内执行，入队待处理截图后由根视图弹出大爆炸全屏层。
struct SnapBangIntent: AppIntent {
    static let title: LocalizedStringResource = "大爆炸截图识别"
    static let description = IntentDescription("识别截图文字并弹出大爆炸选取界面，瞬间完成归档。")
    static let openAppWhenRun = true

    @Parameter(title: "截图", description: "来自快捷指令「截屏」动作的输出")
    var image: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult {
        let image: UIImage
        if let data = self.image?.data, let decoded = UIImage(data: data) {
            image = decoded
        } else {
            // 未传参数时兜底取相册最新截图。
            guard let latest = try await PhotoLibraryHelper.latestScreenshot() else {
                throw SnapIntentError.noScreenshot
            }
            image = latest
        }
        CaptureBus.shared.enqueue(image)
        return .result()
    }
}
