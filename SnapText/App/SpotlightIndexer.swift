import CoreSpotlight
import SwiftData
import UniformTypeIdentifiers

/// Spotlight 索引：归档内容进入系统全局搜索，点击直达详情。
/// App 前台时增量补索引；删除归档时同步删除索引项。
@MainActor
enum SpotlightIndexer {
    private static let domain = "com.snaptext.archives"
    private static let indexedIDsKey = "spotlight.indexedIDs"
    private static let capacity = 500

    static func indexPendingEntries(context: ModelContext) {
        let descriptor = FetchDescriptor<ArchiveEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let entries = try? context.fetch(descriptor) else { return }
        let indexed = Set(UserDefaults.standard.stringArray(forKey: indexedIDsKey) ?? [])
        let pending = entries.filter { !indexed.contains($0.id.uuidString) }.prefix(50)
        guard !pending.isEmpty else { return }

        let items = pending.map { entry -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = entry.title
            attributes.contentDescription = entry.summary.isEmpty
                ? String(entry.recognizedText.prefix(120))
                : entry.summary
            attributes.keywords = entry.tags
            attributes.contentCreationDate = entry.createdAt
            return CSSearchableItem(
                uniqueIdentifier: entry.id.uuidString,
                domainIdentifier: domain,
                attributeSet: attributes
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in
            var ids = (UserDefaults.standard.stringArray(forKey: indexedIDsKey) ?? [])
            let newIDs = pending.map(\.id.uuidString)
            ids.append(contentsOf: newIDs)
            if ids.count > capacity {
                ids.removeFirst(ids.count - capacity)
            }
            UserDefaults.standard.set(ids, forKey: indexedIDsKey)
        }
    }

    static func deleteIndex(for entryID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [entryID.uuidString]) { _ in }
        var ids = UserDefaults.standard.stringArray(forKey: indexedIDsKey) ?? []
        ids.removeAll { $0 == entryID.uuidString }
        UserDefaults.standard.set(ids, forKey: indexedIDsKey)
    }
}
