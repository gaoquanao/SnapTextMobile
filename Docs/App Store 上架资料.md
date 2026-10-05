# App Store Connect 上架资料 · 拾文 SnapText

> 本文档为逐字段可复制粘贴的上架资料。方括号 `[ ]` 处需要你替换为真实信息（支持网址、联系方式等）。

## 0. 上架前检查清单

- [ ] 付费开发者账号（¥688/年）已激活，App Store Connect 中已创建 App（Bundle ID `me.snaptext.app`）
- [ ] 隐私政策网址可访问（草案见 [隐私政策.md](隐私政策.md)，托管建议：GitHub Pages）
- [ ] 支持网址可访问（可用 GitHub 仓库页或新建一个简单页面）
- [ ] App 图标（已内置，含浅色/深色/染色三态）
- [ ] 截图（已生成：`Design/Screenshots/`，五语言 × 4 张，6.9 英寸 1320×2868）
- [ ] Xcode → Product → Archive → Distribute App → App Store Connect 上传构建版本
- [ ] `Info.plist` 已声明 `ITSAppUsesNonExemptEncryption = false`（无需出口合规文档）
- [ ] `PrivacyInfo.xcprivacy` 隐私清单已内置（仅声明 UserDefaults 原因代码 CA92.1）

---

## 1. App 信息（App Information，与语言无关）

| 字段 | 填写内容 |
| --- | --- |
| 名称 | 拾文（App Store 名称，可加空格副标；设备端显示名已本地化为 拾文 / SnapText） |
| 主要语言 | 简体中文 |
| Bundle ID | `me.snaptext.app` |
| SKU | `SNAPTEXT001`（自定义，唯一即可） |
| 主要类别 | **效率**（Productivity） |
| 次要类别 | **工具**（Utilities） |
| 价格 | 免费（或按需设置） |
| App 内购买 | 无 |
| 内容版权 | 不包含第三方内容 |
| 年龄分级 | **4+**（分级问卷全部选「无」/「否」，详见第 4 节） |
| 隐私政策网址 | `[ ]` 必填 |
| 支持网址 | `[ ]` 必填 |
| 营销网址 | `[ ]` 选填 |

---

## 2. App 隐私（隐私标签）逐项填写

App 不收集任何数据——无账号、无网络请求、无分析/广告 SDK，识别与提取全部在设备本地完成。

**填写路径**：App Store Connect → 你的 App → App 隐私 → 开始填写

1. **「你会从此 App 收集数据吗？」** → 选择 **「否，我们不从此 App 收集数据」**
2. 保存后隐私标签将显示为 **Data Not Collected（未收集数据）**
3. 「隐私选项」页其余问题：无需再勾选任何数据类型

**为什么这样填是准确的**（自查依据）：

| 检查项 | 现状 |
| --- | --- |
| 网络代码 | 全项目无 URLSession/Alamofire 等网络调用 |
| 分析 SDK | 无 |
| 账号体系 | 无 |
| 广告 | 无 |
| 数据去向 | 照片、识别文本、归档仅存本机 App Group 容器；导出仅在用户主动操作时经系统分享面板/URL Scheme 交给你选择的目标 App |
| 相册读取 | 仅在用户使用「相册自动收集/处理最近截图」时读取，用于本机识别，不上传 |
| 第三方框架 | 仅系统框架（Vision / NaturalLanguage / SwiftData / Photos 等） |

**隐私清单**：`PrivacyInfo.xcprivacy` 已随包提交，声明访问的 UserDefaults（原因代码 CA92.1）；`NSPrivacyCollectedDataTypes` 为空数组，与「未收集数据」一致。

> 注意：隐私政策网址是必填项，而「隐私标签」与「隐私政策网页」是两回事，都需要提供。政策草案见 [隐私政策.md](隐私政策.md)。

---

## 3. 各语言元数据

在 App Store Connect 的「App 信息 → 本地化」中为以下五个语言分别填写。

### 3.1 简体中文（zh-Hans）

