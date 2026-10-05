import XCTest
@testable import SnapText

final class TextPolisherTests: XCTestCase {
    // MARK: - 段落合并

    func testMergesWrappedCJKLines() {
        let raw = "Apple 发布 Foundation Models 框架，开发者可以在设备本地调用大模型，\n完全离线而且免费使用。"
        let result = TextPolisher.normalize(raw)
        XCTAssertEqual(result, "Apple 发布 Foundation Models 框架，开发者可以在设备本地调用大模型，完全离线而且免费使用。")
    }

    func testMergesWrappedLatinLinesWithSpace() {
        XCTAssertEqual(
            TextPolisher.normalize("The best way to predict\nthe future is to invent it."),
            "The best way to predict the future is to invent it."
        )
    }

    func testBreaksParagraphAfterSentenceEnd() {
        let result = TextPolisher.normalize("这是第一段的内容。\n这是第二段的内容。")
        XCTAssertEqual(result, "这是第一段的内容。\n\n这是第二段的内容。")
    }

    func testShortLinesStaySeparate() {
        // 名片/联系人这类短行应当逐行保留
        let raw = "张伟\n产品经理 · 极光科技\n电话 138-1234-5678\n邮箱 zhangwei@example.com"
        let result = TextPolisher.normalize(raw)
        XCTAssertEqual(result.components(separatedBy: "\n\n").count, 4)
        XCTAssertTrue(result.contains("张伟"))
        XCTAssertTrue(result.contains("138-1234-5678"))
    }

    func testBlankLineSeparatesParagraphs() {
        let result = TextPolisher.normalize("第一段\n\n第二段")
        XCTAssertEqual(result, "第一段\n\n第二段")
    }

