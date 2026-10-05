# 拾文 · SnapText

截图即知识。一款纯端侧的 iOS 截图文本自动归档与知识提取 App：截图之后一按即识别，弹出「大爆炸」式词块选取，瞬间完成归档与导出。

## 三条行为路径

| 路径 | 流程 |
| --- | --- |
| 分享 | 截图 → 点缩略图分享 → **拾文** → 扩展内立即 OCR → 大爆炸选取 → 自动归档/导出 |
| 操作按钮（核心） | 快捷指令「截屏 → 拾文」绑定操作按钮/轻点背面 → 一按即识别，App 弹出大爆炸 |
| App 内 | 捕获页从相册选图 / 读剪贴板 / 拖拽导入 → 识别 → 大爆炸 |

## 能力

- **端侧 OCR**（Vision，中/英/日/韩/西可选，离线）：识别、提取、归档全程不上传
- **文本规整与 AI 润色**：OCR 碎片文本自动整理成可读 Markdown——合并被硬换行截断的段落、清理异常空格、修正标点（中英语境分别处理，列表项保留为 Markdown 列表）；iOS 26 + Apple Intelligence 机型追加端侧大模型润色（严格只排版不改写 + 长度守门防改写）；标题由全文自动摘要生成，不超过 20 字
- **大爆炸选取**：NLTokenizer 词级分词 + 标点独立成块，词块墙**按原文段落/行分组渲染**（分段可见），轻点选取、**长按拖动连选**（跨行跨段整段扫选、贴边自动滚动、词块边界触感反馈）；复制结果忠实还原原文——跨段保留空行、跨行保留换行、词块间隔与原文一致（邮箱 / URL / 版本号不会被拆开）；支持全选、整句、关键词高亮
- **信息提取分组**：大爆炸顶部自动把**电话 / 邮箱 / 链接 / 日期 / 数字**单独成组（正则提取 + 误报排除：列表序号、时间、字母数字混合、电话内数字不重复计数）；轻点组内项即复制，长按可搜索或回填选中对应词块；结构化词块在词墙内以青色高亮
- **图片长按（Haptic Touch）直达大爆炸**：来源截图长按弹出菜单，可直接进入「大爆炸文字提取」或「查看原图」
- **知识提取**：
  - iOS 18–25：规则式（命名实体 + 词频关键词 + 首行标题/首句摘要）
  - iOS 26 + Apple Intelligence 机型：自动升级为 **Foundation Models 端侧大模型**，生成标题/摘要/标签/分类（`canImport` 门控，Xcode 26 构建时自动启用）
- **自动归档**：所有路径进入即存 SwiftData（App Group 共享容器），标题/标签可编辑、全文可搜索；**重复截图自动查重**（感知哈希 + 文本匹配，命中即复用既有归档）
- **收集入口**：
  - 分享扩展（1–5 张图，多张走批量队列）
  - **开箱即用控件**：控制中心与操作按钮（iOS 18「控制」）可直接绑定「大爆炸识别」/「归档最近截图」，无需组装快捷指令
  - **内置快捷指令配方（一键导入）**：配方 A「截屏 → 大爆炸」、配方 B「截屏 → 静默归档 → 通知」随安装包分发并已签名，设置页点「一键添加到快捷指令」→ 系统菜单选「快捷指令」→ 添加即可，导入后可自由修改；配方 C「截屏时自动归档」为系统自动化，iOS 不允许导入，按引导创建一次（详见 `Scripts/build-shortcuts.py` 与 Docs 指南）
  - 快捷指令/操作按钮/轻点背面（4 个 App Intent，进阶玩法）
  - **相册自动收集**：监控「系统全部截图」或指定相簿——前台实时（PHPhotoLibraryChangeObserver）+ 后台补漏（BGAppRefreshTask，iOS 26 可升级照片库专用任务）；从开启时刻起增量收集，断点续传
  - **拍照识别**（UIImagePickerController）与**文档扫描**（VisionKit，自动纠偏增强、多页连拍）
  - 相册多选导入 / 剪贴板 / 拖拽，多张自动进**批量处理队列**（逐行状态、行内大爆炸、单行撤销）