- **名称**（≤30）：`拾文`
- **副标题**（≤30）：`截图即知识 · 端侧OCR与归档`
- **关键词**（≤100，逗号分隔）：`文字识别,提取文字,大爆炸,笔记,备忘录,离线,快捷指令,扫描,OCR,知识管理`
- **推广文本**（≤170，可随时更新）：
  `截图之后一按即识别：大爆炸式词块选取，自动生成标题标签，一键存入备忘录/Obsidian/Bear。全程设备本地完成，无网络也能用。`
- **描述**（≤4000）：

```
拾文把「截图」变成可检索的知识，全程在设备本地完成。

【三条捕获路径】
• 分享：截图后点缩略图 → 分享到拾文 → 立即识别归档
• 一按即识别：把快捷指令绑定到操作按钮（原静音键）或轻点背面，按下瞬间弹出大爆炸选取
• 全自动：开启「截屏时」自动化或相册自动收集，截图实时入库，零操作

【大爆炸式文本选取】
识别结果自动炸成词块墙：
• 轻点选取、横向拖动连选，自动按中英文规则拼合
• 全选、整句选取、关键词高亮
• 选完直接复制、搜索或导出

【端侧 AI 知识提取】
• Vision OCR 中英日韩西多语言识别，离线可用
• 自动生成标题、摘要、标签、分类
• iOS 26 + Apple Intelligence 机型自动升级端侧大模型提取

【收集与整理】
• 相册自动收集：监控全部截图或指定相簿（前台实时，后台补漏）
• 拍照识别与文档扫描（自动纠偏增强、多页连拍）
• 相册多选批量导入、剪贴板、拖拽
• 重复截图自动查重；Spotlight 全局搜索直达

【导出到你的知识库】
• 苹果备忘录、Obsidian、Bear 直达
• 自定义 URL 模板适配 flomo、Craft 等任意应用
• 全库导出 Markdown / JSON 备份

【隐私】
无账号、无网络请求、无分析 SDK。照片与文字只存在你的手机上，FaceID 隐私锁可选。

截图即知识。拾文，拾起散落的文字。
```

- **新功能**（首版）：
  `首个版本。支持分享/操作按钮/相册自动收集三条捕获路径、大爆炸词块选取、端侧 OCR 与知识提取、备忘录与 Obsidian/Bear 导出。`

### 3.2 English (U.S.)

- **名称**：`SnapText - Screenshot to Text`
- **副标题**：`On-device OCR & Smart Archive`
- **关键词**：`ocr,text scanner,screenshot,extract,notes,clipboard,offline,shortcuts,reader,scanner`
- **推广文本**（≤170）：
  `One press after a screenshot: Big Bang token selection, auto titles and tags, export to Notes, Obsidian or Bear. Everything runs on device — no network needed.`
- **描述**：

```
SnapText turns screenshots into searchable knowledge — entirely on your device.

THREE WAYS TO CAPTURE
• Share: screenshot → share sheet → SnapText recognizes and archives instantly
• One press: bind a shortcut to the Action Button or Back Tap for an instant Big Bang selection overlay
• Fully automatic: "When Screenshot is Taken" automation or photo-library auto-capture — zero taps

BIG BANG TEXT SELECTION
Recognition results explode into a wall of tokens:
• Tap to select, drag to sweep — smart CJK/Latin joining
• Select all, select sentence, keyword highlights
• Copy, search or export your selection

ON-DEVICE AI EXTRACTION
• Vision OCR for Chinese, English, Japanese, Korean and Spanish — offline
• Automatic title, summary, tags and category
• On iOS 26 with Apple Intelligence: automatic upgrade to the on-device foundation model

COLLECT & ORGANIZE
• Photo-library auto-capture: watch all screenshots or a specific album (real-time in foreground, background catch-up)
• Camera capture and document scanning (auto edge correction, multi-page)
• Multi-select import, clipboard, drag & drop
• Duplicate detection; Spotlight search to jump straight to an archive

EXPORT TO YOUR KNOWLEDGE BASE
• Apple Notes, Obsidian, Bear
• Custom URL template for flomo, Craft and more
• Full-library export as Markdown / JSON

PRIVACY
No account, no network requests, no analytics SDK. Photos and text stay on your phone. Optional Face ID lock.

Screenshots become knowledge.
```

