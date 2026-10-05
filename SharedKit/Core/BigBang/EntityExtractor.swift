import Foundation

/// 从识别文本中提取的结构化信息（电话 / 邮箱 / 链接 / 日期 / 数字）。
struct TextEntity: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case phone, email, url, date, number

        var id: String { rawValue }

        var symbolName: String {
            switch self {
            case .phone: "phone"
            case .email: "envelope"
            case .url: "link"
            case .date: "calendar"
            case .number: "number"
            }
        }

        var displayName: String {
            switch self {
            case .phone: String(localized: "电话")
            case .email: String(localized: "邮箱")
            case .url: String(localized: "链接")
            case .date: String(localized: "日期")
            case .number: String(localized: "数字")
            }
        }
    }

    let id: Int
    let kind: Kind
    let value: String
}

/// 规则式实体提取：正则匹配 + 误报排除（列表序号、时间、URl/电话内的数字等）。
enum EntityExtractor {
    /// 提取并按「电话 → 邮箱 → 链接 → 日期 → 数字」排序；数字限量避免刷屏。
    static func extract(from text: String, numberLimit: Int = 6, totalLimit: Int = 16) -> [TextEntity] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var claimed: [NSRange] = []
        var entities: [TextEntity] = []
        var seen = Set<String>()
        var nextID = 0

        func add(_ kind: TextEntity.Kind, _ range: NSRange) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            // 与已提取区间重叠的匹配跳过（如 +86 前缀电话同时命中多种电话模式）
            guard !claimed.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { return }
            let value = nsText.substring(with: range).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return }
            let key = "\(kind.rawValue)|\(value)"
            guard !seen.contains(key) else { return }
            seen.insert(key)
            claimed.append(range)
            entities.append(TextEntity(id: nextID, kind: kind, value: value))
            nextID += 1
        }

        // 电话：+86 可选前缀、11 位手机号（可含 - / 空格分段）、固话 0xxx-xxxxxxx、3-4-4 分段
        for pattern in [
            #"(?:\+?86[\s\-]?)?1[3-9]\d[\s\-]?\d{4}[\s\-]?\d{4}"#,
            #"0\d{2,3}[\s\-]?\d{7,8}"#,
            #"\d{3,4}[\s\-]\d{3,4}[\s\-]\d{3,4}"#,
        ] {
            matches(of: pattern, in: nsText, range: fullRange).forEach { add(.phone, $0) }
        }

        // 邮箱
        matches(of: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#, in: nsText, range: fullRange)
            .forEach { add(.email, $0) }

        // 链接
        matches(of: #"(?:https?://|www\.)[^\s，。；、）】》""'']+"#, in: nsText, range: fullRange)
            .forEach { add(.url, $0) }

        // 日期 / 时间
        for pattern in [
            #"\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?"#,
            #"\d{1,2}月\d{1,2}日"#,
            #"\d{1,2}:\d{2}(?::\d{2})?"#,
        ] {
            matches(of: pattern, in: nsText, range: fullRange).forEach { add(.date, $0) }
        }

        // 数字：排除已被电话/邮箱/链接/日期占用的区间、字母数字混合（WWDC26）、列表序号、行首单个数字
        var numberCount = 0
        for range in matches(of: #"(?<![A-Za-z0-9])\d+(?:[.,]\d+)?(?:\s?(?:%|亿|万|千|百|元|美元|分钟|小时|天|年|月|个|次|倍|km|kg|GB|MB))?"#, in: nsText, range: fullRange) {
            guard numberCount < numberLimit else { break }
            guard !claimed.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { continue }
            let value = nsText.substring(with: range)
            let digits = value.filter(\.isNumber)
            // 单个数字仅在带单位/百分号时保留（过滤列表序号与零散个位数）
            if digits.count < 2, value.count == digits.count { continue }
            // 列表序号：行首数字后紧跟 . 、 )
            if isListMarker(at: range, in: nsText) { continue }
            add(.number, range)
            numberCount += 1
        }

        let order: [TextEntity.Kind: Int] = [.phone: 0, .email: 1, .url: 2, .date: 3, .number: 4]
        return entities
            .sorted { lhs, rhs in
                let l = order[lhs.kind] ?? 9
                let r = order[rhs.kind] ?? 9
                return l != r ? l < r : lhs.id < rhs.id
            }
            .prefix(totalLimit)
            .map { $0 }
    }

    /// 实体在大爆炸词块中的对应 token 序列（用于高亮与「选中」回填）。
    static func matchingTokenIDs(for entity: TextEntity, in tokens: [TextToken]) -> [Int] {
        let target = entity.value.replacingOccurrences(of: " ", with: "")
        guard !target.isEmpty else { return [] }
        let candidates = tokens.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        for start in candidates.indices {
            var buffer = ""
            var ids: [Int] = []
            for index in start..<candidates.count {
                buffer += candidates[index].text.replacingOccurrences(of: " ", with: "")
                ids.append(candidates[index].id)
                if buffer == target { return ids }
                if buffer.count >= target.count || !target.hasPrefix(buffer) { break }
            }
        }
        return []
    }

    // MARK: - 工具

    private static func matches(of pattern: String, in text: NSString, range: NSRange) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text as String, range: range).map(\.range)
    }

    /// 判断数字是否为列表序号（行首 + 后跟 . 、 ) 或 "、"）。
    private static func isListMarker(at range: NSRange, in text: NSString) -> Bool {
        let lineStart: Bool
        if range.location == 0 {
            lineStart = true
        } else {
            let previous = text.substring(with: NSRange(location: range.location - 1, length: 1))
            lineStart = previous == "\n"
        }
        guard lineStart else { return false }
        let after = range.location + range.length
        guard after < text.length else { return false }
        let next = text.substring(with: NSRange(location: after, length: 1))
        return [".", "、", ")", "．"].contains(next)
    }
}
