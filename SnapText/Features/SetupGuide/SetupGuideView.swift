import Photos
import SwiftData
import SwiftUI

/// 设置 + 快捷指令/操作按钮配置引导 + 相册监控 + 导出。
struct SetupGuideView: View {
    @AppStorage(SettingsKeys.obsidianVault) private var obsidianVault = ""
    @AppStorage(SettingsKeys.customTemplate) private var customTemplate = ""
    @AppStorage(SettingsKeys.customName) private var customName = ""
    @AppStorage(SettingsKeys.searchEngineBase) private var searchEngineBase = "https://www.bing.com/search?q="
    @AppStorage(SettingsKeys.recognitionLanguages) private var recognitionLanguages = RecognitionLanguageOption.zhEn.rawValue
    @AppStorage(SettingsKeys.watchEnabled) private var watchEnabled = false
    @AppStorage(SettingsKeys.watchMode) private var watchMode = PhotoWatchMode.screenshots.rawValue
    @AppStorage(SettingsKeys.watchAlbumID) private var watchAlbumID = ""
    @AppStorage(SettingsKeys.privacyLockEnabled) private var privacyLockEnabled = false
    @AppStorage(SettingsKeys.autoDeleteScreenshots) private var autoDeleteScreenshots = false

    @State private var albums: [(id: String, title: String)] = []
    @State private var watchSummary: String?
    @State private var exportShareItems: [Any]?
    @State private var showOnboarding = false
    @State private var exportTestMessage: String?
    @State private var recipeImportFailed = false

