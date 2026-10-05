import Foundation
import NaturalLanguage

/// 大爆炸文本块。
struct TextToken: Identifiable, Equatable {
    enum Kind: Equatable {
        case word
        case punctuation
    }

    let id: Int
    let text: String
    let kind: Kind
    /// 所属句子序号（用于「整句选」）。
    var sentenceIndex: Int
    /// 所属原文行号（跨行复制时还原换行）。
    var lineIndex: Int = 0
    /// 所属原文段落号（跨段复制时还原空行分隔）。
    var paragraphIndex: Int = 0
    /// 原文中该词块与前一个词块之间是否有空白（复制时忠实还原，邮箱/域名/版本号不被拆开）。
    var spacedBefore: Bool = true

    var isPunctuation: Bool { kind == .punctuation }
}

/// 混合分词：字母/CJK 连续段交给 NLTokenizer 出词级 token，
/// 标点逐个独立成块，空白不入块（由流式布局的间隙隐含）；
/// 换行按原文保留成行/段索引，供词墙分段渲染与跨行复制还原结构。
enum TextTokenizer {
    private enum CharClass {
        case word
        case punctuation
        case space
    }

    static func tokenize(_ text: String) -> [TextToken] {
        // 统一换行符后按行切分，保留空行（空行 = 段落边界）。
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        var texts: [String] = []
        var kinds: [TextToken.Kind] = []
        var lineIndices: [Int] = []
        var paragraphIndices: [Int] = []
        var spacedBefores: [Bool] = []

        var paragraph = 0
        var atParagraphBoundary = false
        for (lineIndex, line) in lines.enumerated() {
            if line.isEmpty {
                // 连续空行只算一次分隔。
                atParagraphBoundary = true
                continue
            }
            if atParagraphBoundary {
                paragraph += 1
                atParagraphBoundary = false
            }
            tokenizeLine(String(line)) { text, kind, spacedBefore in
                texts.append(text)
                kinds.append(kind)
                lineIndices.append(lineIndex)
                paragraphIndices.append(paragraph)
                spacedBefores.append(spacedBefore)
            }
        }

        // 句子归属：按句末标点切句（可跨行延续）。
        var result: [TextToken] = []
        var sentence = 0
        for index in texts.indices {
            result.append(TextToken(
                id: index,
                text: texts[index],
                kind: kinds[index],
                sentenceIndex: sentence,
                lineIndex: lineIndices[index],
                paragraphIndex: paragraphIndices[index],
                spacedBefore: spacedBefores[index]
            ))
            if kinds[index] == .punctuation, isSentenceTerminator(texts[index]) {
                sentence += 1
            }
        }
        return result
    }

    /// 单行内分词：词类字符连续段交给 NLTokenizer 出词级 token，标点逐个独立成块；
    /// 同时记录每个词块前是否有空白，供复制时忠实还原原文间隔。
    private static func tokenizeLine(_ line: String, emit: (String, TextToken.Kind, Bool) -> Void) {
        var run = ""
        var runIsWord = false
        // 行首视为有分隔；跨空白后的第一个词块为 true，同一连续段内其余词块为 false。
        var spacedBefore = true

        func flushRun() {
            guard !run.isEmpty else { return }
            if runIsWord {
                for (index, word) in splitWords(run).enumerated() {
                    emit(word, .word, index == 0 ? spacedBefore : false)
                }
            } else {
                for (index, ch) in run.enumerated() {
                    emit(String(ch), .punctuation, index == 0 ? spacedBefore : false)
                }
            }
            run = ""
            spacedBefore = false
        }

        for ch in line {
            switch classify(ch) {
            case .word:
                if !runIsWord { flushRun() }
                runIsWord = true
                run.append(ch)
            case .punctuation:
                if runIsWord { flushRun() }
                runIsWord = false
                run.append(ch)
            case .space:
                flushRun()
                spacedBefore = true
            }
        }
        flushRun()
    }

    /// 把一个「词类字符连续段」切成词；NLTokenizer 无结果时整段作为单个 token 兜底。
    private static func splitWords(_ run: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = run
        if let language = NLLanguageRecognizer.dominantLanguage(for: run) {
            tokenizer.setLanguage(language)
        }
        var words: [String] = []
        tokenizer.enumerateTokens(in: run.startIndex..<run.endIndex) { range, _ in
            words.append(String(run[range]))
            return true
        }
        // NLTokenizer 会跳过它认为非词的字符（如数字间的符号），兜底保证不丢字。
        let joined = words.joined()
        if words.isEmpty || joined.count != run.count {
            // 逐字对比代价高且极端场景少，直接整段兜底，保证文本不丢失。
            if words.isEmpty { return [run] }
            // 有丢失时补齐：按顺序用原串扫描对齐。
            return alignWords(words: words, in: run)
        }
        return words
    }

    /// NL 分词结果与原串对齐：跳过的字符并入相邻 token，保证拼回去等于原段。
    private static func alignWords(words: [String], in run: String) -> [String] {
        var aligned: [String] = []
        var cursor = run.startIndex
        for word in words {
            guard let range = run.range(of: word, range: cursor..<run.endIndex) else { continue }
            if range.lowerBound > cursor {
                aligned.append(String(run[cursor..<range.lowerBound]))
            }
            aligned.append(String(run[range]))
            cursor = range.upperBound
        }
        if cursor < run.endIndex {
            aligned.append(String(run[cursor..<run.endIndex]))
        }
        return aligned
    }

    private static func classify(_ ch: Character) -> CharClass {
        if ch.isLetter || ch.isNumber { return .word }
        if ch.isWhitespace || ch.isNewline { return .space }
        return .punctuation
    }

    private static func isSentenceTerminator(_ token: String) -> Bool {
        switch token {
        case "。", "！", "？", ".", "!", "?", "；", ";", "…":
            true
        default:
            false
        }
    }
}
