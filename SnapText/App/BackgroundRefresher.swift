import BackgroundTasks
import Foundation

/// 后台相册补漏：App 退后台时提交请求，系统择机唤醒，复用 PhotoWatchService 增量处理。
/// 说明：iOS 26 才有随相册变化精确唤醒的 BGPhotoLibraryRefreshTask；iOS 18 用通用的
/// BGAppRefreshTask 周期性兜底，前台 observer 仍是实时主力。
enum BackgroundRefresher {
    static let taskIdentifier = "com.snaptext.photo-refresh"

    /// 必须在 App 启动完成前注册。
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task { @MainActor in
                await PhotoWatchService.shared.processPending()
                refreshTask.setTaskCompleted(success: true)
            }
            refreshTask.expirationHandler = {
                work.cancel()
                refreshTask.setTaskCompleted(success: false)
            }
        }
    }

    /// App 退到后台时提交请求。
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nil
        try? BGTaskScheduler.shared.submit(request)
    }
}
