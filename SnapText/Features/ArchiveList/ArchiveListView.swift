import CoreSpotlight
import SwiftData
import SwiftUI

struct ArchiveListView: View {
    /// 跨进程（分享扩展/快捷指令）新增数据后，由根视图递增此值强制重建 @Query 快照。
    var reloadToken: Int = 0

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArchiveEntry.createdAt, order: .reverse) private var entries: [ArchiveEntry]
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private var filtered: [ArchiveEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText)
                || entry.recognizedText.localizedCaseInsensitiveContains(searchText)
                || entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if filtered.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("拾文")
            .searchable(text: $searchText, prompt: "搜索标题、正文、标签")
            .navigationDestination(for: UUID.self) { entryID in
                if let entry = entries.first(where: { $0.id == entryID }) {
                    ArchiveDetailView(entry: entry)
                } else {
                    Text("该归档已删除")
                        .foregroundStyle(.secondary)
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let idString = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                   let entryID = UUID(uuidString: idString) {
                    path.append(entryID)
                }
            }
            // 只重建列表内容刷新 @Query 快照；不能重建整个 NavigationStack，
            // 否则回前台时会出现双导航栏布局竞态导致崩溃。
            .id(reloadToken)
        }
    }

    private var list: some View {
        List {
            ForEach(filtered) { entry in
                NavigationLink(value: entry.id) {
                    EntryRowView(entry: entry)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有归档", systemImage: "text.viewfinder")
        } description: {
            Text("截图后分享到拾文、绑定操作按钮一键捕获，\n或在设置里开启相册自动收集。\n识别、提取、归档全部在设备本地完成。")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            SpotlightIndexer.deleteIndex(for: filtered[index].id)
            modelContext.delete(filtered[index])
        }
        try? modelContext.save()
    }
}

struct EntryRowView: View {
    let entry: ArchiveEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(entry.summary.isEmpty ? entry.recognizedText : entry.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                    Text("\(entry.source.displayName) · \(ArchiveEntry.dateFormatter.string(from: entry.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = entry.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "text.viewfinder")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

extension ArchiveEntry {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}