- **新功能**：
  `First release: three capture paths (share sheet, Action Button, photo auto-capture), Big Bang token selection, on-device OCR and knowledge extraction, Notes / Obsidian / Bear export.`

### 3.3 日本語

- **名称**：`SnapText - スクショをテキスト化`
- **副标题**：`オンデバイスOCR・自動保存`
- **关键词**：`スクリーンショット,OCR,文字認識,テキスト抽出,コピー,メモ,オフライン,ショートカット,クリップボード,スキャン`
- **推广文本**（≤170）：
  `スクリーンショットのあとワンプッシュ：ビッグバン選択で単語をサッと選び、タイトルとタグを自動生成。メモ・Obsidian・Bearへ書き出し。すべてデバイス上で完結、オフラインでも使えます。`
- **描述**：

```
SnapTextはスクリーンショットを検索できる知識に変えます。処理はすべてデバイス上で完結。

3つの取り込み方法
• 共有：スクリーンショット→共有シート→SnapTextで即認識・保存
• ワンプッシュ：ショートカットをアクションボタンや背面タップに割り当て、押すだけでビッグバン選択を表示
• 完全自動：「スクリーンショット撮影時」オートメーションまたは写真ライブラリの自動収集で操作ゼロ

ビッグバン選択
認識結果が単語ブロックの壁に展開：
• タップで選択、横になぞって連続選択（日中英の混在も自動整形）
• すべて選択・文単位・キーワード強調
• 選択したテキストをコピー・検索・書き出し

オンデバイスAI抽出
• Vision OCR：中国語・英語・日本語・韓国語・スペイン語、オフライン対応
• タイトル・要約・タグ・分類を自動生成
• iOS 26 + Apple Intelligence搭載機ではオンデバイスモデルに自動アップグレード

収集と整理
• 写真ライブラリの自動収集：全スクリーンショットまたは指定アルバムを監視
• 撮影認識と書類スキャン（自動補正・複数ページ）
• 複数選択インポート・クリップボード・ドラッグ&ドロップ
• 重複スクリーンショットの自動検出、Spotlightからアーカイブへ直行

書き出し
• メモ、Obsidian、Bear
• カスタムURLテンプレートでflomoやCraftなどにも対応
• 全アーカイブをMarkdown / JSONでバックアップ

プライバシー
アカウント不要・通信なし・解析SDKなし。写真とテキストは端末内のみ。Face IDロック対応。

スクリーンショットが、知識になる。
```

- **新功能**：
  `初回リリース：3つの取り込み経路、ビッグバン選択、オンデバイスOCRと知識抽出、メモ/Obsidian/Bear書き出しに対応。`

### 3.4 한국어

- **名称**：`SnapText - 스크린샷 텍스트`
- **副标题**：`온디바이스 OCR · 자동 보관`
- **关键词**：`스크린샷,OCR,텍스트 추출,복사,메모,오프라인,단축어,클립보드,스캔,보관`
- **推广文本**（≤170）：
  `스크린샷 후 한 번만 누르면 빅뱅 선택으로 단어를 빠르게 고르고 제목과 태그가 자동 생성됩니다. 메모, Obsidian, Bear로 내보내기. 모든 처리는 기기에서, 오프라인에서도 동작합니다.`
- **描述**：

