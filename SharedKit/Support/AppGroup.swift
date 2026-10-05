import Foundation

/// App Group 容器：主 App、分享扩展、控件扩展共用同一份数据。
enum AppGroup {
    static let identifier = "group.com.snaptext.app"

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // 无 App Group 权限（例如模拟器未签名）时退回沙盒文档目录，保证开发期可用。
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// SwiftData 存储文件。
    static var storeURL: URL {
        containerURL.appending(path: "SnapText.store")
    }
}
