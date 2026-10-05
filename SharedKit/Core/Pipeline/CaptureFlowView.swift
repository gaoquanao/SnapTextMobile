import SwiftData
import SwiftUI

/// 捕获流程页：展示识别进度 → 完成「OCR + 知识提取 + 自动归档」 → 内嵌大爆炸选取。
/// 主 App（导入 / 快捷指令拉起）与分享扩展共用。
struct CaptureFlowView: View {
    let image: UIImage
    var source: ArchiveSource = .importAction
    var onDone: () -> Void = {}

    private enum Phase: Equatable {
        case processing
        case ready
        case failed(String)
    }

    @State private var phase: Phase = .processing
    @State private var entry: ArchiveEntry?
    @State private var isDuplicate = false

    var body: some View {
        VStack(spacing: 16) {
            switch phase {
            case .processing:
                processingView
            case .ready:
                readyView
            case .failed(let message):
                failedView(message)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .task { await run() }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4, y: 2)
            ProgressView("正在端侧识别文字…")
                .font(.headline)
            Text("识别在设备本地完成，不会上传")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var readyView: some View {
        if let entry {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            ForEach(entry.tags.prefix(4), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                            Label(isDuplicate
                                ? LocalizedStringKey("重复 · 复用既有归档")
                                : LocalizedStringKey("已归档"),
                                  systemImage: isDuplicate ? "doc.on.doc" : "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(isDuplicate ? .orange : .green)
                        }
                    }
                    Spacer()
                    Button {
                        removeEntry(entry)
                    } label: {
                        Label("移除", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                if !entry.category.isEmpty {
                    Text("分类：\(entry.category)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BigBangView(text: entry.recognizedText, highlightKeywords: entry.tags, onDone: onDone)
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("识别失败")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("重试") { Task { await run() } }
                    .buttonStyle(.borderedProminent)
                Button("关闭") { onDone() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func run() async {
        phase = .processing
        do {
            let outcome = try await CapturePipeline.capture(image: image, source: source)
            entry = outcome.entry
            isDuplicate = outcome.isDuplicate
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// 撤销归档：删除该条记录并关闭。
    private func removeEntry(_ target: ArchiveEntry) {
        ArchiveStore.mainContext.delete(target)
        try? ArchiveStore.mainContext.save()
        onDone()
    }
}
