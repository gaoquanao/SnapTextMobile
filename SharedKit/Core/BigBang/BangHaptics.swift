import UIKit

/// 大爆炸选取的触感反馈：进入选取用中等力度，扫过词块切换用轻点。
/// 分享扩展内不可用，静默降级为空实现。
enum BangHaptics {
    #if !APP_EXTENSION
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    /// 手势即将开始前调用，提前唤醒引擎降低首次延迟。
    static func prepare() {
        selection.prepare()
        impact.prepare()
    }

    /// 长按进入选取模式。
    static func activate() {
        impact.impactOccurred()
    }

    /// 拖过词块边界。
    static func tick() {
        selection.selectionChanged()
    }
    #else
    static func prepare() {}
    static func activate() {}
    static func tick() {}
    #endif
}