```
SnapText는 스크린샷을 검색 가능한 지식으로 바꿉니다. 모든 처리는 기기에서 이루어집니다.

세 가지 수집 방법
• 공유: 스크린샷 → 공유 시트 → SnapText에서 즉시 인식·보관
• 한 번 누르기: 단축어를 동작 버튼이나 뒤쪽 탭에 연결해 누르는 순간 빅뱅 선택 표시
• 완전 자동: '스크린샷 촬영 시' 자동화 또는 사진 보관함 자동 수집으로 터치 없이 보관

빅뱅 텍스트 선택
인식 결과가 단어 블록 벽으로 펼쳐집니다:
• 탭하여 선택, 가로로 드래그해 연속 선택(중·영·일 혼합 자동 결합)
• 전체 선택, 문장 단위, 키워드 강조
• 선택한 텍스트 복사·검색·내보내기

온디바이스 AI 추출
• Vision OCR: 중국어·영어·일본어·한국어·스페인어, 오프라인 지원
• 제목·요약·태그·분류 자동 생성
• iOS 26 + Apple Intelligence 기기에서는 온디바이스 모델로 자동 업그레이드

수집과 정리
• 사진 보관함 자동 수집: 전체 스크린샷 또는 지정 앨범 감시
• 촬영 인식과 문서 스캔(자동 보정·여러 페이지)
• 여러 장 가져오기·클립보드·드래그 앤 드롭
• 중복 스크린샷 자동 감지, Spotlight에서 바로 열기

내보내기
• 메모, Obsidian, Bear
• 사용자 정의 URL 템플릿으로 flomo, Craft 등 지원
• 전체 보관함을 Markdown / JSON으로 백업

개인정보 보호
계정 없음·네트워크 요청 없음·분석 SDK 없음. 사진과 텍스트는 기기에만 저장. Face ID 잠금 지원.

스크린샷이 곧 지식.
```

- **新功能**：
  `첫 릴리스: 세 가지 수집 경로, 빅뱅 선택, 온디바이스 OCR과 지식 추출, 메모/Obsidian/Bear 내보내기 지원.`

### 3.5 Español (Mexico)

- **名称**：`SnapText - Capturas a texto`
- **副标题**：`OCR en el dispositivo y archivo`
- **关键词**：`captura,OCR,texto,extraer,notas,copiar,sin conexión,atajos,portapapeles,escáner`
- **推广文本**（≤170）：
  `Tras una captura, un toque: selección Big Bang por palabras, títulos y etiquetas automáticos y exportación a Notas, Obsidian o Bear. Todo ocurre en el dispositivo, sin conexión.`
- **描述**：

```
SnapText convierte tus capturas de pantalla en conocimiento buscable, todo en el dispositivo.

TRES FORMAS DE CAPTURAR
• Compartir: captura → hoja de compartir → SnapText reconoce y archiva al instante
• Un toque: asigna un atajo al botón Acción o a Tocar atrás y obtén la selección Big Bang al momento
• Totalmente automático: automatización «Al hacer captura» o recolección automática de Fotos, sin tocar nada

SELECCIÓN BIG BANG
Los resultados se despliegan como un muro de bloques de palabras:
• Toca para seleccionar, arrastra para elegir en cadena (unión inteligente de idiomas)
• Todo, frase completa, resaltado de palabras clave
• Copia, busca o exporta la selección

EXTRACCIÓN CON IA EN EL DISPOSITIVO
• Vision OCR en chino, inglés, japonés, coreano y español, sin conexión
• Genera título, resumen, etiquetas y categoría automáticamente
• En iOS 26 con Apple Intelligence: se mejora al modelo en el dispositivo

RECOLECTA Y ORGANIZA
• Recolección automática: vigila todas las capturas o un álbum específico
• Cámara y escáner de documentos (corrección automática, varias páginas)
• Importación múltiple, portapapeles, arrastrar y soltar
• Detección de duplicados y búsqueda en Spotlight

EXPORTA A TU BASE DE CONOCIMIENTO
• Notas de Apple, Obsidian, Bear
• Plantilla de URL personalizada para flomo, Craft y más
• Exporta todo como Markdown / JSON

PRIVACIDAD
Sin cuenta, sin peticiones de red, sin SDK de análisis. Tus fotos y textos se quedan en el teléfono. Bloqueo con Face ID opcional.

Tus capturas se vuelven conocimiento.
```

- **新功能**：
  `Primera versión: tres formas de capturar, selección Big Bang, OCR y extracción en el dispositivo y exportación a Notas / Obsidian / Bear.`

---

## 4. 年龄分级问卷（Age Rating）

在 App Store Connect → App 年龄分级中，以下条目全部选择 **「无」/「否」**：

- 卡通或幻想暴力、写实暴力、色情或裸露、亵渎或粗俗幽默、酒精/烟草/毒品
- 成熟或暗示性主题、恐怖/惊悚、医疗/治疗信息
- 赌博（真实与模拟）
- 用户生成内容、社交功能、不受限制的网络访问 —— 均为「否」
- App 内是否提供家长控制：否

