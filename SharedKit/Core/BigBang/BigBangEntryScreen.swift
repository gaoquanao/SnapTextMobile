import SwiftUI

/// 全屏大爆炸容器：给定一条归档，展示标题 + 词块选取。
/// 详情页、批量导入行、单张捕获流程共用。
struct BigBangEntryScreen: View {
    let entry: ArchiveEntry
    /// 演示用：进入时自动选中前 N 个词块。
    var preselectCount: Int = 0
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    dismiss()
                    onDone()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            BigBangView(
                text: entry.recognizedText,
                highlightKeywords: entry.tags,
                preselectCount: preselectCount
            ) {
                dismiss()
                onDone()
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }
}

/// fullScreenCover(item:) 包装。
struct EntrySheet: Identifiable {
    let id = UUID()
    let entry: ArchiveEntry
}
