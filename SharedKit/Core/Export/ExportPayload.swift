import Foundation

/// 导出载荷：统一整理成 Markdown。
struct ExportPayload {
    var title: String
    var text: String
    var tags: [String]
    var date: Date = Date()

    init(title: String, text: String, tags: [String] = [], date: Date = Date()) {
        self.title = title
        self.text = text
        self.tags = tags
        self.date = date
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    /// 供备忘录 / 系统分享使用的 Markdown 全文。
    var markdown: String {
        let defaultTitle = String(localized: "拾文速记")
        var lines: [String] = []
        lines.append("# \(title.isEmpty ? defaultTitle : title)")
        lines.append("")
        lines.append(text)
        if !tags.isEmpty {
            lines.append("")
            lines.append(tags.map { "#\($0)" }.joined(separator: " "))
        }
        lines.append("")
        lines.append("> " + String(localized: "摘自「拾文 SnapText」 · \(ExportPayload.dateFormatter.string(from: date))"))
        return lines.joined(separator: "\n")
    }

    /// 用作文件名/笔记名的安全标题。
    var safeTitle: String {
        let base = title.isEmpty ? String(localized: "拾文速记") : title
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = base.unicodeScalars.filter { !invalid.contains($0) }
        let name = String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "拾文速记") : String(name.prefix(40))
    }

    var tagsJoined: String {
        tags.joined(separator: ",")
    }

    var tagsWithHash: String {
        tags.map { "#\($0)" }.joined(separator: " ")
    }

    var dateString: String {
        ExportPayload.dateFormatter.string(from: date)
    }
}
