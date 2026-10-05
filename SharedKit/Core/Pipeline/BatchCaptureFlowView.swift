import SwiftData
import SwiftUI

/// 批量捕获流程：多张图串行「查重 → OCR → 提取 → 归档」，逐行展示状态，
/// 行可点开大爆炸选取。
struct BatchCaptureFlowView: View {
    let images: [UIImage]
    var source: ArchiveSource = .importAction
    var onDone: () -> Void = {}

    private enum ItemStatus: Equatable {
        case pending
        case processing
        case archived
        case duplicate
        case failed(String)
    }

    private struct BatchItem: Identifiable {
        let id = UUID()
        let image: UIImage
        var status: ItemStatus = .pending
        var entry: ArchiveEntry?
    }

    @State private var items: [BatchItem] = []
    @State private var presentingEntry: EntrySheet?
    @State private var processed = 0

    var body: some View {
        VStack(spacing: 12) {
            header
            list
            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if items.isEmpty {
                items = images.map { BatchItem(image: $0) }
            }
        }
        .task { await runAll() }
        .fullScreenCover(item: $presentingEntry) { sheet in
            BigBangEntryScreen(entry: sheet.entry)
        }
    }

    private var doneCount: Int {
        items.filter { $0.status != .pending && $0.status != .processing }.count
    }

    private var header: some View {
        VStack(spacing: 6) {
            ProgressView(value: Double(doneCount), total: Double(max(items.count, 1)))
            Text("批量识别 \(doneCount)/\(items.count) · 全程端侧")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: BatchItem) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                switch item.status {
                case .pending:
                    Text("等待处理").font(.footnote).foregroundStyle(.secondary)
                case .processing:
                    Text("正在识别…").font(.footnote).foregroundStyle(.tint)
                case .archived, .duplicate:
                    Text(item.entry?.title ?? String(localized: "已归档"))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: item.status == .duplicate ? "doc.on.doc" : "checkmark.seal.fill")
                            .font(.caption2)
                        Text(item.status == .duplicate
                            ? LocalizedStringKey("重复 · 复用既有归档")
                            : LocalizedStringKey("已归档"))
                            .font(.caption2)
                    }
                    .foregroundStyle(item.status == .duplicate ? .orange : .green)
                case .failed(let message):
                    Text("失败：\(message)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let entry = item.entry {
                Image(systemName: "text.word.spacing")
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            if let entry = item.entry {
                presentingEntry = EntrySheet(entry: entry)
            }
        }
        .contextMenu {
            if let entry = item.entry {
                Button(role: .destructive) {
                    removeEntry(entry, itemID: item.id)
                } label: {
                    Label("移除该归档", systemImage: "trash")
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                onDone()
            } label: {
                Text("完成")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - 处理

    private func runAll() async {
        for index in items.indices {
            items[index].status = .processing
            do {
                let outcome = try await CapturePipeline.capture(image: items[index].image, source: source)
                items[index].entry = outcome.entry
                items[index].status = outcome.isDuplicate ? .duplicate : .archived
            } catch {
                items[index].status = .failed(error.localizedDescription)
            }
            processed += 1
        }
    }

    private func removeEntry(_ entry: ArchiveEntry, itemID: UUID) {
        ArchiveStore.mainContext.delete(entry)
        try? ArchiveStore.mainContext.save()
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].entry = nil
            items[index].status = .failed(String(localized: "已移除"))
        }
    }
}
