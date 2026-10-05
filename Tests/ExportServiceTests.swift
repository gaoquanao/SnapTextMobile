import XCTest
@testable import SnapText

final class ExportServiceTests: XCTestCase {
    private func makePayload() -> ExportPayload {
        ExportPayload(title: "端侧AI笔记", text: "Vision 框架识别截图", tags: ["AI", "iOS"], date: Date(timeIntervalSince1970: 0))
    }

    func testMarkdownFormat() {
        let markdown = makePayload().markdown
        XCTAssertTrue(markdown.hasPrefix("# 端侧AI笔记"))
        XCTAssertTrue(markdown.contains("Vision 框架识别截图"))
        XCTAssertTrue(markdown.contains("#AI #iOS"))
        XCTAssertTrue(markdown.contains("拾文 SnapText"))
    }

    func testObsidianURL() {
        let url = ExportService.obsidianURL(payload: makePayload(), vault: "MyVault")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "obsidian")
        XCTAssertEqual(url?.host, "new")
        let query = url?.query ?? ""
        XCTAssertTrue(query.contains("vault=MyVault"))
        XCTAssertTrue(query.contains("name="))
        XCTAssertTrue(query.contains("content="))
    }

    func testBearURL() {
        let url = ExportService.bearURL(payload: makePayload())
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "bear")
        XCTAssertEqual(url?.host, "x-callback-url")
        XCTAssertEqual(url?.path, "/create")
        XCTAssertTrue((url?.query ?? "").contains("truncated=no"))
    }

    func testCustomTemplateSubstitution() {
        let template = "flomoapp://share?content={title}%20{content}%20{tagsHash}"
        let url = ExportService.customURL(template: template, payload: makePayload())
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "flomoapp")
        XCTAssertEqual(url?.host, "share")
        let query = url?.query ?? ""
        XCTAssertTrue(query.contains("flomoapp") == false, "结构不应被转义")
        XCTAssertTrue(query.contains("%20") || query.contains(" "), "标题与内容间应有分隔")
    }

    func testCustomTemplateEncodesAmpersandInValue() {
        let payload = ExportPayload(title: "A&B", text: "x=1&y=2", tags: [])
        let url = ExportService.customURL(template: "app://create?title={title}&body={content}", payload: payload)
        let query = url?.query ?? ""
        XCTAssertFalse(query.contains("body=x=1&y=2"), "值内的 & 必须被转义，否则破坏模板结构")
        XCTAssertTrue(query.contains("%26"))
    }

    func testCustomTemplateEmptyReturnsNil() {
        XCTAssertNil(ExportService.customURL(template: "", payload: makePayload()))
    }

    func testSafeTitleStripsInvalidCharacters() {
        let payload = ExportPayload(title: "a/b\\c:d", text: "", tags: [])
        XCTAssertEqual(payload.safeTitle, "abcd")
    }

    func testEncodedKeepsStructureCharacters() {
        XCTAssertEqual(ExportService.encoded("hello world"), "hello%20world")
        XCTAssertEqual(ExportService.encoded("a&b=c"), "a%26b%3Dc")
    }
}