预期结果：**4+**。

> 说明：App 的搜索结果跳转通过外部浏览器打开（离开 App），App 本身不含内置浏览器，因此「不受限制的网络访问」选「否」。

---

## 5. 审核备注（App Review Information）

**联系信息**：填你的姓名/电话/邮箱（必填）。

**备注**（英文，粘贴到「备注」框）：

```
Hello — SnapText is a fully offline screenshot-to-knowledge tool. No account or login is required.

How to test the core flow (no special setup needed):
1. Take a screenshot, tap the thumbnail, and share it into SnapText — the app performs on-device OCR (Vision), auto-generates title/tags, archives it, and opens the "Big Bang" token-selection screen where words can be tapped or drag-selected, then copied/exported.
2. Alternatively, use the Capture tab: choose photos, read an image from the clipboard, drag & drop, or use the camera/document scanner (device only).
3. Export options: Save to Notes via the share sheet; Obsidian/Bear via their URL schemes (no-ops if not installed).

Optional integrations (not required to review):
- App Intents "Big Bang screenshot" / "Silently archive screenshot" can be wired in the Shortcuts app with the "Take Screenshot" action (Action Button / Back Tap / "When Screenshot is Taken" automation).
- Photo-library auto-capture and "Process latest screenshot" use PhotoKit; photo permission is requested only when the user enables these features.

Photo deletion (Settings → Screenshot Cleanup) is OFF by default and only affects silent capture paths (photo auto-capture, Control Center control). When enabled, iOS presents its own confirmation before any photo is deleted, and deleted items remain in Recently Deleted for 30 days. Interactive flows (share sheet, manual import, Big Bang) never delete photos.

Privacy: no network requests, no analytics, no third-party SDKs. All data stays in the app's on-device container.

Note: the app was notarized… [不需要]
```

> 提示：审核员可能拿不到「操作按钮」机型，因此备注第一段把「分享 → 大爆炸」列为主要验证路径；相册权限弹窗只会出现在用户主动开启相册功能时。

---

## 6. 截图（App Store 截图）

已生成 25 张，位于 [`Design/Screenshots/`](../Design/Screenshots/)（iPhone 6.9 英寸规格 1320×2868，App Store 必填尺寸）：

| 文件 | 内容 | 建议顺序 |
| --- | --- | --- |
| `01-archive-list.png` | 归档列表（标题/摘要/标签/来源） | 第 3 张 |
| `02-bigbang.png` | **大爆炸词块选取（核心卖点）** | 第 1 张 |
| `03-capture.png` | 捕获导入（相册/剪贴板/拖拽） | 第 4 张 |
| `04-settings.png` | 设置与快捷指令引导 | 第 5 张 |
| `05-onboarding.png` | 首次引导「三种捕获方式」 | 第 2 张 |

语言：`zh-Hans / en / ja / ko / es` 各一套，与元数据本地化一一对应。
`zh-Hans/onboarding-flow/` 下另有中文引导四页全流程参考图（01-04），供你核对引导文案（该子目录不需要上传）。

- 如需 iPad 版截图，需另建 iPad 模拟器重新截取（当前工程为 iPhone 单设备，`TARGETED_DEVICE_FAMILY = 1`）
- 截图中的状态栏已用 `9:41 / 满电` 营销样式；重截可用 `Scripts/capture-screenshots.sh`
- 12/14 英寸大屏截图与 App 预览视频为可选项

---

## 7. 构建与上传

1. Xcode 打开工程 → 三个 target 设置你的付费团队（App Groups 能力需付费账号注册）
2. 顶部设备选 **Any iOS Device (arm64)** → **Product → Archive**
3. Organizer → **Distribute App → App Store Connect → Upload**
4. 等待处理完成后，在 App Store Connect 选择该构建版本，填写本文档元数据 → 提交审核

> 使用免费个人账号无法上传 App Store；上传需付费开发者账号（脚本 `Scripts/build-ipa.sh` 同样支持填入付费 Team ID 出包）。
