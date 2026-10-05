import AppIntents

/// 让快捷指令 App 的动作列表直接搜到拾文的四个能力。
struct SnapTextShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SnapBangIntent(),
            phrases: ["用\(.applicationName)识别截图", "用\(.applicationName)大爆炸"],
            shortTitle: "大爆炸截图识别",
            systemImageName: "text.word.spacing"
        )
        AppShortcut(
            intent: SnapArchiveIntent(),
            phrases: ["用\(.applicationName)静默归档"],
            shortTitle: "静默归档截图",
            systemImageName: "archivebox"
        )
        AppShortcut(
            intent: SnapOCRIntent(),
            phrases: ["用\(.applicationName)提取文本"],
            shortTitle: "提取截图文本",
            systemImageName: "doc.text.viewfinder"
        )
        AppShortcut(
            intent: SnapLatestScreenshotIntent(),
            phrases: ["用\(.applicationName)处理最近截图"],
            shortTitle: "处理最近截图",
            systemImageName: "photo.badge.arrow.down"
        )
    }
}