- **导出**：
  - 苹果备忘录（Markdown 全文经系统分享面板直发）
  - Obsidian（`obsidian://new` 直达指定 Vault，配置后可**发送测试笔记**验证）
  - Bear（`bear://x-callback-url/create`）
  - 自定义 URL 模板（`{title} {content} {markdown} {tags} {tagsHash} {date}`，支持发送测试笔记）
  - **全库导出** Markdown / JSON（防丢、可迁移）
  - 复制 / 系统分享面板始终可用；导出配置区支持键盘「完成」收起与滚动收起
- **系统整合**：Spotlight 全局搜索归档内容并直达详情；来源截图可点击全屏查看（双指缩放/拖动/双击）；FaceID 隐私锁；隐私清单 PrivacyInfo.xcprivacy 已内置
- **截图清理策略**（默认关闭，设置页显式开启）：静默归档（相册自动收集、控制中心控件、静默归档兜底）成功后把源截图从相册移除，改由拾文保管。iOS 规定删除必须经系统弹窗确认，删除的图片进入「最近删除」保留 30 天；分享与手动导入的图片不受影响
- **首次使用引导**：4 页滑动引导（品牌 / 三条捕获路径 / 大爆炸演示 / 开始使用），仅首次启动展示，设置页「查看使用引导」可随时回看；被快捷指令带截图拉起时让路，不遮挡实际任务

## 工程结构

```
project.yml                  # XcodeGen 配置（4 个 target）
SharedKit/                   # 双/三 target 共享源码
  Models/                    # ArchiveEntry + App Group 存储
  Core/OCR/                  # Vision OCR + 图片预处理
  Core/BigBang/              # 分词、拼接、流式布局、BigBangView
  Core/Extraction/           # NL 提取器 + FoundationModels（iOS 26 gated）
  Core/Export/               # 各知识库 URL 构建 + 宿主桥接
  Core/Pipeline/             # 捕获管线 + 捕获流程页
SnapText/                    # 主 App：归档流 / 详情 / 捕获 / 设置引导 / AppIntents
SnapTextShareExtension/      # 分享扩展（复用 CaptureFlowView + BigBangView）
SnapTextWidgets/             # 控制中心 ControlWidget
Tests/                       # 分词 / 拼接 / 导出模板 单元测试
```

## 构建运行

要求：Xcode 16.2+（iOS 18 SDK）。本机无 `xcodegen` 时先 `brew install xcodegen`。

```bash
xcodegen generate          # 生成 SnapText.xcodeproj
open SnapText.xcodeproj
```

1. 团队签名已在 `project.yml` 统一配好（`DEVELOPMENT_TEAM: QGC87Z9JX3`，三个 App target 共用）；更换团队只改这一处，再 `xcodegen generate`
2. App Group `group.com.snaptext.app` 已随团队注册，保持现状即可；如确需改名，请同步替换 `SharedKit/Support/AppGroup.swift`、三个 `.entitlements` 和 `project.yml`
3. 真机运行（快捷指令、操作按钮、分享扩展均需真机体验）

跑测试：

```bash
xcodebuild test -project SnapText.xcodeproj -scheme SnapText \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6'
```

## 快捷指令 / 操作按钮配置

见 [Docs/快捷指令配置指南.md](Docs/快捷指令配置指南.md)，App 内「设置」页也有同样的图文引导。**两条核心配方已内置在 App 中，一键导入**，无需手动搭建：

- **配方 A · 拾文·大爆炸（默认）**：`截屏` → `拾文：大爆炸截图识别` —— 想马上查看并整理文字
- **配方 B · 拾文·静默归档**：`截屏` → `拾文：静默归档截图` → `显示通知` —— 不打断当前操作
- **配方 C · 截屏自动归档**：系统自动化（截屏时触发），iOS 不允许导入，按引导创建一次

配方文件由 [Scripts/build-shortcuts.py](Scripts/build-shortcuts.py) 生成（含 `shortcuts sign` 签名，导入无需开启「允许不受信任的快捷指令」），产物在 `SnapText/Resources/Shortcuts/`。

## 上架资料

