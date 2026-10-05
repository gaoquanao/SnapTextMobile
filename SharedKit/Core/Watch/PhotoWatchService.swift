import Foundation
import Photos
import SwiftData
import UIKit

/// 相册监控：前台 PHPhotoLibraryChangeObserver 实时处理 + 后台 BGTask 复用同一套增量逻辑。
/// 监控范围二选一：系统全部截图 / 指定相簿。
@MainActor
final class PhotoWatchService: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoWatchService()

    @Published private(set) var lastRunSummary: String?

    private var registered = false
    private var debounceTask: Task<Void, Never>?
    private var running = false

    private override init() {
        super.init()
    }

    // MARK: - 开关

    func applyEnabled(_ enabled: Bool) {
        if enabled {
            ensureAuthorized()
            registerObserver()
        } else {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
            registered = false
            ProcessedAssetStore().reset()
        }
    }

    func startIfEnabled() {
        guard PhotoWatchConfig.current.enabled else { return }
        ensureAuthorized()
        registerObserver()
    }

    private func ensureAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
        }
    }

    private func registerObserver() {
        guard !registered else { return }
        PHPhotoLibrary.shared().register(self)
        registered = true
    }

    // MARK: - PHPhotoLibraryChangeObserver

    @objc nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard PhotoWatchConfig.current.enabled else { return }
            // 防抖：连续存图只触发一次处理。
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await processPending()
            }
        }
    }

    // MARK: - 增量处理（前台 observer 与后台 BGTask 共用）

    func processPending() async {
        let config = PhotoWatchConfig.current
        guard config.enabled, !running else { return }
        running = true
        defer { running = false }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        let store = ProcessedAssetStore()
        if !store.baselineSet {
            store.setBaselineNow()
            return
        }

        let cutoff = store.lastProcessedDate
        let newAssets = fetchNewAssets(config: config, after: cutoff)
        guard !newAssets.isEmpty else { return }

        var archived = 0
        var skipped = 0
        var latestDate = cutoff
        var archivedAssetIDs: [String] = []

        for asset in newAssets {
            store.mark(asset.localIdentifier)
            if let date = asset.creationDate {
                latestDate = max(latestDate, date)
            }
            do {
                guard let image = try await PhotoLibraryHelper.image(for: asset) else {
                    skipped += 1
                    continue
                }
                let outcome = try await CapturePipeline.capture(image: image, source: .autoWatch)
                if outcome.isDuplicate {
                    skipped += 1
                } else {
                    archived += 1
                }
                // 内容已入库（含重复命中）才纳入清理；失败的不动。
                archivedAssetIDs.append(asset.localIdentifier)
            } catch {
                // 单张失败不阻断批次，登记为已处理避免死循环。
                skipped += 1
            }
        }
        store.updateLastProcessedDate(latestDate)
        let cleaned = await ScreenshotCleanupPolicy.run(assetIDs: archivedAssetIDs)
        lastRunSummary = ScreenshotCleanupPolicy.summary(archived: archived, skipped: skipped, cleaned: cleaned)
    }

    private func fetchNewAssets(config: PhotoWatchConfig, after cutoff: Date) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var assets: [PHAsset] = []
        switch config.mode {
        case .screenshots:
            options.predicate = PhotoLibraryHelper.screenshotPredicate
            PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
                if let date = asset.creationDate, date > cutoff {
                    assets.append(asset)
                }
            }
        case .album:
            let identifier = config.albumID
            guard !identifier.isEmpty else { return [] }
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil)
            guard let album = collections.firstObject else { return [] }
            PHAsset.fetchAssets(in: album, options: options).enumerateObjects { asset, _, _ in
                if let date = asset.creationDate, date > cutoff {
                    assets.append(asset)
                }
            }
        }
        return assets.filter { !ProcessedAssetStore().contains($0.localIdentifier) }
    }
}
