import Social
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 分享扩展入口：从系统分享面板接收截图图片（支持多张）。
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        ShareExtensionCoordinator.shared = ShareExtensionCoordinator(
            context: extensionContext,
            rootViewController: self
        )
        let hosting = UIHostingController(rootView: ShareExtensionView(
            extensionContext: extensionContext,
            onFinish: finish
        ))
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// 分享扩展主界面：取图 → 复用主 App 的批量/单张捕获流程（查重 + OCR + 提取 + 归档 + 大爆炸）。
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?
    var onFinish: () -> Void

    @State private var images: [UIImage]?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let images {
                if images.count == 1 {
                    CaptureFlowView(image: images[0], source: .share, onDone: onFinish)
                } else {
                    BatchCaptureFlowView(images: images, source: .share, onDone: onFinish)
                }
            } else if loadFailed {
                VStack(spacing: 14) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("未能读取分享的图片")
                        .font(.headline)
                    Button("关闭", action: onFinish)
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView("正在接收截图…")
            }
        }
        .task { await loadImages() }
    }

    private func loadImages() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            loadFailed = true
            return
        }
        var allProviders: [NSItemProvider] = []
        for item in extensionItems {
            allProviders.append(contentsOf: item.attachments ?? [])
        }
        let providers = allProviders.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
        guard !providers.isEmpty else {
            loadFailed = true
            return
        }

        var decoded: [UIImage] = []
        for provider in providers.prefix(5) {
            if let image = try? await decodeImage(from: provider) {
                decoded.append(image)
            }
        }
        if decoded.isEmpty {
            loadFailed = true
        } else {
            images = decoded
        }
    }

    /// 优先按 Data 读取，兼容 URL/UIImage 两种提供方式。
    private func decodeImage(from provider: NSItemProvider) async throws -> UIImage? {
        if let data = try? await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Data?, Error>) in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }), let image = UIImage(data: data) {
            return image
        }

        let item: (any NSSecureCoding)? = try? await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
        if let url = item as? URL, let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return item as? UIImage
    }
}
