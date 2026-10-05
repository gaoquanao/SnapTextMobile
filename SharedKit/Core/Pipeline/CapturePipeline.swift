import SwiftData
import UIKit

/// 捕获管线：缩放 → 查重 → OCR → 知识提取 → 入库。所有行为路径共用。
@MainActor
enum CapturePipeline {
    struct Outcome {
        let entry: ArchiveEntry
        let extract: KnowledgeExtract
        /// 命中重复：entry 指向既有归档，未新建。
        var isDuplicate: Bool = false
    }

    static func capture(
        image: UIImage,
        source: ArchiveSource,
        context: ModelContext? = nil
    ) async throws -> Outcome {
        let scaled = ImagePreprocessor.downscale(image)
        let rawText = try await TextRecognizer.recognize(scaled)
        // 规整为可读 Markdown（合并断行、修标点空格）；iOS 26 支持时追加端侧大模型润色。
        let text = await TextPolishService.polish(rawText)
        let extract = await KnowledgeExtractor.extract(from: text)
        let hash = ImagePreprocessor.averageHash(scaled)

        let target = context ?? ArchiveStore.mainContext

        if let existing = findDuplicate(text: text, hash: hash, in: target) {
            return Outcome(entry: existing, extract: extract, isDuplicate: true)
        }

        let entry = ArchiveEntry(
            source: source,
            imageData: ImagePreprocessor.jpegData(image),
            recognizedText: text,
            title: extract.title.isEmpty ? String(localized: "未命名速记") : extract.title,
            summary: extract.summary,
            tags: extract.tags,
            category: extract.category,
            imageHash: hash
        )
        target.insert(entry)
        try? target.save()
        return Outcome(entry: entry, extract: extract)
    }

    /// 查重：感知哈希相同且 OCR 文本一致，或 OCR 文本完全一致（更稳的信号）。
    static func findDuplicate(text: String, hash: Int64, in context: ModelContext) -> ArchiveEntry? {
        let textDescriptor = FetchDescriptor<ArchiveEntry>(
            predicate: #Predicate { $0.recognizedText == text }
        )
        if let exactText = try? context.fetch(textDescriptor), let match = exactText.first {
            return match
        }
        let hashDescriptor = FetchDescriptor<ArchiveEntry>(
            predicate: #Predicate { $0.imageHash == hash }
        )
        if let sameHash = try? context.fetch(hashDescriptor),
           let match = sameHash.first(where: { $0.recognizedText == text }) {
            return match
        }
        return nil
    }
}
