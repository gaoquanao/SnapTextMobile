import Foundation

/// 自动提取的知识元数据。
struct KnowledgeExtract: Equatable {
    var title: String
    var summary: String
    var tags: [String]
    var category: String

    static let empty = KnowledgeExtract(title: "", summary: "", tags: [], category: "")
}

/// 提取管道调度：iOS 26+ 且 Apple Intelligence 可用时走端侧大模型，否则退回 NaturalLanguage 规则提取。
enum KnowledgeExtractor {
    static func extract(from text: String) async -> KnowledgeExtract {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .empty }

        #if canImport(FoundationModels)
        if FoundationModelsExtractor.isAvailable {
            if let result = try? await FoundationModelsExtractor.extract(from: cleaned) {
                return result
            }
        }
        #endif
        return NaturalLanguageExtractor.extract(from: cleaned)
    }
}
