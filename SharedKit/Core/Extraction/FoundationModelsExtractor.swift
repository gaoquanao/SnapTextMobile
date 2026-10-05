import Foundation

#if canImport(FoundationModels)

import FoundationModels

/// iOS 26+ 端侧大模型提取（Apple Intelligence 设备）。
/// 本文件仅在 Xcode 26 / iOS 26 SDK 下参与编译；旧 SDK 构建时整个实现被编译门控剔除，
/// 运行时自动退回 NaturalLanguageExtractor。
@available(iOS 26, *)
@Generable
struct FMKnowledge {
    @Guide var title: String
    @Guide var summary: String
    @Guide var tags: [String]
    @Guide var category: String
}

@available(iOS 26, *)
enum FoundationModelsExtractor {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static func extract(from text: String) async throws -> KnowledgeExtract {
        let session = LanguageModelSession(model: .system)
        let clipped = String(text.prefix(3000))
        let prompt = """
        请分析下面这段从截图识别出的文字，提炼知识元数据。
        要求：title 是全文的浓缩摘要，不超过 20 个字；summary 不超过 60 字；tags 为 3-5 个关键词；
        category 从「灵感」「待办」「代码」「文章」「联系人」「账号」「地址」「其他」中选择。

        文本内容：
        \(clipped)
        """
        let response = try await session.respond(to: prompt, generating: FMKnowledge.self)
        let content = response.content
        return KnowledgeExtract(
            title: String(content.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20)),
            summary: content.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: content.tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(5)
                .map(String.init),
            category: content.category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// 端侧大模型润色：把 OCR 碎片文本整理成 Markdown。
    /// 严格限定「只排版不改写」，调用方另有长度守门兜底。
    static func polish(_ text: String) async throws -> String {
        let session = LanguageModelSession(model: .system)
        let clipped = String(text.prefix(3000))
        let prompt = """
        你是文本排版助手。请把下面从截图 OCR 得到的文字整理成 Markdown：
        1. 把被硬换行截断的段落合并为完整段落，修正标点与空格为规范用法；
        2. 数字序号、项目符号等列表项保持逐行；
        3. 只做排版与标点修正，逐字保留原文内容——不得改写、增删、翻译任何文字，不确定时保持原样。

        只输出整理后的 Markdown 正文，不要任何解释或代码块围栏。

        原文：
        \(clipped)
        """
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#endif
