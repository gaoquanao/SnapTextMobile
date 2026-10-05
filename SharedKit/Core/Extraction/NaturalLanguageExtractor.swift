import Foundation
import NaturalLanguage

/// 规则式提取（全设备可用）：首行标题、首句摘要、词频关键词（去停用词）+ 命名实体。
enum NaturalLanguageExtractor {
    static func extract(from text: String) -> KnowledgeExtract {
        let title = extractTitle(from: text)
        let summary = extractSummary(from: text)
        let tags = extractTags(from: text)
        return KnowledgeExtract(title: title, summary: summary, tags: tags, category: "")
    }

    /// 标题 = 全文摘要，限制在 20 字以内：优先取首句，超长则在词/字边界收窄。
    static func extractTitle(from text: String, limit: Int = 20) -> String {
        let firstLine = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        // 取首句（到句末标点为止）
        var sentence = firstLine
        if let endIndex = firstLine.firstIndex(where: { ["。", "！", "？", ".", "!", "?", "；", ";", "，", ","].contains($0) }) {
            sentence = String(firstLine[..<endIndex])
        }
        var title = sentence.trimmingCharacters(in: .whitespaces)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "。！？.!?，,；;：:、"))

        guard title.count > limit else { return title }
        var clipped = String(title.prefix(limit))
        // 英文尽量不在单词中间截断
        if let last = clipped.last, last.isLetter, clipped.contains(" "),
           let lastSpace = clipped.lastIndex(of: " ") {
            clipped = String(clipped[..<lastSpace])
        }
        return clipped.trimmingCharacters(in: .whitespaces)
    }

    static func extractSummary(from text: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var firstSentence = ""
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            firstSentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return false
        }
        let summary = firstSentence.isEmpty ? text : firstSentence
        return String(summary.prefix(80))
    }

    static func extractTags(from text: String, limit: Int = 5) -> [String] {
        var candidates: [String: Int] = [:]

        // 命名实体优先（中英通用，未下载中文模型的设备上可能为空）。
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .nameType) { tag, range in
            if let tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.count >= 2 { candidates[name, default: 0] += 3 }
            }
            return true
        }

        // 词频兜底。
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) {
            tokenizer.setLanguage(language)
        }
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if word.count >= 2, word.count <= 12, !isStopWord(word) {
                candidates[word, default: 0] += 1
            }
            return true
        }

        return candidates
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key.count > rhs.key.count
            }
            .prefix(limit)
            .map(\.key)
    }

    private static let stopWords: Set<String> = [
        "的", "了", "是", "我", "你", "他", "她", "它", "我们", "你们", "他们", "她们",
        "这", "那", "这个", "那个", "这些", "那些", "和", "与", "也", "就", "都", "很",
        "在", "有", "不", "没", "吗", "呢", "吧", "啊", "呀", "哦", "嗯", "咱", "啥",
        "什么", "怎么", "为什么", "因为", "所以", "但是", "而且", "如果", "虽然",
        "然后", "现在", "今天", "昨天", "明天", "可以", "应该", "需要", "会", "能",
        "要", "等", "还是", "或者", "以及", "关于", "对于", "通过", "作为", "一个",
        "一些", "这种", "那种", "自己", "别人", "大家", "时候", "地方", "东西", "事情",
        "问题", "方法", "一下", "一直", "一定", "可能", "已经", "这样", "那样",
        "the", "a", "an", "and", "or", "but", "if", "then", "of", "to", "in", "on",
        "for", "with", "at", "by", "is", "are", "was", "were", "be", "been", "it",
        "this", "that", "these", "those", "i", "you", "he", "she", "we", "they",
        "as", "not", "no", "so", "do", "does", "did", "have", "has", "had", "will",
        "would", "can", "could", "should", "from", "about", "into", "over", "after"
    ]

    static func isStopWord(_ word: String) -> Bool {
        stopWords.contains(word.lowercased())
    }
}
