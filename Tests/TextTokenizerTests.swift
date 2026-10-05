import XCTest
@testable import SnapText

final class TextTokenizerTests: XCTestCase {
    private func texts(_ tokens: [TextToken]) -> [String] {
        tokens.map(\.text)
    }

    func testChineseSegmentation() {
        let tokens = TextTokenizer.tokenize("我今天想吃苹果")
        let words = texts(tokens)
        XCTAssertFalse(words.isEmpty)
        // 词级切分：任何词都不应长于原句，且全部为词类块。
        XCTAssertTrue(words.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(words.joined(), "我今天想吃苹果")
        XCTAssertTrue(words.contains(where: { $0.count < "我今天想吃苹果".count }), "应切出多于一个词")
    }

    func testPunctuationBecomesStandaloneTokens() {
        let tokens = TextTokenizer.tokenize("你好，世界！")
        let puncts = tokens.filter(\.isPunctuation)
        XCTAssertEqual(puncts.map(\.text), ["，", "！"])
    }

    func testEnglishWordsKeptWhole() {
        let tokens = TextTokenizer.tokenize("Share Extension")
        XCTAssertEqual(texts(tokens), ["Share", "Extension"])
    }

    func testWhitespaceNotTokenized() {
        let tokens = TextTokenizer.tokenize("a  b\n c")
        XCTAssertEqual(texts(tokens), ["a", "b", "c"])
    }

    func testRoundTripPreservesContentIgnoringWhitespace() {
        let original = "WWDC26 发布了 Foundation Models 框架，支持端侧生成；性能很好！"
        let tokens = TextTokenizer.tokenize(original)
        let rejoined = TokenJoiner.join(tokens)
        let strip: (String) -> String = { $0.components(separatedBy: .whitespacesAndNewlines).joined() }
        XCTAssertEqual(strip(rejoined), strip(original), "分词+拼合必须无损还原原文")
    }

    func testSentenceIndexAdvancesAtTerminators() {
        let tokens = TextTokenizer.tokenize("第一句。第二句")
        let terminator = tokens.first { $0.text == "。" }
        XCTAssertNotNil(terminator, "句号应独立成块")
        XCTAssertEqual(terminator?.sentenceIndex, 0)
        let secondSentence = tokens.filter { $0.sentenceIndex == 1 && !$0.isPunctuation }
        XCTAssertFalse(secondSentence.isEmpty, "句号之后应有属于第二句的词块")
    }

    func testCJKAndLatinMixed() {
        let tokens = TextTokenizer.tokenize("用Swift写iOS应用")
        XCTAssertTrue(tokens.contains { $0.text == "Swift" })
        let rejoined = TokenJoiner.join(tokens)
        XCTAssertEqual(rejoined, "用Swift写iOS应用", "原文无空白时忠实还原，不擅自插入空格")
    }

    func testSourceSpacingAroundLatinPreserved() {
        let tokens = TextTokenizer.tokenize("用 Swift 写 iOS 应用")
        XCTAssertEqual(TokenJoiner.join(tokens), "用 Swift 写 iOS 应用")
    }

    func testEmailVersionAndDecimalNotBroken() {
        XCTAssertEqual(
            TokenJoiner.join(TextTokenizer.tokenize("邮箱 zhangwei@example.com")),
            "邮箱 zhangwei@example.com",
            "邮箱内的点不应被拆成空格"
        )
        XCTAssertEqual(
            TokenJoiner.join(TextTokenizer.tokenize("升级到 v1.2 后正常")),
            "升级到 v1.2 后正常"
        )
        XCTAssertEqual(
            TokenJoiner.join(TextTokenizer.tokenize("共 3.14 秒")),
            "共 3.14 秒"
        )
    }

    // MARK: - 行 / 段结构

    func testLineAndParagraphIndices() {
        let tokens = TextTokenizer.tokenize("甲\n乙\n\n丙")
        XCTAssertEqual(tokens.map(\.text), ["甲", "乙", "丙"])
        XCTAssertEqual(tokens.map(\.lineIndex), [0, 1, 3], "空行占一行号")
        XCTAssertEqual(tokens.map(\.paragraphIndex), [0, 0, 1], "空行开新段落")
    }

    func testConsecutiveBlankLinesCollapseToOneParagraphBreak() {
        let tokens = TextTokenizer.tokenize("甲\n\n\n\n乙")
        XCTAssertEqual(tokens.map(\.paragraphIndex), [0, 1], "连续空行只算一次分段")
    }

    func testMultilineMixedContentIndices() {
        let tokens = TextTokenizer.tokenize("Hello World\n\n拾文")
        let hello = tokens.first { $0.text == "Hello" }
        XCTAssertEqual(hello?.lineIndex, 0)
        XCTAssertEqual(hello?.paragraphIndex, 0)
        let shiwen = tokens.last
        XCTAssertEqual(shiwen?.lineIndex, 2)
        XCTAssertEqual(shiwen?.paragraphIndex, 1)
    }

    func testRoundTripPreservesParagraphStructure() {
        let original = "第一段文字。\n第二行。\n\n第二段。\n\n\n第三段。"
        let tokens = TextTokenizer.tokenize(original)
        XCTAssertEqual(
            TokenJoiner.join(tokens),
            "第一段文字。\n第二行。\n\n第二段。\n\n第三段。",
            "整段拼合应还原换行与分段（连续空行折叠为一个分段）"
        )
    }

    func testSingleLineTextHasZeroIndices() {
        let tokens = TextTokenizer.tokenize("单行文本")
        XCTAssertTrue(tokens.allSatisfy { $0.lineIndex == 0 && $0.paragraphIndex == 0 })
    }
}
