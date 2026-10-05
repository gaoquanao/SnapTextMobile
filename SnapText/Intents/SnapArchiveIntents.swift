import AppIntents
import SwiftData
import UIKit

/// 配方 B：快捷指令「截屏 → 拾文静默归档截图」。后台完成 OCR + 提取 + 入库，返回摘要供通知展示。
struct SnapArchiveIntent: AppIntent {
    static let title: LocalizedStringResource = "静默归档截图"
    static let description = IntentDescription("在后台识别截图并自动归档，返回标题与摘要，可接「显示通知」。")

    @Parameter(title: "截图", description: "来自快捷指令「截屏」动作的输出")
    var image: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let image: UIImage
        var cleanupAssetID: String?
        if let data = self.image?.data, let decoded = UIImage(data: data) {
            image = decoded
        } else {
            // 兜底路径由 App 自行从相册取材，属于静默通道，纳入清理策略。
            guard let asset = try await PhotoLibraryHelper.latestScreenshotAsset(),
                  let latest = try await PhotoLibraryHelper.image(for: asset) else {
                throw SnapIntentError.noScreenshot
            }
            image = latest
            cleanupAssetID = asset.localIdentifier
        }
        let outcome = try await CapturePipeline.capture(image: image, source: .quickButton)
        if let cleanupAssetID {
            await ScreenshotCleanupPolicy.run(assetIDs: [cleanupAssetID])
        }
        let tags = outcome.entry.tags.prefix(3).map { "#\($0)" }.joined(separator: " ")
        let summary = "\(outcome.entry.title)\n\(outcome.entry.summary)\(tags.isEmpty ? "" : "\n\(tags)")"
        return .result(value: summary)
    }
}

/// 只提取文本返回给快捷指令，供自由串接（例如直接接「创建备忘录」动作）。
struct SnapOCRIntent: AppIntent {
    static let title: LocalizedStringResource = "提取截图文本"
    static let description = IntentDescription("仅识别截图文本并返回，方便在快捷指令中继续加工。")

    @Parameter(title: "截图", description: "来自快捷指令「截屏」动作的输出")
    var image: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let image: UIImage
        if let data = self.image?.data, let decoded = UIImage(data: data) {
            image = decoded
        } else {
            guard let latest = try await PhotoLibraryHelper.latestScreenshot() else {
                throw SnapIntentError.noScreenshot
            }
            image = latest
        }
        let text = try await TextRecognizer.recognize(ImagePreprocessor.downscale(image))
        return .result(value: text)
    }
}
