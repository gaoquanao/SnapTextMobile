import SwiftUI

/// 首次启动引导：4 页滑动介绍核心概念与三条捕获路径。
/// 完成或跳过后写入 `SettingsKeys.onboardingSeen`，之后不再自动出现；
/// 设置页的「查看使用引导」可随时重新打开。
struct OnboardingView: View {
    /// 结束回调；参数为 true 表示用户选择了「查看快捷指令配置」，应跳转到设置页。
    var onFinish: (Bool) -> Void

    @State private var page: Int

    private let pageCount = 4

    init(initialPage: Int = 0, onFinish: @escaping (Bool) -> Void) {
        _page = State(initialValue: min(max(initialPage, 0), 3))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                welcomePage.tag(0)
                capturePage.tag(1)
                bigBangPage.tag(2)
                readyPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(backgroundGradient)
    }

    // MARK: - 页面框架

    private var header: some View {
        HStack {
            Spacer()
            Button("跳过") {
                onFinish(false)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.trailing, 20)
            .padding(.top, 12)
        }
    }

    private var footer: some View {
        VStack(spacing: 18) {
            pageDots
            if page < pageCount - 1 {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("下一步")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 28)
            } else {
                Button {
                    onFinish(true)
                } label: {
                    Label("查看快捷指令配置", systemImage: "wand.and.rays")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 36)
        .padding(.top, 12)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == page ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.accentColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 第 1 页 · 品牌

    private var welcomePage: some View {
        VStack(spacing: 26) {
            Spacer()
            sealIcon
            VStack(spacing: 10) {
                Text("拾文")
                    .font(.system(size: 40, weight: .bold))
                Text("截图即知识")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tint)
            }
            Text("识别、提取、归档，全部在设备本地完成，不上传任何数据。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
            Spacer()
            Spacer()
        }
    }

    /// 复刻 App 图标：暖纸底 + 朱红印章「拾」。
    private var sealIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.965, green: 0.937, blue: 0.878),
                                 Color(red: 0.925, green: 0.886, blue: 0.800)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 156, height: 156)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.91, green: 0.33, blue: 0.28),
                                 Color(red: 0.76, green: 0.18, blue: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 102, height: 102)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 2)
                        .padding(8)
                }
            Text("拾")
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - 第 2 页 · 三条捕获路径

    private var capturePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("三种方式，随手捕获")
                .font(.title2.weight(.bold))
            VStack(spacing: 14) {
                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "分享截图",
                    subtitle: "从分享面板送入拾文，立即识别归档"
                )
                FeatureRow(
                    icon: "button.programmable",
                    title: "操作按钮一按",
                    subtitle: "弹出大爆炸，瞬间选取文字"
                )
                FeatureRow(
                    icon: "bolt.badge.automatic.fill",
                    title: "截屏自动化",
                    subtitle: "截图那一刻自动入库，零操作"
                )
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    // MARK: - 第 3 页 · 大爆炸

    private var bigBangPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("大爆炸选取")
                .font(.title2.weight(.bold))
            VStack(spacing: 10) {
                mockTokenWall
                Text("轻点词块选取 · 横向拖动连选 · 自动按中英文拼合")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            Text("选中的文字可直接复制、搜索、导出到备忘录或 Obsidian")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    /// 静态词块墙演示：蓝底为选中态，黄底为关键词高亮。
    private var mockTokenWall: some View {
        TokenFlowLayout(lineSpacing: 8, itemSpacing: 6) {
            ForEach(Array(demoTokens.enumerated()), id: \.offset) { index, token in
                Text(token)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(tokenBackground(index))
                    .foregroundStyle(index < 6 ? Color.accentColor : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func tokenBackground(_ index: Int) -> some ShapeStyle {
        if index < 6 {
            return AnyShapeStyle(Color.accentColor.opacity(0.22))
        }
        if [8, 9, 14].contains(index) {
            return AnyShapeStyle(Color.yellow.opacity(0.22))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.10))
    }

    private let demoTokens = [
        "WWDC26", "发布", "Foundation", "Models", "框架", "开发者",
        "可在", "设备", "本地", "调用", "约", "30", "亿", "参数", "的", "大模型", "。",
    ]

    // MARK: - 第 4 页 · 开始使用

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            VStack(spacing: 10) {
                Text("准备好开始了")
                    .font(.title2.weight(.bold))
                Text("建议先在设置里按引导绑定操作按钮，体验一按即识别")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }
}

/// 引导页的功能行：圆角图标 + 标题 + 说明。
private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 46, height: 46)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
