import Foundation

/// 各知识库直达 URL 构建。
enum ExportService {
    // MARK: - Obsidian

    /// obsidian://new?vault={vault}&name={title}&content={content}
    static func obsidianURL(payload: ExportPayload, vault: String) -> URL? {
        let vaultName = vault.isEmpty ? "Obsidian" : vault
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "name", value: payload.safeTitle),
            URLQueryItem(name: "content", value: payload.markdown),
        ]
        return components.url
    }

    // MARK: - Bear

    /// bear://x-callback-url/create?title={title}&text={text}&truncated=no
    static func bearURL(payload: ExportPayload) -> URL? {
        var components = URLComponents()
        components.scheme = "bear"
        components.host = "x-callback-url"
        components.path = "/create"
        components.queryItems = [
            URLQueryItem(name: "title", value: payload.safeTitle),
            URLQueryItem(name: "text", value: payload.markdown),
            URLQueryItem(name: "truncated", value: "no"),
        ]
        return components.url
    }

    // MARK: - 自定义 URL 模板

    /// 模板占位符：{title} {content} {markdown} {tags} {tagsHash} {date}
    /// 例：flomoapp://share?content={content}%20{tagsHash}
    /// 模板中的结构字符（scheme、host、&、?）原样保留，仅对占位符替换出的值做查询转义。
    static func customURL(template: String, payload: ExportPayload) -> URL? {
        guard !template.isEmpty else { return nil }
        let pairs: [(String, String)] = [
            ("{markdown}", payload.markdown),
            ("{content}", payload.text),
            ("{title}", payload.safeTitle),
            ("{tagsHash}", payload.tagsWithHash),
            ("{tags}", payload.tagsJoined),
            ("{date}", payload.dateString),
        ]
        var replaced = template
        for (placeholder, value) in pairs {
            replaced = replaced.replacingOccurrences(of: placeholder, with: encoded(value))
        }
        return URL(string: replaced)
    }

    /// URL 查询值转义：保留常见 scheme 结构字符。
    static func encoded(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
