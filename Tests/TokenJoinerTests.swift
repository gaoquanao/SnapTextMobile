import XCTest
@testable import SnapText

final class TokenJoinerTests: XCTestCase {
    func testCJKAdjacentNoSpace() {
        XCTAssertEqual(TokenJoiner.join(["今天", "天气", "不错"]), "今天天气不错")
    }

    func testLatinWordsGetSpaces() {
        XCTAssertEqual(TokenJoiner.join(["Share", "Extension"]), "Share Extension")
    }

    func testPunctuationAttachesToPreviousWord() {
        XCTAssertEqual(TokenJoiner.join(["苹果", "，", "好吃"]), "苹果，好吃")
        XCTAssertEqual(TokenJoiner.join(["done", ",", "next"]), "done, next")
    }

    func testCJKAndLatinBoundary() {
        XCTAssertEqual(TokenJoiner.join(["用", "Swift", "开发"]), "用 Swift 开发")
    }

    func testOpeningPunctuationAttachesForward() {
        XCTAssertEqual(TokenJoiner.join(["他说", "「", "你好", "」"]), "他说「你好」")
    }

    func testEmptyPiecesSkipped() {
        XCTAssertEqual(TokenJoiner.join(["你好", "", "世界"]), "你好世界")
    }

    func testSingleToken() {
        XCTAssertEqual(TokenJoiner.join(["测试"]), "测试")
    }

    // MARK: - 跨行 / 跨段选取

    func testCrossLineSelectionInsertsNewline() {
        let tokens = TextTokenizer.tokenize("甲组\n乙组")
        XCTAssertEqual(TokenJoiner.join(tokens), "甲组\n乙组")
    }

    func testCrossParagraphSelectionInsertsBlankLine() {
        let tokens = TextTokenizer.tokenize("第一段\n\n第二段")
        XCTAssertEqual(TokenJoiner.join(tokens), "第一段\n\n第二段")
    }

    func testSubsetAcrossLinesKeepsBreak() {
        let tokens = TextTokenizer.tokenize("alpha beta\ngamma")
        let beta = tokens.first { $0.text == "beta" }
        let gamma = tokens.first { $0.text == "gamma" }
        XCTAssertEqual(TokenJoiner.join([beta, gamma].compactMap { $0 }), "beta\ngamma")
    }

    func testSubsetWithinLineStillUsesSpacingRules() {
        let tokens = TextTokenizer.tokenize("alpha beta\ngamma")
        let selected = tokens.filter { $0.text == "alpha" || $0.text == "beta" }
        XCTAssertEqual(TokenJoiner.join(selected), "alpha beta", "同一行内不引入换行")
    }
}
