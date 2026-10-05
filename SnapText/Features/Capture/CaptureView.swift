import PhotosUI
import SwiftUI
import VisionKit
import UIKit

/// App 内导入：相册多选 / 拍照 / 文档扫描 / 剪贴板 / 拖拽，处理后进批量或单张流程。
struct CaptureView: View {
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showScanner = false
    @State private var batchSession: BatchSession?
    @State private var singleSession: CaptureSession?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    dropZone
                    importButtons
                    if let message {
                        Label(message, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    tips
                }
                .padding(20)
            }
            .navigationTitle("捕获")
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task { await loadPickerItems(items) }
        }
        .fullScreenCover(item: $batchSession) { session in
            BatchCaptureFlowView(images: session.images, source: session.source) {
                batchSession = nil
            }
        }
        .fullScreenCover(item: $singleSession) { session in
            CaptureFlowView(image: session.image, source: session.source) {
                singleSession = nil
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.secondary.opacity(0.08))
            .frame(height: 140)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 30))
                        .foregroundStyle(.tint)
                    Text("把截图拖到这里")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.image], isTargeted: nil) { providers in
                let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
                guard !imageProviders.isEmpty else { return false }
                Task { await loadDropped(imageProviders) }
                return true
            }
    }

    private var importButtons: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                Label("从相册选择（可多选）", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            #if !targetEnvironment(simulator)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照识别", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showScanner = true
                } label: {
                    Label("扫描文档（自动纠偏增强）", systemImage: "doc.text.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            #endif

            Button {
                importFromPasteboard()
            } label: {
                Label("读取剪贴板中的图片", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                singleSession = CaptureSession(image: image, source: .camera)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                guard !images.isEmpty else { return }
                if images.count == 1 {
                    singleSession = CaptureSession(image: images[0], source: .camera)
                } else {
                    batchSession = BatchSession(images: images, source: .camera)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("更快的方式", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
            Text("在「设置」页按引导把快捷指令绑定到操作按钮，或开启「截屏时」自动化——截图后无需任何操作，自动识别归档。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 加载

    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        present(images: images, source: .importAction)
    }

    private func loadDropped(_ providers: [NSItemProvider]) async {
        var images: [UIImage] = []
        for provider in providers {
            if let data: Data = try? await withCheckedThrowingContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }, let image = UIImage(data: data) {
                images.append(image)
            }
        }
        present(images: images, source: .importAction)
    }

    private func importFromPasteboard() {
        guard UIPasteboard.general.hasImages, let image = UIPasteboard.general.image else {
            message = "剪贴板中没有图片，请先复制或截屏一张图"
            return
        }
        singleSession = CaptureSession(image: image, source: .importAction)
    }

    private func present(images: [UIImage], source: ArchiveSource) {
        guard !images.isEmpty else {
            message = "无法读取所选图片"
            return
        }
        if images.count == 1 {
            singleSession = CaptureSession(image: images[0], source: source)
        } else {
            batchSession = BatchSession(images: images, source: source)
        }
    }
}

/// 批量处理会话（fullScreenCover(item:) 包装）。
struct BatchSession: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let source: ArchiveSource

    init(images: [UIImage], source: ArchiveSource = .importAction) {
        self.images = images
        self.source = source
    }
}
