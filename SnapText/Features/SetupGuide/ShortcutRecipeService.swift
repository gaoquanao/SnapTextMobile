import OSLog
import SwiftUI
import UIKit

let recipeImportLogger = Logger(subsystem: "me.snaptext.app", category: "recipe-import")

/// 随 App 内置的快捷指令配方（.shortcut 文件，已签名）。
/// 用户在设置页「一键添加」，经系统导入确认后即出现在快捷指令 App，可自由修改。
struct ShortcutRecipe: Identifiable {
    let id: String
    /// Bundle 内的资源名（不含扩展名），也是导入后快捷指令的显示名。
    let resourceName: String
    /// 默认推荐配方：设置页与引导中优先展示。
    let isDefault: Bool
    let summary: LocalizedStringKey
    /// 手动搭建步骤（导入失败或想完全自己配置时使用）。
    let manualSteps: [String]
}

enum ShortcutRecipeLibrary {
    static let bang = ShortcutRecipe(
        id: "bang",
        resourceName: "拾文·大爆炸",
        isDefault: true,
        summary: "截屏 → 立即弹出大爆炸选取，适合想马上查看并整理文字的时刻。",
        manualSteps: [
            String(localized: "打开「快捷指令」App，新建快捷指令，命名如「拾文·大爆炸」"),
            String(localized: "添加动作 1：搜索并选择「截屏」"),
            String(localized: "添加动作 2：搜索 App「拾文」，选择「大爆炸截图识别」，把「截图」参数设为上一步的输出"),
            String(localized: "运行测试一次，首次会询问「允许截屏」，选择允许"),
        ]
    )

    static let archive = ShortcutRecipe(
        id: "archive",
        resourceName: "拾文·静默归档",
        isDefault: false,
        summary: "截屏 → 后台完成识别归档并发送通知，不打断当前操作。",
        manualSteps: [
            String(localized: "新建快捷指令，命名如「拾文·静默归档」"),
            String(localized: "添加动作 1：「截屏」"),
            String(localized: "添加动作 2：拾文 App 的「静默归档截图」，把「截图」参数设为上一步的输出"),
            String(localized: "（可选）添加动作 3：「显示通知」，正文用快捷指令的「提供输入」"),
        ]
    )

    static let all: [ShortcutRecipe] = [bang, archive]
}

/// 把内置配方交给系统导入。
@MainActor
enum ShortcutRecipeImporter {
    /// 复制到临时目录并返回文件 URL：包内文件直接外发会被沙盒拦截。
    /// 返回 nil 表示资源缺失或拷贝失败，调用方应提示用手动搭建。
    static func exportFileURL(_ recipe: ShortcutRecipe) -> URL? {
        guard let source = Bundle.main.url(forResource: recipe.resourceName, withExtension: "shortcut") else {
            return nil
        }
        let destination = FileManager.default.temporaryDirectory
            .appending(path: source.lastPathComponent)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            return nil
        }
        return destination
    }
}

/// 经系统「打开方式」菜单把配方文件交给快捷指令 App：
/// Shortcuts 在系统里注册为 .shortcut 文件的处理程序，菜单由系统完成沙盒外的文件拷贝，
/// 全程离线；路径不通时由调用方退回分享面板。
@MainActor
final class RecipeDocumentPresenter: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = RecipeDocumentPresenter()

    private var controller: UIDocumentInteractionController?

    var topView: UIView? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        return window?.rootViewController?.view
    }

    /// 返回 false 表示系统里没有可打开该类型的 App。
    @discardableResult
    func presentOpenInMenu(for fileURL: URL) -> Bool {
        guard let view = topView else {
            recipeImportLogger.error("open-in: 找不到顶层视图")
            return false
        }
        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        self.controller = controller
        let presented = controller.presentOpenInMenu(from: view.bounds, in: view, animated: true)
        recipeImportLogger.info("open-in 菜单已弹出: \(presented, privacy: .public)")
        return presented
    }

    nonisolated func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        Task { @MainActor in self.controller = nil }
    }

    nonisolated func documentInteractionControllerDidEndSendingToApplication(_ controller: UIDocumentInteractionController) {
        Task { @MainActor in self.controller = nil }
    }
}
