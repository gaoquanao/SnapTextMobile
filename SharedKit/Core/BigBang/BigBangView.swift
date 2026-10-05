import SwiftUI
import UIKit

/// 大爆炸文本快速选取视图：文字炸成词块墙，轻点选取，自动按中英文规则拼合。
struct BigBangView: View {
    let text: String
    var highlightKeywords: [String] = []
    var bridge: ExportBridge = .default
    /// 演示用：进入时自动选中前 N 个词块（0 表示不预选）。
    var preselectCount: Int = 0
    var onDone: () -> Void = {}

    @State private var tokens: [TextToken] = []
    @State private var selected: Set<Int> = []
    @State private var lastTapped: Int?
    @State private var toast: String?
    // 结构化信息提取（电话/邮箱/链接/日期/数字）
    @State private var entities: [TextEntity] = []
    @State private var entityTokenMap: [Int: [Int]] = [:]
    // 滑动连选
    @State private var tokenFrames: [Int: CGRect] = [:]
    @State private var dragAnchor: Int?
    @State private var dragRemoving = false
    /// 长按已进入选取模式（此时禁用滚动，避免与连选打架）。
    @State private var selecting = false
    @State private var lastDragLocation: CGPoint?
    @State private var lastHit: Int?
    @State private var autoScrollTask: Task<Void, Never>?
    @State private var wallHeight: CGFloat = 0
    // 词墙分组：段落 → 行 → 词块（用于分段渲染与自动滚动定位）
    @State private var paragraphGroups: [[[TextToken]]] = []
    @State private var lineGroups: [[TextToken]] = []

