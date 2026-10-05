import SwiftData
import SwiftUI
import UIKit

/// 开发期演示支持：**仅 DEBUG 构建生效**，Release 下所有入口关闭、不产生任何行为。
/// 用于生成 App Store 截图与本地体验，通过 simctl 启动参数触发：
///
///   xcrun simctl launch <UDID> me.snaptext.app -SnapTextDemoSeed 1
///   xcrun simctl launch <UDID> me.snaptext.app -SnapTextDemoScreen bigbang
///
/// 屏幕参数取值：list（默认）| bigbang | capture | settings
enum DemoSupport {
    enum DemoScreen: String {
        case list, bigbang, capture, settings, onboarding
    }

    /// 启动参数指定的目标界面（Release 恒为 nil）。
    static var screen: DemoScreen? {
        #if DEBUG
        guard let raw = UserDefaults.standard.string(forKey: "SnapTextDemoScreen") else { return nil }
        return DemoScreen(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 演示引导时直接跳到第几页（0 起始；Release 恒为 0）。
    static var onboardingPage: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "SnapTextDemoOnboardingPage")
        #else
        return 0
        #endif
    }

    /// 验证用：-SnapTextDemoImportRecipe bang|archive 让设置页出现后自动触发该配方导入（Release 恒为 nil）。
    static var pendingRecipeImport: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "SnapTextDemoImportRecipe")
        #else
        return nil
        #endif
    }

    /// 注入演示归档（走真实 OCR + 提取管线；重复运行由查重兜底，不产生重复数据）。
    @MainActor
    static func seedIfNeeded() async {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "SnapTextDemoSeed") else { return }
        let samples: [(UIImage, ArchiveSource)] = [
            (DemoCardRenderer.article(), .share),
            (DemoCardRenderer.businessCard(), .camera),
            (DemoCardRenderer.quote(), .importAction),
            (DemoCardRenderer.recipe(), .autoWatch),
        ]
        for (image, source) in samples {
            _ = try? await CapturePipeline.capture(image: image, source: source)
        }
        #endif
    }

    /// 取演示用归档：优先含结构化信息的名片（展示信息提取分组），其次科技文章，最后最新一条。
    @MainActor
    static func firstEntry() -> ArchiveEntry? {
        #if DEBUG
        let descriptor = FetchDescriptor<ArchiveEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let entries = (try? ArchiveStore.mainContext.fetch(descriptor)) ?? []
        if let contact = entries.first(where: { $0.recognizedText.contains("example.com") }) {
            return contact
        }
        if let article = entries.first(where: { $0.recognizedText.contains("WWDC26") }) {
            return article
        }
        return entries.first
        #else
        return nil
        #endif
    }

    /// 调试钻取：验证删除通道（-SnapTextDemoDeleteDrill 1 删除相册最新一张图片，
    /// 用于确认系统确认弹窗正常出现；配合 UI 测试或人工点按完成）。
    static func runDeleteDrillIfNeeded() async {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "SnapTextDemoDeleteDrill") else { return }
        guard let asset = try? await PhotoLibraryHelper.latestAsset(matching: nil) else { return }
        _ = await PhotoLibraryHelper.deleteAssets(withLocalIdentifiers: [asset.localIdentifier])
        #endif
    }
}

#if DEBUG

/// 演示用「截图卡片」渲染：白底深字，模拟真实截图内容。
private enum DemoCardRenderer {
    static let size = CGSize(width: 900, height: 1200)

    private static func render(
        lines: [(text: String, font: UIFont, color: UIColor, spacing: CGFloat)]
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.99, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 90
            for line in lines {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: line.font,
                    .foregroundColor: line.color,
                ]
                let rect = (line.text as NSString).boundingRect(
                    with: CGSize(width: size.width - 140, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil
                )
                (line.text as NSString).draw(
                    with: CGRect(x: 70, y: y, width: size.width - 140, height: rect.height + 4),
                    options: [.usesLineFragmentOrigin],
                    attributes: attributes,
                    context: nil
                )
                y += rect.height + line.spacing
            }
        }
    }

    static func article() -> UIImage {
        render(lines: [
            ("WWDC26 主题演讲要点", .systemFont(ofSize: 54, weight: .bold), .black, 36),
            ("Apple 发布 Foundation Models 框架，开发者可在设备本地调用约 30 亿参数的大模型，完全离线、免费。", .systemFont(ofSize: 34), .darkGray, 28),
            ("适用：iOS 26 及以上 · Apple Intelligence 机型", .systemFont(ofSize: 32), .darkGray, 28),
            ("价格：免费（无按量计费）", .systemFont(ofSize: 32), .darkGray, 28),
            ("地点：Cupertino, California", .systemFont(ofSize: 32), .darkGray, 28),
        ])
    }

    static func businessCard() -> UIImage {
        render(lines: [
            ("张伟", .systemFont(ofSize: 56, weight: .bold), .black, 30),
            ("产品经理 · 极光科技", .systemFont(ofSize: 34), .darkGray, 40),
            ("电话 138-1234-5678", .systemFont(ofSize: 34), .black, 26),
            ("邮箱 zhangwei@example.com", .systemFont(ofSize: 34), .black, 26),
            ("地址：上海市浦东新区世纪大道 100 号", .systemFont(ofSize: 34), .black, 26),
            ("官网 https://example.com", .systemFont(ofSize: 32), .systemBlue, 26),
        ])
    }

    static func quote() -> UIImage {
        render(lines: [
            ("The best way to predict\nthe future is to invent it.", .systemFont(ofSize: 46, weight: .medium), .black, 34),
            ("— Alan Kay", .systemFont(ofSize: 36), .darkGray, 44),
            ("Ship early, ship often.\nMeasure everything.", .systemFont(ofSize: 40), .black, 30),
            ("Idea #42 · keep it offline.", .systemFont(ofSize: 34), .systemBlue, 26),
        ])
    }

    static func recipe() -> UIImage {
        render(lines: [
            ("番茄牛腩做法", .systemFont(ofSize: 54, weight: .bold), .black, 34),
            ("1. 牛腩冷水下锅，焯水去浮沫", .systemFont(ofSize: 34), .black, 24),
            ("2. 热油炒香葱姜，加入番茄炒出汁", .systemFont(ofSize: 34), .black, 24),
            ("3. 加牛腩与热水，小火炖 90 分钟", .systemFont(ofSize: 34), .black, 24),
            ("4. 出锅前加盐，撒香菜", .systemFont(ofSize: 34), .black, 24),
            ("小贴士：番茄去皮口感更好", .systemFont(ofSize: 30), .darkGray, 24),
        ])
    }
}

#endif
