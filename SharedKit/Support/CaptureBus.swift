import SwiftUI
import UIKit

/// 意图 → 界面的待处理截图总线（三个 target 共用，实际只在主 App 进程中读写）。
/// `openAppWhenRun` 的 App Intent 在主 App 进程内执行，入队后根视图弹出捕获流程。
@MainActor
final class CaptureBus {
    static let shared = CaptureBus()

    private(set) var pendingImage: UIImage?

    private init() {}

    func enqueue(_ image: UIImage) {
        pendingImage = image
        NotificationCenter.default.post(name: .snapPendingCapture, object: nil)
    }

    func takePending() -> UIImage? {
        defer { pendingImage = nil }
        return pendingImage
    }
}

extension Notification.Name {
    static let snapPendingCapture = Notification.Name("com.snaptext.pendingCapture")
}
