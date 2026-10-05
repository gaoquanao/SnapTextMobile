import Foundation
import SwiftData

/// 截图来源。
enum ArchiveSource: String, Codable {
    case share          // 分享扩展
    case quickButton    // 快捷指令（操作按钮/轻点背面/控制中心）
    case importAction   // App 内导入
    case control        // 控制中心控件
    case autoWatch      // 相册自动收集
    case camera         // 相机拍摄 / 文档扫描

    var displayName: String {
        switch self {
        case .share: String(localized: "分享")
        case .quickButton: String(localized: "快捷指令")
        case .importAction: String(localized: "导入")
        case .control: String(localized: "控制中心")
        case .autoWatch: String(localized: "自动收集")
        case .camera: String(localized: "拍摄")
        }
    }
}

/// 一条截图归档记录：原图缩略 + OCR 文本 + 自动提取的知识元数据。
@Model
final class ArchiveEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceRaw: String
    var imageData: Data?
    var recognizedText: String
    var title: String
    var summary: String
    var tags: [String]
    var category: String
    /// 感知哈希（aHash），用于重复截图检测。
    var imageHash: Int64

    var source: ArchiveSource {
        get { ArchiveSource(rawValue: sourceRaw) ?? .importAction }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: ArchiveSource,
        imageData: Data?,
        recognizedText: String,
        title: String,
        summary: String,
        tags: [String],
        category: String = "",
        imageHash: Int64 = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceRaw = source.rawValue
        self.imageData = imageData
        self.recognizedText = recognizedText
        self.title = title
        self.summary = summary
        self.tags = tags
        self.category = category
        self.imageHash = imageHash
    }
}
