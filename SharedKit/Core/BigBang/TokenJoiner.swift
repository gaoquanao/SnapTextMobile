import Foundation

/// 选中 token 的拼接规则：
/// 以原文间隔为准（词块间原本有空白处补一个空格，无空白处直接相连，
/// 邮箱/域名/版本号等不被拆开）；跨行还原为单换行，跨段还原为分段空行。
/// 另有基于字符类别的 `join(_ pieces:)` 供无结构信息时使用。
enum TokenJoiner {
    static func join(_ tokens: [TextToken]) -> String {
        var result = ""
        var previous: TextToken?
        for token in tokens where !token.text.isEmpty {
            if let previous {
                if token.paragraphIndex > previous.paragraphIndex {
                    result += "\n\n"
                } else if token.lineIndex > previous.lineIndex {
                    result += "\n"
                } else if token.spacedBefore {
                    result += " "
                }
            }
            result += token.text
            previous = token
        }
        return result
    }

    static func join(_ pieces: [String]) -> String {
        var result = ""
        for piece in pieces where !piece.isEmpty {
            if result.isEmpty {
                result = piece
                continue
            }
            result += separator(between: result.last!, and: piece.first!)
            result += piece
        }
        return result
    }

    private static func separator(between lhs: Character, and rhs: Character) -> String {
        // 标点永远贴前词。
        if isPunctuation(rhs) { return "" }
        if isPunctuation(lhs) {
            // CJK 标点（，。！？等）与两侧汉字之间不加空格。
            if isCJK(lhs) { return "" }
            // 西文后标点（, . ! 等）与下一词之间加空格；前标点（「 ( 等）贴后词。
            return isClosingPunctuation(lhs) ? " " : ""
        }
        // 双侧都是 CJK 才不加空格；CJK 与西文交界处加空格。
        if isCJK(lhs) && isCJK(rhs) { return "" }
        return " "
    }

    static func isPunctuation(_ ch: Character) -> Bool {
        !(ch.isLetter || ch.isNumber)
    }

    static func isClosingPunctuation(_ ch: Character) -> Bool {
        switch ch {
        case "，", "。", "！", "？", "；", "：", "、", "）", "】", "》", "”", "』", "」", ">", ")", "]", "}", ",", ".", "!", "?", ";", ":", "%":
            true
        default:
            false
        }
    }

    static func isCJK(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x2E80...0x2EFF,   // 部首
                 0x3000...0x303F,   // CJK 符号和标点（。、「」等）
                 0x3040...0x30FF,   // 平假名/片假名
                 0x3400...0x4DBF,   // CJK 扩展 A
                 0x4E00...0x9FFF,   // CJK 统一表意
                 0xF900...0xFAFF,   // CJK 兼容表意
                 0xAC00...0xD7AF,   // 谚文
                 0xFF00...0xFFEF:   // 全角形式（，！？：等）
                true
            default:
                false
            }
        }
    }
}
