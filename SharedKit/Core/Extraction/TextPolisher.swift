import Foundation

/// OCR 文本规整：把截图识别出的「逐行碎片文本」整理成可读的 Markdown。
///
/// 处理内容：
/// - 合并被硬换行截断的段落（中文不加空格，英文加空格）
/// - 清理异常空格（CJK 字间空格、标点前后空格）
/// - 标点规范化（CJK 语境半角转全角、连续重复标点折叠、全角字母数字转半角）
/// - 保留列表结构（数字序号、项目符号、圈码逐行保留）
enum TextPolisher {
    // MARK: - 入口

    static func normalize(_ raw: String) -> String {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { normalizeLine($0) }
        return assemble(lines)
    }

    // MARK: - 单行规整

    static func normalizeLine(_ line: String) -> String {
        var text = line

        // OCR 常见的协议前缀残缺：https:/x → https://x（仅补协议斜杠，不碰其余内容）
        text = text.replacingOccurrences(of: "https:/", with: "https://")
        text = text.replacingOccurrences(of: "http:/", with: "http://")
        // 避免把本就正确的 "https://" 变成 "https:///"（上两步若已双斜杠则不会重复消费）
        while text.contains("https:///") {
            text = text.replacingOccurrences(of: "https:///", with: "https://")
        }
        while text.contains("http:///") {
            text = text.replacingOccurrences(of: "http:///", with: "http://")
        }

        // 全角字母数字 → 半角
        text = String(text.map { ch in
            guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return ch }
            switch scalar.value {
            case 0xFF01...0xFF5E:
                if let ascii = UnicodeScalar(scalar.value - 0xFEE0) {
                    return Character(ascii)
                }
                return ch
            case 0x3000:
                return " "
            default:
                return ch
            }
        })

        // 连续空白折叠
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        // 删除 CJK 字符之间的空格（OCR 逐字框常产生）
        text = removingSpacesBetweenCJK(text)

        // 标点前后空格清理
        text = fixingPunctuationSpacing(text)

        // CJK 语境半角标点 → 全角
        text = normalizingPunctuation(text)

        // 连续重复标点折叠（中英文省略号/破折号允许双写）
        text = collapsingRepeatedPunctuation(text)

        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func removingSpacesBetweenCJK(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        for ch in text {
            if ch == " " {
                pendingSpace = true
                continue
            }
            if pendingSpace {
                let prev = result.last
                if let prev, isCJK(prev), (isCJK(ch) || isCJKPunctuation(ch)) {
                    // CJK 与 CJK（或其后标点）之间不留空格
                } else if let prev, isCJKPunctuation(prev), isCJK(ch) {
                    // 标点与后续 CJK 之间不留空格
                } else {
                    result.append(" ")
                }
                pendingSpace = false
            }
            result.append(ch)
        }
        if pendingSpace { result.append(" ") }
        return result
    }

    private static func fixingPunctuationSpacing(_ text: String) -> String {
        // 1) 标点前的空格一律删除
        var result = text
        let noSpaceBefore: [Character] = ["，", "。", "！", "？", "；", "：", "、", "）", "】", "》", "”", "』", "」", ",", ".", "!", "?", ";", ":", ")", "]", "}"]
        for punct in noSpaceBefore {
            result = result.replacingOccurrences(of: " \(punct)", with: String(punct))
        }

        // 2) CJK 标点后紧跟 CJK 时不留空格；3) 西文标点后紧跟西文字母时补一个空格（小数/版本号除外）
        var output = ""
        let chars = Array(result)
        let cjkNoSpaceAfter: Set<Character> = ["，", "。", "！", "？", "；", "：", "、", "）", "】", "》"]
        let latinNeedSpaceAfter: Set<Character> = [",", ".", ";", ":"]
        for index in chars.indices {
            let ch = chars[index]

            // 行中分隔点（•/·）两侧补空格："42•keep" → "42 • keep"（行首列表符号除外）
            if ["•", "·"].contains(ch), index > 0 {
                if let last = output.last, last != " " {
                    output.append(" ")
                }
                output.append(ch)
                if index + 1 < chars.count, chars[index + 1] != " " {
                    output.append(" ")
                }
                continue
            }

            output.append(ch)
            guard index + 1 < chars.count else { continue }
            let next = chars[index + 1]
            if cjkNoSpaceAfter.contains(ch), next == " " {
                // 跳过标点后的空格（如果空格后是 CJK）
                if index + 2 < chars.count, isCJK(chars[index + 2]) {
                    continue
                }
            }
            if latinNeedSpaceAfter.contains(ch), next != " ", isLatinOrDigit(next) {
                // 数字语境（小数 1.5、时间 5:30、千分位 1,000）不插空格
                let prev = index > 0 ? chars[index - 1] : nil
                let isNumericContext = (prev?.isNumber ?? false) && next.isNumber
                // 句点后仅在下一字符是大写字母时补空格（句子边界）；
                // 避免破坏邮箱/域名/文件名的连续小写（example.com → 保持原样）
                let isSentenceDot = ch == "." && next.isUppercase
                let shouldInsert = ch != "." ? !isNumericContext : isSentenceDot
                if shouldInsert {
                    output.append(" ")
                }
            }
        }
        return output
    }