    private var selectedText: String {
        let byID = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0) })
        return TokenJoiner.join(selected.sorted().compactMap { byID[$0] })
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            if !entities.isEmpty {
                entitySection
            }
            tokenWall
            selectionTools
            actionBar
            privacyHint
        }
        .onAppear {
            tokens = TextTokenizer.tokenize(text)
            rebuildGroups()
            entities = EntityExtractor.extract(from: text)
            var map: [Int: [Int]] = [:]
            for entity in entities {
                let ids = EntityExtractor.matchingTokenIDs(for: entity, in: tokens)
                if !ids.isEmpty {
                    map[entity.id] = ids
                }
            }
            entityTokenMap = map
            if preselectCount > 0 {
                selected = Set(tokens.prefix(preselectCount).map(\.id))
            }
            BangHaptics.prepare()
        }
        .overlay(alignment: .bottom) { toastView }
        .sheet(isPresented: shareSheetBinding) { shareSheet }
    }

    private var shareSheetBinding: Binding<Bool> {
        Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })
    }

    @State private var shareItems: [Any]? = nil

    private var shareSheet: some View {
        #if APP_EXTENSION
        // 扩展进程不走 SwiftUI 分享面板，导出由 ExportBridge 直接桥接宿主。
        Color.clear
        #else
        ActivityShareSheet(items: shareItems ?? [])
        #endif
    }

    // MARK: - 子视图

    private var header: some View {
        Text("轻点选取 · 长按拖动连选 · 自动分段拼合")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 底部隐私提示：本 App 完全本地运行，不采集任何数据。
    private var privacyHint: some View {
        Label(String(localized: "完全本地运行 · 不采集隐私"), systemImage: "lock.shield")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    // MARK: - 信息提取分组

    /// 电话 / 邮箱 / 链接 / 日期 / 数字 单独成组：轻点复制，长按更多操作，可选中回填词块。
    private var entitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(String(localized: "信息提取"), systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("轻点复制 · 长按更多")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entities) { entity in
                        Menu {
                            Button {
                                copyEntity(entity)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            Button {
                                performSearch(entity.value)
                            } label: {
                                Label("搜索", systemImage: "magnifyingglass")
                            }
                            if entityTokenMap[entity.id] != nil {
                                Button {
                                    selectEntityTokens(entity)
                                } label: {
                                    Label("选中词块", systemImage: "hand.tap")
                                }
                            }
                        } label: {
                            entityChip(entity)
                        } primaryAction: {
                            copyEntity(entity)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()
        }
    }

    private func entityChip(_ entity: TextEntity) -> some View {
        HStack(spacing: 5) {
            Image(systemName: entity.kind.symbolName)
                .font(.caption2.weight(.semibold))
            Text(entity.value)
                .font(.caption.monospaced())
                .lineLimit(1)
        }
        .foregroundStyle(entityColor(entity.kind))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(entityColor(entity.kind).opacity(0.13), in: Capsule())
    }

    private func entityColor(_ kind: TextEntity.Kind) -> Color {
        switch kind {
        case .phone: .green
        case .email: .blue
        case .url: .indigo
        case .date: .orange
        case .number: .teal
        }
    }

    private func copyEntity(_ entity: TextEntity) {
        UIPasteboard.general.string = entity.value
        showToast(String(localized: "已复制 \(entity.value)"))
    }

    private func selectEntityTokens(_ entity: TextEntity) {
        guard let ids = entityTokenMap[entity.id] else { return }
        selected.formUnion(ids)
        lastTapped = ids.first
        showToast(String(localized: "已选中 \(entity.value)"))
    }

    private var tokenWall: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(paragraphGroups.enumerated()), id: \.offset) { _, lines in
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, lineTokens in
                                TokenFlowLayout {
                                    ForEach(lineTokens) { token in
                                        tokenView(token)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .coordinateSpace(name: "bangWall")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { wallHeight = geo.size.height }
                        .onChange(of: geo.size.height) { _, height in wallHeight = height }
                }
            )
            .simultaneousGesture(selectionGesture(proxy: proxy))
            .scrollDisabled(selecting)
        }
    }

    /// 长按（0.28s）进入选取模式，随后拖动连选；未长按的拖动照常滚动。
    private func selectionGesture(proxy: ScrollViewProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28, maximumDistance: 14)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("bangWall")))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if !selecting {
                    // 长按落在词块上才进入选取；落在空白则交还给滚动。
                    guard let anchor = tokenID(at: drag.startLocation) else { return }
                    dragAnchor = anchor
                    dragRemoving = selected.contains(anchor)
                    selecting = true
                    BangHaptics.activate()
                    startAutoScroll(proxy: proxy)
                }
                extendSelection(at: drag.location)
            }
            .onEnded { _ in
                endSelection()
            }
    }

    /// 按当前手指位置命中词块，并把锚点到命中的整段范围按起手状态加选/减选。
    private func extendSelection(at location: CGPoint) {
        lastDragLocation = location
        guard let hit = tokenID(at: location) else { return }
        if hit != lastHit {
            lastHit = hit
            BangHaptics.tick()
        }
        guard let anchor = dragAnchor,
              let startIndex = tokens.firstIndex(where: { $0.id == anchor }),
              let hitIndex = tokens.firstIndex(where: { $0.id == hit })
        else { return }
        for index in min(startIndex, hitIndex)...max(startIndex, hitIndex) {
            let id = tokens[index].id
            if dragRemoving {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        }
        lastTapped = hit
    }

    private func endSelection() {
        selecting = false
        dragAnchor = nil
        lastHit = nil
        lastDragLocation = nil
        autoScrollTask?.cancel()
        autoScrollTask = nil
        BangHaptics.prepare()
    }

    /// 拖动接近上下边缘时按行自动滚动，让长文也能一次选到底。
    private func startAutoScroll(proxy: ScrollViewProxy) {
        autoScrollTask?.cancel()
        autoScrollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(140))
                guard selecting, let location = lastDragLocation, wallHeight > 0 else { continue }
                // 先按最新布局把选中范围推进到指下词块，再滚动补足视野。
                extendSelection(at: location)
                let threshold: CGFloat = 56
                if location.y < threshold {
                    scrollAdjacentLine(by: -1, anchor: .top, proxy: proxy)
                } else if location.y > wallHeight - threshold {
                    scrollAdjacentLine(by: 1, anchor: .bottom, proxy: proxy)
                }
            }
        }
    }

    private func scrollAdjacentLine(by delta: Int, anchor: UnitPoint, proxy: ScrollViewProxy) {
        let referenceID = lastHit ?? (delta < 0 ? lineGroups.first?.first?.id : lineGroups.last?.last?.id)
        guard let referenceID,
              let lineIndex = lineGroups.firstIndex(where: { $0.contains { $0.id == referenceID } })
        else { return }
        let targetIndex = lineIndex + delta
        guard lineGroups.indices.contains(targetIndex) else { return }
        let target = lineGroups[targetIndex]
        guard let targetID = delta < 0 ? target.first?.id : target.last?.id else { return }
        withAnimation(.linear(duration: 0.16)) {
            proxy.scrollTo(targetID, anchor: anchor)
        }
    }

    private func tokenID(at point: CGPoint) -> Int? {
        tokenFrames.first(where: { $0.value.contains(point) })?.key
    }

    /// 词墙分组：段落 → 行 → 词块（保留原文的分段结构）。
    private func rebuildGroups() {
        var paragraphs: [[[TextToken]]] = []
        var flatLines: [[TextToken]] = []
        var paragraphLines: [[TextToken]] = []
        var lineTokens: [TextToken] = []
        var currentParagraph: Int?
        var currentLine: Int?

        func flushLine() {
            guard !lineTokens.isEmpty else { return }
            paragraphLines.append(lineTokens)
            flatLines.append(lineTokens)
            lineTokens = []
        }

        for token in tokens {
            if token.paragraphIndex != currentParagraph {
                flushLine()
                if !paragraphLines.isEmpty {
                    paragraphs.append(paragraphLines)
                    paragraphLines = []
                }
                currentParagraph = token.paragraphIndex
                currentLine = token.lineIndex
            } else if token.lineIndex != currentLine {
                flushLine()
                currentLine = token.lineIndex
            }
            lineTokens.append(token)
        }
        flushLine()
        if !paragraphLines.isEmpty {
            paragraphs.append(paragraphLines)
        }
        paragraphGroups = paragraphs
        lineGroups = flatLines
    }

    private func tokenView(_ token: TextToken) -> some View {
        let isSelected = selected.contains(token.id)
        let isEntity = entityTokenMap.values.contains { $0.contains(token.id) }
        let isHighlight = !isSelected && !isEntity && highlightKeywords.contains(token.text)
        return Button {
            toggle(token.id)
        } label: {
            Text(token.text)
                .font(.system(size: 17, weight: token.isPunctuation ? .regular : .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(background(isSelected: isSelected, isHighlight: isHighlight, isEntity: isEntity))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { tokenFrames[token.id] = geo.frame(in: .named("bangWall")) }
                    .onChange(of: geo.frame(in: .named("bangWall"))) { _, frame in
                        tokenFrames[token.id] = frame
                    }
            }
        )
    }

    private func background(isSelected: Bool, isHighlight: Bool, isEntity: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.22))
        }
        if isEntity {
            // 结构化信息词块（电话/邮箱/链接等）独立配色
            return AnyShapeStyle(Color.teal.opacity(0.18))
        }
        if isHighlight {
            return AnyShapeStyle(Color.yellow.opacity(0.16))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.09))
    }

    private var selectionTools: some View {
        HStack(spacing: 16) {
            Button("全选") { selectAll() }
            Button("整句") { selectSentence() }
            Button("清空") { selected = [] }
            Spacer()
            Text(selectedText.isEmpty
                ? LocalizedStringKey("未选取")
                : LocalizedStringKey("\(selected.count) 块"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .buttonStyle(.borderless)
        .tint(.accentColor)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("复制", icon: "doc.on.doc") { copySelection() }
            actionButton("搜索", icon: "magnifyingglass") { searchSelection() }
            exportMenu
            Button {
                onDone()
            } label: {
                actionLabel("完成", icon: "checkmark")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var exportMenu: some View {
        Menu {
            Button {
                bridge.presentShareSheet([payload(for: selectedText).markdown])
            } label: {
                Label("存入备忘录（分享面板）", systemImage: "note.text")
            }
            Button {
                exportObsidian()
            } label: {
                Label("Obsidian", systemImage: "circle.grid.cross")
            }
            Button {
                exportBear()
            } label: {
                Label("Bear", systemImage: "bear")
            }
            Button {
                exportCustom()
            } label: {
                Label("自定义模板", systemImage: "link")
            }
        } label: {
            actionLabel("导出", icon: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
    }

    private func actionButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(title, icon: icon) }
            .buttonStyle(.bordered)
    }

    private func actionLabel(_ title: LocalizedStringKey, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.medium))
    }

    private var toastView: some View {
        Group {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
    }

    // MARK: - 行为

    private func toggle(_ id: Int) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
        lastTapped = id
    }

    private func selectAll() {
        selected = Set(tokens.map(\.id))
    }

    private func selectSentence() {
        let anchor: Int?
        if let lastTapped, tokens.contains(where: { $0.id == lastTapped }) {
            anchor = lastTapped
        } else {
            anchor = selected.sorted().first ?? tokens.first?.id
        }
        guard let anchor, let anchorToken = tokens.first(where: { $0.id == anchor }) else { return }
        let ids = tokens.filter { $0.sentenceIndex == anchorToken.sentenceIndex }.map(\.id)
        selected.formUnion(ids)
    }

    private func payload(for text: String) -> ExportPayload {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? self.text : trimmed
        let title = NaturalLanguageExtractor.extractTitle(from: finalText)
        return ExportPayload(title: title.isEmpty ? String(localized: "拾文速记") : title, text: finalText, tags: highlightKeywords)
    }

    private func copySelection() {
        let content = selectedText.isEmpty ? text : selectedText
        UIPasteboard.general.string = content
        showToast(String(localized: "已复制 \(content.count) 字"))
    }

    private func searchSelection() {
        // 跨行/跨段选取拼出来带换行，搜索前压成单空格。
        let query = selectedText
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            showToast(String(localized: "请先选取要搜索的词块"))
            return
        }
        performSearch(query)
    }

    /// 用指定关键词搜索（选中词块或信息提取项共用）。
    private func performSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let config = ExportConfig.current
        let urlString = config.searchEngineBase + ExportService.encoded(trimmed)
        guard let url = URL(string: urlString) else {
            showToast(String(localized: "搜索地址无效"))
            return
        }
        if bridge.openURL(url) {
            showToast(String(localized: "正在搜索…"))
        } else {
            UIPasteboard.general.string = trimmed
            showToast(String(localized: "无法打开浏览器，已复制搜索词"))
        }
    }

    private func exportObsidian() {
        let config = ExportConfig.current
        guard let url = ExportService.obsidianURL(payload: payload(for: selectedText), vault: config.obsidianVault) else {
            showToast(String(localized: "导出内容为空"))
            return
        }
        openOrFallback(url, app: "Obsidian")
    }

    private func exportBear() {
        guard let url = ExportService.bearURL(payload: payload(for: selectedText)) else {
            showToast(String(localized: "导出内容为空"))
            return
        }
        openOrFallback(url, app: "Bear")
    }

    private func exportCustom() {
        let config = ExportConfig.current
        guard let url = ExportService.customURL(template: config.customTemplate, payload: payload(for: selectedText)) else {
            showToast(String(localized: "请先在设置中配置导出模板"))
            return
        }
        openOrFallback(url, app: config.customName.isEmpty ? String(localized: "自定义模板") : config.customName)
    }

    private func openOrFallback(_ url: URL, app: String) {
        if bridge.openURL(url) {
            showToast(String(localized: "已发送到 \(app)"))
        } else {
            UIPasteboard.general.string = payload(for: selectedText).markdown
            showToast(String(localized: "未检测到 \(app)，全文已复制"))
        }
    }

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if toast == message {
                toast = nil
            }
        }
    }
}