    func testListLinesPreservedIndividually() {
        let raw = "1. 牛腩冷水下锅，焯水去浮沫并冲洗干净备用\n2. 热油炒香葱姜，加入番茄炒出汁\n3. 加牛腩与热水，小火炖 90 分钟"
        let result = TextPolisher.normalize(raw)
        // 连续列表项以单换行相连（Markdown 有序列表语义）
        let lines = result.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("1."))
        XCTAssertTrue(lines[2].contains("90 分钟"))
    }

    func testBulletLinesPreserved() {
        let raw = "• 支持离线识别\n• 支持快捷指令自动化"
        let result = TextPolisher.normalize(raw)
        XCTAssertEqual(result.components(separatedBy: "\n").count, 2)
    }

    // MARK: - 空格

    func testRemovesSpacesBetweenCJK() {
        XCTAssertEqual(TextPolisher.normalize("识 别 文 字"), "识别文字")
    }

    func testKeepsSpacesAroundLatin() {
        XCTAssertEqual(TextPolisher.normalize("用 Swift 开发 iOS 应用"), "用 Swift 开发 iOS 应用")
    }

    func testDoesNotBreakDecimals() {
        XCTAssertEqual(TextPolisher.normalize("版本 1.5 发布"), "版本 1.5 发布")
        XCTAssertEqual(TextPolisher.normalize("时间 5:30 开始"), "时间 5:30 开始")
    }

    func testAddsSpaceAfterLatinPunctuation() {
        XCTAssertEqual(TextPolisher.normalize("hello,world"), "hello, world")
    }

    func testDoesNotBreakEmailOrDomain() {
        // 句点后不加空格，避免破坏邮箱/域名
        XCTAssertEqual(TextPolisher.normalize("邮箱 zhangwei@example.com"), "邮箱 zhangwei@example.com")
        XCTAssertEqual(TextPolisher.normalize("访问 example.com 了解"), "访问 example.com 了解")
    }

    func testSentenceDotStillGetsSpace() {
        XCTAssertEqual(TextPolisher.normalize("End.Next sentence"), "End. Next sentence")
    }

    func testRepairsBrokenURLScheme() {
        XCTAssertEqual(TextPolisher.normalize("官网 https:/example.com"), "官网 https://example.com")
        XCTAssertEqual(TextPolisher.normalize("官网 https://example.com"), "官网 https://example.com")
    }

    // MARK: - 标点

    func testHalfWidthPunctuationBecomesFullWidthInCJK() {
        XCTAssertEqual(TextPolisher.normalize("你好,世界"), "你好，世界")
        XCTAssertEqual(TextPolisher.normalize("完成了!"), "完成了！")
    }

    func testLatinPunctuationStaysHalfWidth() {
        XCTAssertEqual(TextPolisher.normalize("Hello, world."), "Hello, world.")
    }

    func testCollapsesRepeatedPunctuation() {
        XCTAssertEqual(TextPolisher.normalize("太好了！！！"), "太好了！")
        XCTAssertEqual(TextPolisher.normalize("等等……"), "等等……")
    }

    func testFullWidthAlphanumericsToHalfWidth() {
        XCTAssertEqual(TextPolisher.normalize("ＡＢＣ１２３"), "ABC123")
    }

    func testParenthesesRestoredInCJK() {
        XCTAssertEqual(TextPolisher.normalize("免费(无内购)"), "免费（无内购）")
    }

    func testRemovesSpaceBeforePunctuation() {
        XCTAssertEqual(TextPolisher.normalize("你好 ，世界 。"), "你好，世界。")
    }

    func testConsecutiveListItemsUseSingleNewline() {
        let raw = "1. 牛腩冷水下锅，焯水去浮沫\n2. 热油炒香葱姜，加入番茄炒出汁\n3. 小火炖 90 分钟"
        let result = TextPolisher.normalize(raw)
        XCTAssertFalse(result.contains("\n\n"), "连续列表项之间不应有空行")
        XCTAssertEqual(result.components(separatedBy: "\n").count, 3)
    }

    func testListMarkerGetsSpace() {
        // Markdown 列表要求序号后带空格
        XCTAssertEqual(TextPolisher.normalize("1.牛腩下锅"), "1. 牛腩下锅")
        XCTAssertEqual(TextPolisher.normalize("-支持离线"), "- 支持离线")
    }

    func testAttributionLineStaysStandalone() {
        let raw = "The best way to predict the future is to invent it.\n— Alan Kay\nShip early, ship often."
        let result = TextPolisher.normalize(raw)
        XCTAssertTrue(result.contains("\n\n— Alan Kay"))
        XCTAssertTrue(result.contains("— Alan Kay\n\nShip early"))
    }

    func testMidLineBulletGetsSpaces() {
        XCTAssertEqual(TextPolisher.normalize("Idea #42•keep it offline."), "Idea #42 • keep it offline.")
        // 行首列表符号不受影响
        XCTAssertEqual(TextPolisher.normalize("• 支持离线识别"), "• 支持离线识别")
    }

    // MARK: - 标题摘要

    func testTitleTakesFirstSentenceWithinLimit() {
        let title = NaturalLanguageExtractor.extractTitle(from: "WWDC26 主题演讲要点。Apple 发布新框架。")
        XCTAssertEqual(title, "WWDC26 主题演讲要点")
        XCTAssertLessThanOrEqual(title.count, 20)
    }

    func testTitleClipsLongSentence() {
        let long = "这是一段非常长的句子用来验证标题截断逻辑是否正确处理超过二十个字的情况"
        let title = NaturalLanguageExtractor.extractTitle(from: long)
        XCTAssertLessThanOrEqual(title.count, 20)
        XCTAssertTrue(long.hasPrefix(title))
    }

    func testTitleAvoidsBreakingEnglishWord() {
        let title = NaturalLanguageExtractor.extractTitle(from: "The best way to predict the future")
        XCTAssertLessThanOrEqual(title.count, 20)
        XCTAssertFalse(title.hasSuffix(" "))
        // 不应在单词中间截断
        XCTAssertFalse(title.hasSuffix("pred"))
    }

    func testEmptyTextGivesEmptyTitle() {
        XCTAssertEqual(NaturalLanguageExtractor.extractTitle(from: ""), "")
    }

    // MARK: - AI 润色守门

    func testFaithfulGateAcceptsSimilarLength() {
        XCTAssertTrue(TextPolishService.isFaithful("整理后的文本内容", comparedTo: "整理后的文本"))
    }

    func testFaithfulGateRejectsOverRewrite() {
        // 输出远短于原文（可能丢内容）应拒绝
        XCTAssertFalse(TextPolishService.isFaithful("短", comparedTo: "一段比较长的原始文本内容用来测试守门阈值"))
        // 输出大幅膨胀（可能扩写）应拒绝
        let input = "原文"
        let output = String(repeating: "扩写", count: 10)
        XCTAssertFalse(TextPolishService.isFaithful(output, comparedTo: input))
    }

    func testFaithfulGateRejectsEmpty() {
        XCTAssertFalse(TextPolishService.isFaithful("", comparedTo: "原文"))
        XCTAssertFalse(TextPolishService.isFaithful("输出", comparedTo: ""))
    }
}