    /// 导出配置输入框焦点：支持键盘「完成」按钮与点击空白处收起。
    private enum Field: Hashable {
        case obsidianVault, customName, customTemplate, searchEngine
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                readySection
                aiSection
                recipeSection
                bindingSection
                watchSection
                cleanupSection
                exportSection
                privacySection
                aboutSection
            }
            .navigationTitle("设置")
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
        }
        .onAppear {
            loadAlbumsIfAuthorized()
            #if DEBUG
            runDemoRecipeImportIfNeeded()
            #endif
        }
        .onChange(of: watchEnabled) { _, enabled in
            // 开启监控时会请求相册权限；授权完成后延迟刷新相簿列表。
            guard enabled else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                loadAlbumsIfAuthorized()
            }
        }
        .sheet(isPresented: Binding(
            get: { exportShareItems != nil },
            set: { if !$0 { exportShareItems = nil } }
        )) {
            ActivityShareSheet(items: exportShareItems ?? [])
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { openSettings in
                showOnboarding = false
            }
        }
        .alert(
            "导出测试",
            isPresented: Binding(
                get: { exportTestMessage != nil },
                set: { if !$0 { exportTestMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(exportTestMessage ?? "")
        }
        .alert("未能打开配方文件", isPresented: $recipeImportFailed) {
            Button("好", role: .cancel) {}
        } message: {
            Text("安装包内未找到配方文件，请改用「手动搭建配方」按步骤创建。")
        }
    }

    #if DEBUG
    /// 验证用：-SnapTextDemoImportRecipe bang|archive 启动参数在设置页出现后自动触发导入。
    private func runDemoRecipeImportIfNeeded() {
        guard let id = DemoSupport.pendingRecipeImport,
              let recipe = ShortcutRecipeLibrary.all.first(where: { $0.id == id }) else { return }
        recipeImportLogger.info("demo: 1 秒后触发配方导入 \(id, privacy: .public)")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            addRecipe(recipe)
        }
    }
    #endif

    /// 仅在已授权时枚举相簿：避免用户尚未使用照片功能时触发系统授权弹窗。
    private func loadAlbumsIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        albums = PhotoLibraryHelper.userAlbums()
    }

    // MARK: - 端侧 AI

    private var aiSection: some View {
        Section {
            HStack {
                Label("端侧识别", systemImage: "waveform.text")
                Spacer()
                Text("Vision OCR · 始终开启")
                    .foregroundStyle(.secondary)
            }
            aiExtractRow
            Picker("识别语言", selection: $recognitionLanguages) {
                ForEach(RecognitionLanguageOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
        } header: {
            Text("端侧 AI")
        } footer: {
            Text("所有识别与提取均在设备本地完成，不上传任何数据。语言更多时识别略慢。")
        }
    }

    @ViewBuilder
    private var aiExtractRow: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if FoundationModelsExtractor.isAvailable {
                HStack {
                    Text("知识提取")
                    Spacer()
                    Text("端侧大模型已启用")
                        .foregroundStyle(.green)
                }
            } else {
                HStack {
                    Text("知识提取")
                    Spacer()
                    Text("规则模式（开启 Apple Intelligence 后升级）")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack {
                Text("知识提取")
                Spacer()
                Text("规则模式（iOS 26 自动升级大模型）")
                    .foregroundStyle(.secondary)
            }
        }
        #else
        HStack {
            Text("知识提取")
            Spacer()
            Text("规则模式（iOS 26 自动升级大模型）")
                .foregroundStyle(.secondary)
        }
        #endif
    }

    // MARK: - 开箱即用

    private var readySection: some View {
        Section {
            stepList(title: String(localized: "控制中心（免配置）"), steps: [
                String(localized: "长按控制中心进入编辑 → 添加控件"),
                String(localized: "找到「拾文」：添加「大爆炸识别」或「归档最近截图」"),
            ])
            stepList(title: String(localized: "操作按钮（iPhone 15 Pro 及以上，iOS 18）"), steps: [
                String(localized: "设置 → 操作按钮 → 左右滑动到「控制」"),
                String(localized: "选择「拾文·大爆炸识别」——无需快捷指令，即装即用"),
            ])
            stepList(title: String(localized: "分享面板"), steps: [
                String(localized: "截图后点缩略图 → 分享 → 拾文"),
                String(localized: "在扩展内直接完成识别、大爆炸选取与归档"),
            ])
        } header: {
            Text("第一步 · 开箱即用")
        } footer: {
            Text("以上方式都不需要在快捷指令里组装步骤，装上即可使用。首次使用会请求相册权限。")
        }
    }

    // MARK: - 快捷指令配方

    private var recipeSection: some View {
        Section {
            ForEach(ShortcutRecipeLibrary.all) { recipe in
                recipeRow(recipe)
            }
            stepList(title: String(localized: "配方 C · 截屏自动归档（系统自动化，需创建一次）"), steps: [
                String(localized: "快捷指令 App → 自动化 → 新建自动化"),
                String(localized: "选择「截屏时」（App 内截屏即触发）"),
                String(localized: "选择「立即运行」并关闭「运行前询问」"),
                String(localized: "动作选择拾文 App 的「静默归档截图」"),
            ])
            DisclosureGroup {
                stepList(title: String(localized: "配方 A · 大爆炸"), steps: ShortcutRecipeLibrary.bang.manualSteps)
                stepList(title: String(localized: "配方 B · 静默归档"), steps: ShortcutRecipeLibrary.archive.manualSteps)
            } label: {
                Text("手动搭建配方（可选）")
                    .font(.subheadline.weight(.semibold))
            }
        } header: {
            Text("第二步 · 快捷指令（可选进阶）")
        } footer: {
            Text("配方已内置在 App 中：点「一键添加」并在快捷指令 App 里确认即可，导入后可自由修改任意动作。配方 C 属于系统自动化，iOS 不允许导入，需按步骤创建一次。")
        }
    }

    /// 内置配方行：默认配方带标记，一键导入到快捷指令 App。
    private func recipeRow(_ recipe: ShortcutRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(recipe.resourceName)
                    .font(.subheadline.weight(.semibold))
                if recipe.isDefault {
                    Text("默认")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                addRecipe(recipe)
            } label: {
                Label("一键添加到快捷指令", systemImage: "plus.circle.fill")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    private func addRecipe(_ recipe: ShortcutRecipe) {
        guard let url = ShortcutRecipeImporter.exportFileURL(recipe) else {
            recipeImportLogger.error("配方导出失败：\(recipe.resourceName, privacy: .public)")
            recipeImportFailed = true
            return
        }
        // 系统菜单不可用（无处理该类型的 App）时退回分享面板，用户在面板里选「快捷指令」。
        if !RecipeDocumentPresenter.shared.presentOpenInMenu(for: url) {
            recipeImportLogger.info("退回分享面板")
            exportShareItems = [url]
        }
    }

    private var bindingSection: some View {
        Section {
            stepList(title: String(localized: "轻点背面（所有全面屏机型）"), steps: [
                String(localized: "设置 → 辅助功能 → 触控 → 轻点背面"),
                String(localized: "「轻点两下」选择配方 A 的快捷指令"),
            ])
        } header: {
            Text("第三步 · 轻点背面（需先导入快捷指令）")
        }
    }

    // MARK: - 相册监控

    private var watchSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { watchEnabled },
                set: { newValue in
                    watchEnabled = newValue
                    PhotoWatchService.shared.applyEnabled(newValue)
                }
            )) {
                Label("相册自动收集", systemImage: "photo.stack")
            }
            if watchEnabled {
                Picker("监控范围", selection: $watchMode) {
                    Text("系统全部截图").tag(PhotoWatchMode.screenshots.rawValue)
                    Text("指定相簿").tag(PhotoWatchMode.album.rawValue)
                }
                .onChange(of: watchMode) { _, _ in
                    ProcessedAssetStore().reset()
                }
                if watchMode == PhotoWatchMode.album.rawValue {
                    Picker("相簿", selection: $watchAlbumID) {
                        Text("请选择").tag("")
                        ForEach(albums, id: \.id) { album in
                            Text(album.title).tag(album.id)
                        }
                    }
                }
                if let watchSummary {
                    Label(watchSummary, systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("相册自动收集")
        } footer: {
            Text("开启后自动识别并归档新增图片：截图在前台实时处理；拍摄的照片由系统在后台择机处理（需保持后台 App 刷新开启）。从开启时刻开始收集，不回溯历史。")
                .onAppear {
                    watchSummary = PhotoWatchService.shared.lastRunSummary
                }
        }
    }

    // MARK: - 截图清理策略

    private var cleanupSection: some View {
        Section {
            Toggle(isOn: $autoDeleteScreenshots) {
                Label("归档后删除源截图", systemImage: "trash.slash")
            }
        } header: {
            Text("截图清理")
        } footer: {
            Text("开启后，静默归档（相册自动收集、控制中心控件）处理成功的截图会从相册移除，改由拾文保管。系统会弹窗确认；删除的图片进入「最近删除」保留 30 天。分享与手动导入的图片不受影响。")
        }
    }

    // MARK: - 导出设置

    private var exportSection: some View {
        Section {
            Button {
                exportAll(asMarkdown: true)
            } label: {
                Label("导出全部归档 · Markdown", systemImage: "doc.plaintext")
            }
            Button {
                exportAll(asMarkdown: false)
            } label: {
                Label("导出全部归档 · JSON（备份）", systemImage: "curlybraces.square")
            }

            LabeledContent("Obsidian Vault 名称") {
                TextField("例如 MyVault", text: $obsidianVault)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .obsidianVault)
            }
            Button {
                testObsidianExport()
            } label: {
                Label("发送测试笔记到 Obsidian", systemImage: "paperplane")
            }
            .disabled(obsidianVault.trimmingCharacters(in: .whitespaces).isEmpty)

            LabeledContent("自定义模板名称") {
                TextField("例如 flomo", text: $customName)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .customName)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("自定义导出 URL 模板")
                TextField("flomoapp://share?content={content} {tagsHash}", text: $customTemplate, axis: .vertical)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .customTemplate)
                Text("占位符：{title} {content} {markdown} {tags} {tagsHash} {date}。适配 flomo、Craft 等一切支持 URL Scheme 的应用。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button {
                testCustomExport()
            } label: {
                Label("发送测试笔记到自定义应用", systemImage: "paperplane")
            }
            .disabled(customTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            VStack(alignment: .leading, spacing: 6) {
                Text("搜索入口")
                TextField("https://www.bing.com/search?q=", text: $searchEngineBase)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .searchEngine)
            }
        } header: {
            Text("导出")
        } footer: {
            Text("Obsidian 的 Vault 名称必须与 App 内完全一致（可在 Obsidian 左下角切换库中查看）；模板里的 URL Scheme 需目标应用已安装。配置后用「发送测试笔记」验证。")
        }
    }

    /// 测试导出用的示例内容。
    private var testPayload: ExportPayload {
        ExportPayload(
            title: String(localized: "拾文导出测试"),
            text: String(localized: "这是一条来自拾文的测试笔记。能看到它，说明导出配置正确。"),
            tags: [String(localized: "测试")]
        )
    }

    private func testObsidianExport() {
        let payload = testPayload
        guard let url = ExportService.obsidianURL(payload: payload, vault: obsidianVault) else {
            exportTestMessage = String(localized: "配置不完整，请检查 Vault 名称")
            return
        }
        openForTest(url, appName: "Obsidian")
    }

    private func testCustomExport() {
        let payload = testPayload
        guard let url = ExportService.customURL(template: customTemplate, payload: payload) else {
            exportTestMessage = String(localized: "模板无法生成有效链接，请检查 URL 格式")
            return
        }
        let name = customName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "目标应用")
            : customName
        openForTest(url, appName: name)
    }

    private func openForTest(_ url: URL, appName: String) {
        if UIApplication.shared.openURL(url) {
            exportTestMessage = String(localized: "已发送到 \(appName)，请到对应 App 中确认是否创建成功")
        } else {
            exportTestMessage = String(localized: "未检测到 \(appName)，请确认已安装后重试")
        }
    }

    // MARK: - 隐私

    private var privacySection: some View {
        Section {
            Toggle(isOn: $privacyLockEnabled) {
                Label("FaceID 隐私锁", systemImage: "faceid")
            }
        } header: {
            Text("隐私")
        } footer: {
            Text("开启后 App 退到后台即上锁，回前台需 FaceID / 触控 ID / 密码验证。数据始终只存在本机。")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            Button {
                showOnboarding = true
            } label: {
                Label("查看使用引导", systemImage: "sparkles")
            }
            LabeledContent("版本") { Text("1.1") }
            LabeledContent("存储位置") { Text("本机 App Group 容器") }
        } header: {
            Text("关于拾文")
        } footer: {
            Text("拾文 SnapText · 截图即知识。识别、提取、归档全程离线。")
        }
    }

    // MARK: - 行为

    private func exportAll(asMarkdown: Bool) {
        let entries = (try? ArchiveStore.mainContext.fetch(FetchDescriptor<ArchiveEntry>())) ?? []
        guard !entries.isEmpty else { return }
        let suffix = ISO8601DateFormatter().string(from: Date()).prefix(10)
        if asMarkdown {
            let content = ExportAllBuilder.markdown(entries: entries)
            if let url = ExportAllBuilder.tempFileURL(content: content, name: "拾文归档-\(suffix).md") {
                exportShareItems = [url]
            }
        } else if let data = try? ExportAllBuilder.jsonData(entries: entries) {
            let url = FileManager.default.temporaryDirectory.appending(path: "拾文归档-\(suffix).json")
            try? data.write(to: url)
            exportShareItems = [url]
        }
    }

    // MARK: - 组件

    private func stepList(title: String, steps: [String]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .frame(width: 18, height: 18)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }
}
