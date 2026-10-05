import Foundation
import SwiftData

/// SwiftData 容器：App Group 目录，三个进程（主 App / 分享扩展 / 控件扩展）读写同一份。
enum ArchiveStore {
    static let schema = Schema([ArchiveEntry.self])

    static let defaultContainer: ModelContainer = {
        let config = ModelConfiguration(schema: schema, url: AppGroup.storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // App Group 目录不可写等极端情况：退回内存库，保证 App 不崩溃。
            return try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }
    }()

    @MainActor
    static var mainContext: ModelContext {
        defaultContainer.mainContext
    }

    @MainActor
    static func newContext() -> ModelContext {
        ModelContext(defaultContainer)
    }
}
