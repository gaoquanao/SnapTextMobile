import SwiftData
import SwiftUI

@main
struct SnapTextApp: App {
    init() {
        // BGTask 必须在启动完成前注册；标识符需与 Info.plist 的
        // BGTaskSchedulerPermittedIdentifiers 一致。
        BackgroundRefresher.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(ArchiveStore.defaultContainer)
    }
}
