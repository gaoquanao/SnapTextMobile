import Foundation

/// 已处理资产登记：断点续传，避免重复归档同一张图。
struct ProcessedAssetStore {
    private let defaults: UserDefaults
    private let idsKey = "watch.processedAssetIDs"
    private let lastDateKey = "watch.lastProcessedDate"
    private let baselineKey = "watch.baselineSet"
    private let capacity = 800

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 已处理 ID（FIFO 截断，防无限膨胀）

    var processedIDs: [String] {
        defaults.stringArray(forKey: idsKey) ?? []
    }

    func contains(_ id: String) -> Bool {
        processedIDs.contains(id)
    }

    func mark(_ id: String) {
        var ids = processedIDs
        guard !ids.contains(id) else { return }
        ids.append(id)
        if ids.count > capacity {
            ids.removeFirst(ids.count - capacity)
        }
        defaults.set(ids, forKey: idsKey)
    }

    // MARK: - 处理水位

    /// 上次处理到的资产创建时间；之后的增量才会被处理。
    var lastProcessedDate: Date {
        let interval = defaults.double(forKey: lastDateKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : .distantPast
    }

    func updateLastProcessedDate(_ date: Date) {
        let current = lastProcessedDate
        guard date > current else { return }
        defaults.set(date.timeIntervalSince1970, forKey: lastDateKey)
    }

    /// 首次启用基线：从「此刻」开始收集，不回溯历史。
    var baselineSet: Bool {
        defaults.bool(forKey: baselineKey)
    }

    func setBaselineNow() {
        defaults.set(Date().timeIntervalSince1970 - 60, forKey: lastDateKey)
        defaults.set(true, forKey: baselineKey)
    }

    /// 关闭监控时清空登记。
    func reset() {
        defaults.removeObject(forKey: idsKey)
        defaults.removeObject(forKey: lastDateKey)
        defaults.set(false, forKey: baselineKey)
    }
}
