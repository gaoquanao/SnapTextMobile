import XCTest
@testable import SnapText

final class EntityExtractorTests: XCTestCase {
    private func values(_ kind: TextEntity.Kind, in text: String) -> [String] {
        EntityExtractor.extract(from: text).filter { $0.kind == kind }.map(\.value)
    }

    // MARK: - 电话

    func testExtractsSegmentedMobileNumber() {
        XCTAssertEqual(values(.phone, in: "电话 138-1234-5678 张伟"), ["138-1234-5678"])
    }

    func testExtractsPlainMobileNumber() {
        XCTAssertEqual(values(.phone, in: "手机 13812345678"), ["13812345678"])
    }

    func testExtractsLandlineAndInternationalPrefix() {
        XCTAssertEqual(values(.phone, in: "座机 010-12345678"), ["010-12345678"])
        XCTAssertEqual(values(.phone, in: "call +86 138 1234 5678"), ["+86 138 1234 5678"])
    }

    // MARK: - 邮箱 / 链接

    func testExtractsEmail() {
        XCTAssertEqual(values(.email, in: "邮箱 zhangwei@example.com，请联系"), ["zhangwei@example.com"])
    }

    func testExtractsURL() {
        XCTAssertEqual(values(.url, in: "官网 https://example.com/docs 查看"), ["https://example.com/docs"])
        XCTAssertEqual(values(.url, in: "访问 www.example.com 了解更多"), ["www.example.com"])
    }

    // MARK: - 日期 / 数字

    func testExtractsDateAndTime() {
        XCTAssertEqual(values(.date, in: "2026年10月5日 发布"), ["2026年10月5日"])
        XCTAssertEqual(values(.date, in: "会议 2026-10-05 开始"), ["2026-10-05"])
        XCTAssertEqual(values(.date, in: "时间 5:30 开始"), ["5:30"])
    }

    func testExtractsNumbersWithUnits() {
        let numbers = values(.number, in: "约 30 亿参数，价格 99 元")
        XCTAssertTrue(numbers.contains("30 亿") || numbers.contains("30亿"))
        XCTAssertTrue(numbers.contains("99 元"))
    }

    // MARK: - 误报排除

    func testDoesNotTreatListMarkerAsNumber() {
        XCTAssertTrue(values(.number, in: "1. 牛腩冷水下锅\n2. 热油炒香").isEmpty)
    }

    func testDoesNotExtractNumberFromAlphanumericToken() {
        // WWDC26 中的 26 不应成为数字组
        XCTAssertTrue(values(.number, in: "WWDC26 主题演讲").isEmpty)
    }

    func testDoesNotDuplicatePhoneDigitsAsNumbers() {
        let entities = EntityExtractor.extract(from: "电话 138-1234-5678")
        XCTAssertTrue(entities.filter { $0.kind == .number }.isEmpty, "电话内的数字不应重复出现在数字组")
    }

    func testTimeIsNotSplitIntoNumbers() {
        XCTAssertTrue(values(.number, in: "时间 5:30 开始").isEmpty)
    }

    func testSingleDigitWithoutUnitIgnored() {
        XCTAssertTrue(values(.number, in: "第 3 章").isEmpty)
    }

    // MARK: - 排序、去重与限量

    func testEntitiesSortedByKind() {
        let text = "价格 99 元，官网 https://example.com，邮箱 a@b.com，电话 13812345678"
        let kinds = EntityExtractor.extract(from: text).map(\.kind)
        XCTAssertEqual(kinds, [.phone, .email, .url, .number])
    }

    func testDuplicatesRemoved() {
        let values = values(.email, in: "a@b.com 和 a@b.com 是同一个邮箱")
        XCTAssertEqual(values, ["a@b.com"])
    }

    func testNumberLimitApplied() {
        let text = "12 34 56 78 90 11 22 33 44"
        let numbers = values(.number, in: text)
        XCTAssertLessThanOrEqual(numbers.count, 6)
    }

    // MARK: - 词块映射

    func testMatchingTokenIDsForPhone() {
        let text = "电话 138-1234-5678"
        let tokens = TextTokenizer.tokenize(text)
        guard let phone = EntityExtractor.extract(from: text).first(where: { $0.kind == .phone }) else {
            return XCTFail("未提取到电话")
        }
        let ids = EntityExtractor.matchingTokenIDs(for: phone, in: tokens)
        XCTAssertFalse(ids.isEmpty)
        let joined = TokenJoiner.join(ids.sorted().compactMap { id in tokens.first { $0.id == id } })
        XCTAssertEqual(joined, "138-1234-5678", "电话内的连字符不应被拆开")
    }

    func testMatchingTokenIDsForEmail() {
        let text = "邮箱 zhangwei@example.com"
        let tokens = TextTokenizer.tokenize(text)
        guard let email = EntityExtractor.extract(from: text).first(where: { $0.kind == .email }) else {
            return XCTFail("未提取到邮箱")
        }
        let ids = EntityExtractor.matchingTokenIDs(for: email, in: tokens)
        let joined = TokenJoiner.join(ids.sorted().compactMap { id in tokens.first { $0.id == id } })
        XCTAssertEqual(joined, "zhangwei@example.com", "邮箱内的点与 @ 不应被拆开")
    }

    func testMatchingTokenIDsReturnsEmptyForMissingValue() {
        let tokens = TextTokenizer.tokenize("无关文本")
        let entity = TextEntity(id: 0, kind: .phone, value: "13812345678")
        XCTAssertTrue(EntityExtractor.matchingTokenIDs(for: entity, in: tokens).isEmpty)
    }

    // MARK: - 综合场景

    func testBusinessCardScenario() {
        let text = """
        张伟
        产品经理 · 极光科技
        电话 138-1234-5678
        邮箱 zhangwei@example.com
        地址：上海市浦东新区世纪大道 100 号
        官网 https://example.com
        """
        let entities = EntityExtractor.extract(from: text)
        XCTAssertTrue(entities.contains { $0.kind == .phone })
        XCTAssertTrue(entities.contains { $0.kind == .email })
        XCTAssertTrue(entities.contains { $0.kind == .url })
        // 「世纪大道 100 号」中的 100 应作为数字提取
        XCTAssertTrue(entities.contains { $0.kind == .number && $0.value.contains("100") })
    }
}