- **[Docs/App Store 上架资料.md](Docs/App Store 上架资料.md)**：五语言元数据（名称/副标题/关键词/描述/新功能）、隐私标签逐项填写、年龄分级问卷、审核备注、截图清单、上传流程
- **[Docs/隐私政策.md](Docs/隐私政策.md)** / **[privacy-policy.html](Docs/privacy-policy.html)**：中英双语隐私政策（HTML 可直接托管为隐私政策网址）
- **Design/Screenshots/**：App Store 截图，5 语言 × 5 张（大爆炸选取 / 归档列表 / 捕获导入 / 设置引导 / 首次引导），6.9 英寸 1320×2868 规格；重新生成用 `Scripts/capture-screenshots.sh`（依赖 DEBUG 构建的演示参数）

## 已知边界

- 备忘录无公开写 API，走系统分享面板直发（官方正路）
- 相册自动收集：前台 observer 实时；后台由系统择机调度（iOS 26 起可升级为随相册变化精确唤醒的 BGPhotoLibraryRefreshTask，代码已预留说明）；后台收集需系统开启「后台 App 刷新」
- 分享扩展内存受限，超大截图会先降采样再 OCR
- iOS 18 机型上知识提取为规则式（关键词+首句标题），无生成式摘要；iOS 26 机型自动获得大模型能力
- 相机/文档扫描仅真机可用（模拟器隐藏入口）；iCloud 同步（需付费开发者账号）留待后续版本
- **截图清理的删除确认需真机验证**：未签名的模拟器构建无法通过 iOS 相册授权（TCC 要求有效代码签名），删除流程在模拟器上只能验证到系统授权边界；真机（免费/付费签名均可）上首次归档触发的相册授权弹窗与删除确认弹窗请实际操作确认一遍。项目内置验证通道：DEBUG 构建用 `-SnapTextDemoDeleteDrill 1` 启动参数可直接触发一次删除请求
- 截图清理策略限定「静默通道」：带界面的流程（分享扩展、大爆炸选取、手动导入）永不删除用户的照片

## 多语言

支持 **简体中文（源语言）、English、日本語、한국어、Español** 五种语言，随系统语言自动切换（App 内文案、分享扩展、控制中心控件、弹窗授权说明、Siri/快捷指令短语全部覆盖）。

- 翻译表：[SnapText/Resources/Localizable.xcstrings](/Users/gaoquanao/ZCodeProject/SnapText/Resources/Localizable.xcstrings)（String Catalog，172 条键 × 4 目标语言，三个 target 共用）
- 系统文案：[SnapText/Resources/InfoPlist.xcstrings](/Users/gaoquanao/ZCodeProject/SnapText/Resources/InfoPlist.xcstrings)（App 名称「拾文 / SnapText」与相册权限说明）
- OCR 识别语言同步提供 5 组预设：中英、中英日、中英日韩、中英西、全部语言
- 运行时拼接的字符串已在代码中使用 `String(localized:)`，避免绕过本地化

**新增语言**：用 Xcode 打开 `Localizable.xcstrings` → 左下角 ＋ 添加语言 → 在表里逐条填写即可（空条目回退到中文源文案）；`InfoPlist.xcstrings` 同样处理，并在 `project.yml` 的 `CFBundleLocalizations` 里登记。命令行构建会自动把目录编译进 App、分享扩展与控件扩展。

## App 图标

设计稿与生成脚本在 `Design/Icons/`（`make_icons.swift`，CoreGraphics 渲染 1024×1024）。当前默认使用**印章风**三态：

| 模式 | 文件 |
| --- | --- |
| 浅色 | `icon-light.png`（暖纸底 + 朱红印章「拾」） |
| 深色 | `icon-dark.png`（墨底 + 朱红印章） |
| 染色（iOS 18 Tinted） | `icon-tinted.png`（灰阶印章） |

替换方法：把 `Design/Icons/` 里其他备选（`A-indigo.png` 靛蓝渐变白字、`C-ink-paper.png` 楷体墨字小印）覆盖 `SnapText/Resources/Assets.xcassets/AppIcon.appiconset/` 下对应文件后重新构建即可。
