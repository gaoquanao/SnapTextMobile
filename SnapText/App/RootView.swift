import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.privacyLockEnabled) private var privacyLockEnabled = false
    @AppStorage(SettingsKeys.onboardingSeen) private var onboardingSeen = false
    @State private var locked = false
    @State private var captureSession: CaptureSession?
    @State private var demoBigBang: EntrySheet?
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var listReloadToken = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ArchiveListView(reloadToken: listReloadToken)
                .tabItem { Label("归档", systemImage: "archivebox") }
                .tag(0)
            CaptureView()
                .tabItem { Label("捕获", systemImage: "plus.viewfinder") }
                .tag(1)
            SetupGuideView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(2)
        }
        .fullScreenCover(item: $captureSession) { session in
            CaptureFlowView(image: session.image, source: session.source) {
                captureSession = nil
            }
        }
        .fullScreenCover(item: $demoBigBang) { sheet in
            BigBangEntryScreen(entry: sheet.entry, preselectCount: 12) {
                demoBigBang = nil
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(initialPage: DemoSupport.onboardingPage) { openSettings in
                onboardingSeen = true
                showOnboarding = false
                if openSettings {
                    selectedTab = 2
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapPendingCapture)) { _ in
            presentPending()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // 快捷指令冷启动 App 时，通知可能早于视图挂载，回到前台时补查一次。
                presentPending()
                listReloadToken += 1
                SpotlightIndexer.indexPendingEntries(context: ArchiveStore.mainContext)
            case .background:
                if privacyLockEnabled {
                    locked = true
                }
                BackgroundRefresher.schedule()
            default:
                break
            }
        }
        .task {
            await DemoSupport.seedIfNeeded()
            applyDemoScreen()
            presentPending()
            SpotlightIndexer.indexPendingEntries(context: ArchiveStore.mainContext)
            presentOnboardingIfNeeded()
            await DemoSupport.runDeleteDrillIfNeeded()
        }
        .overlay {
            if privacyLockEnabled && locked {
                LockScreenView { locked = false }
                    .transition(.opacity)
            }
        }
        .onAppear {
            PhotoWatchService.shared.startIfEnabled()
        }
    }

    private func presentPending() {
        if let image = CaptureBus.shared.takePending() {
            captureSession = CaptureSession(image: image)
        }
    }

    /// 演示模式：启动参数指定界面（Release 下 DemoSupport.screen 恒为 nil，无行为）。
    private func applyDemoScreen() {
        switch DemoSupport.screen {
        case .settings:
            selectedTab = 2
        case .capture:
            selectedTab = 1
        case .onboarding:
            showOnboarding = true
        case .bigbang:
            if let entry = DemoSupport.firstEntry() {
                demoBigBang = EntrySheet(entry: entry)
            }
        case .list, .none:
            break
        }
    }

    /// 首次启动展示引导。以下情况让路、等下次正常启动：
    /// 快捷指令带着截图拉起（优先展示大爆炸）、演示模式指定了界面、已被隐私锁占用。
    private func presentOnboardingIfNeeded() {
        guard !onboardingSeen,
              DemoSupport.screen == nil,
              captureSession == nil,
              demoBigBang == nil,
              !showOnboarding,
              !locked
        else { return }
        // 给启动流程一点缓冲，避免与首帧渲染/数据加载抢动画。
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !onboardingSeen, captureSession == nil, demoBigBang == nil else { return }
            showOnboarding = true
        }
    }
}

/// fullScreenCover(item:) 的包装。
struct CaptureSession: Identifiable {
    let id = UUID()
    let image: UIImage
    var source: ArchiveSource = .quickButton
}
