import SwiftData
import XCTest
@testable import SnapText

final class AverageHashTests: XCTestCase {
    private func solidImage(_ color: UIColor, size: CGFloat = 64) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    private func splitImage(topWhite: Bool, size: CGFloat = 64) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            (topWhite ? UIColor.white : UIColor.black).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size / 2))
            (topWhite ? UIColor.black : UIColor.white).setFill()
            ctx.fill(CGRect(x: 0, y: size / 2, width: size, height: size / 2))
        }
    }

    func testDeterministic() {
        let image = splitImage(topWhite: true)
        XCTAssertEqual(ImagePreprocessor.averageHash(image), ImagePreprocessor.averageHash(image))
    }

    func testUniformImageGivesZero() {
        XCTAssertEqual(ImagePreprocessor.averageHash(solidImage(.white)), 0)
        XCTAssertEqual(ImagePreprocessor.averageHash(solidImage(.black)), 0)
    }

    func testDifferentImagesGiveDifferentHash() {
        XCTAssertNotEqual(
            ImagePreprocessor.averageHash(splitImage(topWhite: true)),
            ImagePreprocessor.averageHash(splitImage(topWhite: false))
        )
    }
}

@MainActor
final class DuplicateDetectorTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ArchiveStore.schema, configurations: [config])
        return ModelContext(container)
    }

    func testDetectsByTextEquality() throws {
        let context = try makeContext()
        context.insert(ArchiveEntry(source: .importAction, imageData: nil, recognizedText: "会议纪要内容", title: "纪要", summary: "", tags: []))
        try context.save()
        XCTAssertNotNil(CapturePipeline.findDuplicate(text: "会议纪要内容", hash: 0, in: context))
    }

    func testDetectsByHashAndText() throws {
        let context = try makeContext()
        context.insert(ArchiveEntry(source: .importAction, imageData: nil, recognizedText: "同一张图", title: "t", summary: "", tags: [], imageHash: 42))
        try context.save()
        XCTAssertNotNil(CapturePipeline.findDuplicate(text: "同一张图", hash: 42, in: context))
    }

    func testNoFalsePositiveOnDifferentText() throws {
        let context = try makeContext()
        context.insert(ArchiveEntry(source: .importAction, imageData: nil, recognizedText: "文本A", title: "t", summary: "", tags: [], imageHash: 7))
        try context.save()
        // 哈希相同但文本不同：不算重复。
        XCTAssertNil(CapturePipeline.findDuplicate(text: "完全不同的文本", hash: 7, in: context))
        // 文本完全相同：即使哈希不同也算重复（文本是更强的信号）。
        XCTAssertNotNil(CapturePipeline.findDuplicate(text: "文本A", hash: 999, in: context))
    }

    func testHashMatchWithDifferentTextIsNotDuplicate() throws {
        let context = try makeContext()
        context.insert(ArchiveEntry(source: .importAction, imageData: nil, recognizedText: "旧文本", title: "t", summary: "", tags: [], imageHash: 7))
        try context.save()
        XCTAssertNil(CapturePipeline.findDuplicate(text: "新文本内容不同", hash: 7, in: context))
    }
}

final class ExportAllBuilderTests: XCTestCase {
    private func makeEntries() -> [ArchiveEntry] {
        [
            ArchiveEntry(createdAt: Date(timeIntervalSince1970: 100), source: .share, imageData: nil, recognizedText: "第一条内容", title: "第一条", summary: "摘要一", tags: ["AI"]),
            ArchiveEntry(createdAt: Date(timeIntervalSince1970: 200), source: .camera, imageData: nil, recognizedText: "第二条内容", title: "第二条", summary: "", tags: ["iOS", "笔记"], category: "灵感"),
        ]
    }

    func testMarkdownContainsAllEntries() {
        let markdown = ExportAllBuilder.markdown(entries: makeEntries())
        // 断言只针对数据字段，界面标签随系统语言变化。
        XCTAssertTrue(markdown.contains("## 第一条"))
        XCTAssertTrue(markdown.contains("## 第二条"))
        XCTAssertTrue(markdown.contains("第一条内容"))
        XCTAssertTrue(markdown.contains("#AI"))
        XCTAssertTrue(markdown.contains("#iOS #笔记"))
        XCTAssertTrue(markdown.contains("灵感"))
    }

    func testJSONRoundTrip() throws {
        let entries = makeEntries()
        let data = try ExportAllBuilder.jsonData(entries: entries)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ExportAllBuilder.JSONEntry].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].title, "第一条")
        XCTAssertEqual(decoded[1].tags, ["iOS", "笔记"])
    }

    func testTempFileURLWrites() {
        let url = ExportAllBuilder.tempFileURL(content: "hello", name: "test-export.md")
        XCTAssertNotNil(url)
        XCTAssertEqual((try? String(contentsOf: url!, encoding: .utf8)), "hello")
    }
}

@MainActor
final class ScreenshotCleanupPolicyTests: XCTestCase {
    func testDisabledByDefault() {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.autoDeleteScreenshots)
        XCTAssertFalse(ScreenshotCleanupPolicy.isEnabled, "清理策略必须默认关闭")
    }

    func testDisabledRunReturnsZeroWithoutTouchingPhotos() async {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.autoDeleteScreenshots)
        // 关闭状态下即使传入资产 ID 也应立即返回 0，不触发任何照片库访问。
        let cleaned = await ScreenshotCleanupPolicy.run(assetIDs: ["fake-id-1", "fake-id-2"])
        XCTAssertEqual(cleaned, 0)
    }

    func testSummaryWithoutCleanupHasNoSuffix() {
        let base = ScreenshotCleanupPolicy.summary(archived: 2, skipped: 1, cleaned: 0)
        // 用与实现相同的插值路径构造期望值（避免字面量数字不进目录导致回退）。
        let expected = String(localized: "新增 \(2) 条，跳过 \(1) 张")
        XCTAssertEqual(base, expected)
        XCTAssertFalse(base.contains("·"))
    }

    func testSummaryWithCleanupAppendsCount() {
        let text = ScreenshotCleanupPolicy.summary(archived: 2, skipped: 1, cleaned: 3)
        XCTAssertTrue(text.contains("·"))
        XCTAssertTrue(text.contains("3"), "摘要应包含清理数量")
    }
}
