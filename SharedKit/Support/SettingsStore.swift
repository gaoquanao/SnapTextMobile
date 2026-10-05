import Foundation

/// 用户可配置项（导出目标、搜索入口、相册监控、识别语言、隐私锁），存 UserDefaults。
enum SettingsKeys {
    static let obsidianVault = "settings.obsidianVault"
    static let customTemplate = "settings.customTemplate"
    static let customName = "settings.customName"
    static let searchEngineBase = "settings.searchEngineBase"
    static let recognitionLanguages = "settings.recognitionLanguages"
    static let watchEnabled = "settings.watchEnabled"
    static let watchMode = "settings.watchMode"          // "screenshots" | "album"
    static let watchAlbumID = "settings.watchAlbumID"
    static let privacyLockEnabled = "settings.privacyLockEnabled"
    static let onboardingSeen = "settings.onboardingSeen"
    /// 截图清理策略：静默归档成功后是否删除相册中的源截图（默认关闭）。
    static let autoDeleteScreenshots = "settings.autoDeleteScreenshots"
}

struct ExportConfig {
    var obsidianVault: String
    var customTemplate: String
    var customName: String
    var searchEngineBase: String

    static var `default`: ExportConfig {
        ExportConfig(obsidianVault: "", customTemplate: "", customName: "", searchEngineBase: "https://www.bing.com/search?q=")
    }

    /// 每次导出实时读取，保证设置页修改立即生效。
    static var current: ExportConfig {
        let defaults = UserDefaults.standard
        return ExportConfig(
            obsidianVault: defaults.string(forKey: SettingsKeys.obsidianVault) ?? "",
            customTemplate: defaults.string(forKey: SettingsKeys.customTemplate) ?? "",
            customName: defaults.string(forKey: SettingsKeys.customName) ?? "",
            searchEngineBase: {
                let base = defaults.string(forKey: SettingsKeys.searchEngineBase) ?? ""
                return base.isEmpty ? "https://www.bing.com/search?q=" : base
            }()
        )
    }
}

/// OCR 识别语言组合（Vision 原生支持）。
enum RecognitionLanguageOption: String, CaseIterable, Identifiable {
    case zhEn
    case zhEnJa
    case zhEnJaKo
    case zhEnEs
    case all

    var id: String { rawValue }

    var languages: [String] {
        switch self {
        case .zhEn: ["zh-Hans", "en-US"]
        case .zhEnJa: ["zh-Hans", "en-US", "ja-JP"]
        case .zhEnJaKo: ["zh-Hans", "en-US", "ja-JP", "ko-KR"]
        case .zhEnEs: ["zh-Hans", "en-US", "es-ES"]
        case .all: ["zh-Hans", "en-US", "ja-JP", "ko-KR", "es-ES"]
        }
    }

    var displayName: String {
        switch self {
        case .zhEn: String(localized: "中文 + 英文")
        case .zhEnJa: String(localized: "中文 + 英文 + 日文")
        case .zhEnJaKo: String(localized: "中文 + 英文 + 日文 + 韩文")
        case .zhEnEs: String(localized: "中文 + 英文 + 西班牙语")
        case .all: String(localized: "全部语言")
        }
    }

    static var current: RecognitionLanguageOption {
        RecognitionLanguageOption(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.recognitionLanguages) ?? "") ?? .zhEn
    }
}

/// 相册监控配置。
enum PhotoWatchMode: String {
    case screenshots   // 系统全部截图
    case album         // 指定相簿
}

struct PhotoWatchConfig {
    var enabled: Bool
    var mode: PhotoWatchMode
    var albumID: String

    static var current: PhotoWatchConfig {
        let defaults = UserDefaults.standard
        let mode = PhotoWatchMode(rawValue: defaults.string(forKey: SettingsKeys.watchMode) ?? "") ?? .screenshots
        return PhotoWatchConfig(
            enabled: defaults.bool(forKey: SettingsKeys.watchEnabled),
            mode: mode,
            albumID: defaults.string(forKey: SettingsKeys.watchAlbumID) ?? ""
        )
    }
}