    private static func normalizingPunctuation(_ text: String) -> String {
        let mapping: [Character: Character] = [
            ",": "，", ".": "。", "!": "！", "?": "？", ";": "；", ":": "：",
            "(": "（", ")": "）",
        ]
        var chars = Array(text)
        for index in chars.indices {
            guard let full = mapping[chars[index]] else { continue }
            let prev = index > 0 ? chars[index - 1] : nil
            let next = index + 1 < chars.count ? chars[index + 1] : nil
            let prevIsCJK = prev.map { isCJK($0) } ?? false
            let nextIsCJK = next.map { isCJK($0) } ?? false
            let prevIsLatinDigit = prev.map { isLatinOrDigit($0) } ?? false
            let nextIsLatinDigit = next.map { isLatinOrDigit($0) } ?? false
            // 数字语境不转换，避免破坏 1.5、iOS 5:30、v1.2
            if [".", ",", ":", ";"].contains(chars[index]), prevIsLatinDigit || nextIsLatinDigit {
                continue
            }
            // 括号仅在贴 CJK 时还原全角
            if ["(", ")"].contains(chars[index]), !prevIsCJK, !nextIsCJK {
                continue
            }
            if prevIsCJK || nextIsCJK {
                chars[index] = full
            }
        }
        return String(chars)
    }

    private static func collapsingRepeatedPunctuation(_ text: String) -> String {
        var result = ""
        var lastPunct: Character?
        var run = 0
        for ch in text {
            if ch == lastPunct, let last = lastPunct, isCollapsiblePunctuation(last) {
                run += 1
                let allowed = (last == "…" || last == "—" || last == ".") ? 2 : 1
                if run <= allowed {
                    result.append(ch)
                }
            } else {
                result.append(ch)
                lastPunct = isPunctuation(ch) ? ch : nil
                run = 1
            }
        }
        return result
    }

    // MARK: - 段落组装

    static func assemble(_ lines: [String]) -> String {
        var paragraphs: [String] = []
        var current = ""

        func flush() {
            if !current.isEmpty {
                paragraphs.append(current)
                current = ""
            }
        }

        for line in lines {
            if line.isEmpty {
                flush()
                continue
            }
            if isListLine(line) {
                flush()
                // 连续列表项用单个换行相连（Markdown 里空行会拆成两个列表）
                if let last = paragraphs.last, isListLine(last) {
                    paragraphs[paragraphs.count - 1] = last + "\n" + normalizeListMarker(line)
                } else {
                    paragraphs.append(normalizeListMarker(line))
                }
                continue
            }
            if current.isEmpty {
                current = line
                continue
            }
            if shouldBreakParagraph(after: current, nextLine: line) {
                flush()
                current = line
            } else {
                current += joiner(previous: current.last, next: line.first) + line
            }
        }
        flush()
        return paragraphs.joined(separator: "\n\n")
    }

