import Foundation

/// 全库导出：把所有归档打包成单文件 Markdown 或 JSON（经系统分享面板发往任意去处）。
enum ExportAllBuilder {
    static func markdown(entries: [ArchiveEntry], date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append(String(localized: "# 拾文 · 全部归档"))
        lines.append("")
        lines.append("> " + String(localized: "导出时间：\(ExportPayload.dateFormatter.string(from: date)) · 共 \(entries.count) 条"))
        lines.append("")
        for entry in entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            lines.append("---")
            lines.append("")
            lines.append("## \(entry.title)")
            lines.append("")
            if !entry.summary.isEmpty {
                lines.append("> \(entry.summary)")
                lines.append("")
            }
            if !entry.tags.isEmpty {
                lines.append(entry.tags.map { "#\($0)" }.joined(separator: " "))
                lines.append("")
            }
            lines.append(entry.recognizedText)
            if !entry.category.isEmpty {
                lines.append("")
                lines.append(String(localized: "分类：\(entry.category)"))
            }
            lines.append("")
            lines.append("*\(entry.source.displayName) · \(formatter.string(from: entry.createdAt))*")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    struct JSONEntry: Codable {
        let title: String
        let text: String
        let summary: String
        let tags: [String]
        let category: String
        let source: String
        let createdAt: Date
    }

    static func jsonData(entries: [ArchiveEntry]) throws -> Data {
        let payload = entries.map { entry in
            JSONEntry(
                title: entry.title,
                text: entry.recognizedText,
                summary: entry.summary,
                tags: entry.tags,
                category: entry.category,
                source: entry.sourceRaw,
                createdAt: entry.createdAt
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    /// 写入临时文件供分享面板发送。
    static func tempFileURL(content: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try content.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
