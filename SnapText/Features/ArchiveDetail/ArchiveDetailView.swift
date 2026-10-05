import SwiftData
import SwiftUI

struct ArchiveDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let entry: ArchiveEntry

    @State private var title: String = ""
    @State private var text: String = ""
    @State private var newTag: String = ""
    @State private var showBigBang = false
    @State private var showShareSheet = false
    @State private var showImageViewer = false

    var body: some View {
        Form {
            if let data = entry.imageData, let image = UIImage(data: data) {
                Section("来源截图") {
                    Button {
                        showImageViewer = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.semibold))
                                    .padding(6)
                                    .background(.thinMaterial, in: Circle())
                                    .padding(8)
                            }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("查看原图"))
                    .contextMenu {
                        Button {
                            showBigBang = true
                        } label: {
                            Label("大爆炸文字提取", systemImage: "text.word.spacing")
                        }
                        Button {
                            showImageViewer = true
                        } label: {
                            Label("查看原图", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    }
                }
            }

            Section("标题") {
                TextField("标题", text: $title)
                    .onChange(of: title) { _, newValue in
                        entry.title = newValue
                    }
            }

            Section("标签") {
                tagChips
                HStack {
                    TextField("添加标签", text: $newTag)
                        .onSubmit(addTag)
                    Button("添加", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !entry.category.isEmpty {
                    Text("分类：\(entry.category)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("识别文本") {
                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .font(.body)
                    .onChange(of: text) { _, newValue in
                        entry.recognizedText = newValue
                    }
            }

            Section {
                Button {
                    showBigBang = true
                } label: {
                    Label("大爆炸选取", systemImage: "burst.fill")
                }
                Menu {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("存入备忘录（分享面板）", systemImage: "note.text")
                    }
                    Button {
                        export { ExportService.obsidianURL(payload: payload, vault: ExportConfig.current.obsidianVault) }
                    } label: {
                        Label("Obsidian", systemImage: "circle.grid.cross")
                    }
                    Button {
                        export { ExportService.bearURL(payload: payload) }
                    } label: {
                        Label("Bear", systemImage: "bear")
                    }
                    Button {
                        export { ExportService.customURL(template: ExportConfig.current.customTemplate, payload: payload) }
                    } label: {
                        Label("自定义模板", systemImage: "link")
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    SpotlightIndexer.deleteIndex(for: entry.id)
                    modelContext.delete(entry)
                    try? modelContext.save()
                } label: {
                    Label("删除该归档", systemImage: "trash")
                }
            } header: {
                Text("操作")
            } footer: {
                Text("\(entry.source.displayName) · \(ExportPayload.dateFormatter.string(from: entry.createdAt))")
            }
        }
        .navigationTitle("归档详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            title = entry.title
            text = entry.recognizedText
        }
        .fullScreenCover(isPresented: $showBigBang) {
            BigBangScreen(entry: entry)
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let data = entry.imageData, let image = UIImage(data: data) {
                ImageZoomViewer(image: image)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: [payload.markdown])
        }
    }

    private var payload: ExportPayload {
        ExportPayload(title: title, text: text, tags: entry.tags, date: entry.createdAt)
    }

    @ViewBuilder
    private var tagChips: some View {
        if !entry.tags.isEmpty {
            TokenFlowLayout {
                ForEach(entry.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .font(.caption)
                        Button {
                            entry.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        } else {
            Text("暂无标签，可手动添加或重新提取")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !entry.tags.contains(tag) else { return }
        entry.tags.append(tag)
        newTag = ""
        try? modelContext.save()
    }

    private func export(urlBuilder: () -> URL?) {
        guard let url = urlBuilder() else { return }
        if UIApplication.shared.openURL(url) { return }
        UIPasteboard.general.string = payload.markdown
    }

    private func save() {
        try? modelContext.save()
    }
}

/// 详情页的大爆炸全屏容器。
private struct BigBangScreen: View {
    let entry: ArchiveEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BigBangEntryScreen(entry: entry) {
            dismiss()
        }
    }
}