    /// 列表标记与内容之间补一个空格（"1.牛腩" → "1. 牛腩"），否则 Markdown 不识别为列表。
    static func normalizeListMarker(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return line }
        // 项目符号：- 或 • 后无空格时补上
        if ["-", "•", "*"].contains(first) {
            let rest = trimmed.dropFirst()
            if let next = rest.first, next != " " {
                return "\(first) \(rest)"
            }
            return trimmed
        }
        // 数字/中文序号：找到分隔符，其后无空格时补上
        let separators: [Character] = [".", "、", ")", "．"]
        if let index = trimmed.firstIndex(where: { separators.contains($0) }) {
            let after = trimmed.index(after: index)
            if after == trimmed.endIndex { return trimmed }
            if trimmed[after] != " " {
                return String(trimmed[..<after]) + " " + String(trimmed[after...])
            }
        }
        return trimmed
    }

    /// 断段规则：
    /// - 上一行以句末标点结尾（完整的句子/段落）；
    /// - 上一行是「强独立行」（署名、联系方式、标签值等结构化信息），不与下文合并；
    /// - 两行都是独立行（名片、聊天短句等）。
    /// 其余连续长行视为被硬换行截断的同一段落，继续合并。
    static func shouldBreakParagraph(after line: String, nextLine: String) -> Bool {
        if let last = line.last, isSentenceEnd(last) {
            return true
        }
        if isStrongStandaloneLine(line) {
            return true
        }
        return isShortLine(line) && isStandaloneLine(nextLine)
    }

    /// 独立行：强独立行，或语义上大概率自成一行（短行）。
    static func isStandaloneLine(_ line: String) -> Bool {
        isStrongStandaloneLine(line) || isShortLine(line)
    }

    /// 强独立行：带有明确的结构特征，几乎必然独立成段。
    static func isStrongStandaloneLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first, ["—", "–"].contains(String(first)) { return true }
        if trimmed.hasPrefix("——") { return true }
        if trimmed.contains("@") || trimmed.contains("://") { return true }
        if trimmed.range(of: #"\d[\d\- ]{5,}\d"#, options: .regularExpression) != nil { return true }
        if let colon = trimmed.firstIndex(where: { $0 == "：" || $0 == ":" }) {
            let label = trimmed[trimmed.startIndex..<colon]
            let value = trimmed[trimmed.index(after: colon)...]
            if !label.isEmpty, label.count <= 8, !value.isEmpty, value.count <= 30 {
                return true
            }
        }
        return false
    }

    /// 短行：字符数少且不以连接性标点结尾（如逗号后还有下文）。
    static func isShortLine(_ line: String) -> Bool {
        guard line.count < 16 else { return false }
        if let last = line.last, ["，", ",", "、", "：", ":", "（", "("].contains(last) {
            return false
        }
        return true
    }

    /// 跨行拼接分隔符：中文之间不空格，其余（含中英交界）加一个空格。
    static func joiner(previous: Character?, next: Character?) -> String {
        guard let previous, let next else { return "" }
        if isCJKPunctuation(previous) { return "" }
        if isCJK(previous) && isCJK(next) { return "" }
        return " "
    }

    /// 列表行：数字序号、项目符号、圈码等，逐行保留。
    static func isListLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        if ["-", "•", "·", "*", "▶", "▪"].contains(first) { return true }
        if ("①"..."⑳").contains(first) { return true }
        // 数字序号：1. 1、 1) （含全角已转半角）
        if first.isNumber {
            let rest = trimmed.dropFirst()
            if let sep = rest.first, [".", "、", ")", "．"].contains(sep) { return true }
            if rest.first?.isNumber == true {
                let afterTwo = rest.dropFirst()
                if let sep = afterTwo.first, [".", "、", ")"].contains(sep) { return true }
            }
        }
        // 中文序号：一、 二、
        if "一二三四五六七八九十".contains(first) {
            let rest = trimmed.dropFirst()
            if let sep = rest.first, ["、", "."].contains(sep) { return true }
        }
        return false
    }

    // MARK: - 字符分类

    static func isCJK(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x2E80...0x2EFF, 0x3000...0x303F, 0x3040...0x30FF,
                 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0xAC00...0xD7AF, 0xFF00...0xFFEF:
                true
            default:
                false
            }
        }
    }

    static func isCJKPunctuation(_ ch: Character) -> Bool {
        guard isCJK(ch), !ch.isLetter, !ch.isNumber else { return false }
        return true
    }

    static func isPunctuation(_ ch: Character) -> Bool {
        !(ch.isLetter || ch.isNumber || ch.isWhitespace)
    }

    static func isLatinOrDigit(_ ch: Character) -> Bool {
        ch.isASCII && (ch.isLetter || ch.isNumber)
    }

    static func isSentenceEnd(_ ch: Character) -> Bool {
        ["。", "！", "？", ".", "!", "?", "…", "；", ";", "」", "』", "”", "】", "）"].contains(ch)
    }

    private static func isCollapsiblePunctuation(_ ch: Character) -> Bool {
        // 引号、括号、斜杠（URL 的 // 与路径）、波浪号等不参与折叠
        isPunctuation(ch) && !["\"", "'", "「", "『", "（", "(", "《", "【", "/", "~", "@", "#", "%"].contains(ch)
    }
}
