import SwiftUI
import UIKit

/// 导出动作的系统桥接：主 App 走 UIApplication/ViewController，分享扩展走 ExtensionContext，
/// 控件扩展不提供交互导出。通过闭包注入，BigBangView 不感知宿主差异。
struct ExportBridge {
    /// 打开外部 URL（Obsidian/Bear/自定义 scheme）。返回是否成功发起。
    let openURL: @MainActor (URL) -> Bool
    /// 弹出系统分享面板（备忘录导出走这里）。
    let presentShareSheet: @MainActor ([Any]) -> Void

    static let `default` = ExportBridge(
        openURL: { url in
            #if SHARE_EXTENSION
            return ShareExtensionCoordinator.shared?.open(url: url) ?? false
            #elseif APP_EXTENSION
            return false
            #else
            // openURL(_:) 自 iOS 10 弃用但同步返回 Bool，用于在目标应用缺失时触发剪贴板兜底。
            return UIApplication.shared.openURL(url)
            #endif
        },
        presentShareSheet: { items in
            #if SHARE_EXTENSION
            ShareExtensionCoordinator.shared?.presentShareSheet(items: items)
            #elseif APP_EXTENSION
            _ = items
            #else
            TopPresenter.present(UIActivityViewController(activityItems: items, applicationActivities: nil))
            #endif
        }
    )
}

/// 主 App 内在任意视图层级弹出 UIKit 面板的辅助。
#if !APP_EXTENSION
enum TopPresenter {
    @MainActor
    static func present(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
            let root = scene.keyWindow?.rootViewController
        else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}
#endif

/// 系统分享面板的 SwiftUI 封装（主 App 用）。
#if !APP_EXTENSION
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
