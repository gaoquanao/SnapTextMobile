import Foundation
import Photos
import UIKit

/// 意图错误定义（多个 target 共用）。
enum SnapIntentError: LocalizedError {
    case noScreenshot
    case photoPermissionDenied

    var errorDescription: String? {
        switch self {
        case .noScreenshot: String(localized: "没有找到可处理的截图")
        case .photoPermissionDenied: String(localized: "需要相册权限，请先打开拾文 App 完成授权")
        }
    }
}

/// 读取相册截图的工具集。
enum PhotoLibraryHelper {
    /// 请求相册授权（未决时才请求）。
    static func ensureAuthorized() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        var current = status
        if current == .notDetermined {
            current = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current == .authorized || current == .limited
    }

    /// 读取相册中最新的一张资产；predicate 为 nil 时取任意类型的最新图片。
    static func latestAsset(matching predicate: NSPredicate?) async throws -> PHAsset? {
        guard await ensureAuthorized() else { throw SnapIntentError.photoPermissionDenied }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 10
        options.predicate = predicate
        return PHAsset.fetchAssets(with: options).firstObject
    }

    /// 最新一张系统截图资产（保留资产引用以支持清理策略）。
    static func latestScreenshotAsset() async throws -> PHAsset? {
        try await latestAsset(matching: screenshotPredicate)
    }

    /// 读取相册最新一张截图（PHAssetMediaSubtype.photoScreenshot）。
    static func latestScreenshot() async throws -> UIImage? {
        guard let asset = try await latestScreenshotAsset() else { return nil }
        return try await image(for: asset)
    }

    /// 按资产读取高清原图（相册监控用）。
    static func image(for asset: PHAsset) async throws -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !degraded, !finished else { return }
                finished = true
                continuation.resume(returning: image)
            }
        }
    }

    /// 系统截图类型资产的查询谓词。
    static var screenshotPredicate: NSPredicate {
        NSPredicate(
            format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
    }

    /// 用户自建相簿列表（设置页选择监控范围用）。
    static func userAlbums() -> [(id: String, title: String)] {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var albums: [(String, String)] = []
        fetch.enumerateObjects { collection, _, _ in
            let title = collection.localizedTitle ?? "未命名相簿"
            albums.append((collection.localIdentifier, title))
        }
        return albums
    }

    /// 删除相册中的指定资产。
    /// iOS 规定：App 删除照片必须经系统确认弹窗；删掉的图片进入「最近删除」保留 30 天。
    /// 用户取消（success=false）或权限不足时返回 false，调用方静默处理即可。
    static func deleteAssets(withLocalIdentifiers ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return false }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard fetch.count > 0 else { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
