import Foundation

/// 文本润色调度：OCR 原始文本 → 规则规整（全设备必做）→（支持时）端侧大模型润色。
enum TextPolishService {
    /// 返回整理后的 Markdown 文本。
    static func polish(_ raw: String) async -> String {
        let normalized = TextPolisher.normalize(raw)
        #if canImport(FoundationModels)
        if FoundationModelsExtractor.isAvailable,
           let polished = try? await FoundationModelsExtractor.polish(normalized),
           isFaithful(polished, comparedTo: normalized) {
            return polished
        }
        #endif
        return normalized
    }

    /// 长度守门：模型输出与规整文本长度接近才采用，防止过度改写或截断丢内容。
    static func isFaithful(_ output: String, comparedTo input: String) -> Bool {
        guard !input.isEmpty else { return false }
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        let ratio = Double(cleaned.count) / Double(input.count)
        return ratio >= 0.5 && ratio <= 1.6
    }
}
