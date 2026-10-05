import Combine
import UIKit

/// 分享扩展的系统能力桥：URL 打开与分享面板，供 ExportBridge 在扩展进程内使用。
final class ShareExtensionCoordinator {
    static var shared: ShareExtensionCoordinator?

    private weak var context: NSExtensionContext?
    private weak var rootViewController: UIViewController?

    init(context: NSExtensionContext?, rootViewController: UIViewController?) {
        self.context = context
        self.rootViewController = rootViewController
    }

    /// 扩展进程打开外部 URL：优先 NSExtensionContext.open，失败交由宿主 App 打开。
    func open(url: URL) -> Bool {
        if let context {
            var succeeded = false
            context.open(url) { success in
                succeeded = success
            }
            // context.open 的 completionHandler 同步回调与否不做保证，失败时返回 false 触发剪贴板兜底。
            return succeeded
        }
        return false
    }

    func presentShareSheet(items: [Any]) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        rootViewController?.present(controller, animated: true)
    }

    /// 扩展上下文里打开外部 App 常受限制：提供「复制 + 提示」兜底，由 UI 层消费。
    static func fallbackCopy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
