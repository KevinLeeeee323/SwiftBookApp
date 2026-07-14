# SwiftBook · 仿 Apple Books 的 iOS EPUB 阅读器

一个用 SwiftUI + WKWebView 实现的 iOS EPUB 电子书阅读器，UI 仿 Apple Books：导入 EPUB、左右翻页（点击 / 滑动 / 底部进度条 / 音量键）、调节字号字体主题。

> **当前状态**：MVP 可用，已在 iOS 模拟器（26.3）跑通导入与阅读全流程。逐项状态见 [TODO.md](TODO.md)。
> **构建约束**：只能在 Mac 的 Xcode 里编译运行（这里的环境无法编译）；音量键翻页需**真机**验证，模拟器结果不可信。

---

## 功能

| 功能 | 状态 |
|------|------|
| EPUB 导入（文件 App → .epub） | ✅ |
| 分页 & 翻页：点击左右区 / 左右滑动 / 底部进度条 | ✅ |
| 单击屏幕中部：呼出 / 收起控制条 | ✅ |
| 断点续读（记住上次页码，书库进度条同步） | ✅ |
| 字号(12–32) / 字体 / 行距 / 对齐 / 主题(白·暖黄·暗黑·护眼绿) / 页边距 | ✅ |
| EPUB 内嵌图片 / 封面图渲染 | ✅ |
| 音量键翻页（音量+ 下一页，音量- 上一页，不改系统音量） | 🟡 真机待验证 |

---

## 项目结构

```
Reader/
├── README.md                 # 本文件
├── TODO.md                   # 进度与后续计划
├── create_project.sh         # 一键生成 .xcodeproj 的脚本
└── SwiftBook/
    ├── project.yml           # XcodeGen 配置
    ├── SwiftBook.xcodeproj/   # 已生成的 Xcode 工程
    └── Sources/
        ├── App/SwiftBookApp.swift              # App 入口
        ├── Models/
        │   ├── Book.swift                      # 书籍模型（spine/chapters/进度/封面）
        │   └── ReadingSettings.swift           # 阅读设置（字号/字体/主题/边距…枚举）
        ├── Views/
        │   ├── LibraryView.swift               # 书库主界面（网格 + 导入）
        │   ├── ReaderView.swift                # ★ 阅读器（核心，含 BookWebView）
        │   ├── SettingsPanelView.swift         # 底部设置面板
        │   └── BookCardView.swift              # 书库卡片 + 进度条
        ├── Services/
        │   ├── BookManager.swift               # 书库/导入/解压/进度持久化
        │   ├── EPUBParser.swift                # 解析 container.xml→OPF→spine/TOC
        │   └── VolumeButtonHandler.swift       # 音量键 KVO → 翻页
        ├── Utilities/ZipReader.swift           # 最小 ZIP 解压（stored + deflate）
        └── Resources/Info.plist
```

**改动最集中的文件是 [SwiftBook/Sources/Views/ReaderView.swift](SwiftBook/Sources/Views/ReaderView.swift)** —— 阅读与分页、手势、设置注入、断点续读、图片改写都在这里（含 `BookWebView` 这个 `UIViewRepresentable` 和内嵌的分页 JS）。

---

## 构建 & 运行（仅 Mac + Xcode）

工程已经生成好，直接打开即可：

```bash
open SwiftBook/SwiftBook.xcodeproj
```

若 `Sources/` 结构有增删、需要重新生成工程：

```bash
brew install xcodegen                 # 首次
cd SwiftBook && xcodegen generate     # 按 project.yml 重建 .xcodeproj
# 或：./create_project.sh
```

在 Xcode 里选 target **SwiftBook** → **Signing & Capabilities** 选开发团队、改 Bundle ID → 选真机/模拟器 → ▶️。
要求：iOS 16.0+ / Xcode 15+ / Swift 5.9+。

---

## 核心实现与工程要点（含踩过的坑）

> 更细的实现笔记记录在 Claude 记忆库（`.claude/.../memory/reader-webview-architecture.md`）。下面是给人看的浓缩版。

### 1. 分页：WKWebView + CSS 多栏
- 整本书的所有 spine 章节拼成**一个 HTML**，塞进 `#reader-container`，每章一个 `.content-chunk`（`break-before: column` 让每章另起一页）。
- 用 CSS 多栏分页：`column-width = 内容宽`、`column-gap = 2×左右边距`，于是**一页正好 = 容器 `clientWidth`**。翻页即 JS `container.scrollLeft = 页码 × pageStep`；`measure()` 用 `scrollWidth / pageStep` 反算总页数。
- **原生 `scrollView` 滚动被禁用**，翻页完全由 JS 的 `scrollLeft` 驱动。
- **坑①（最近修的）——WebView 尺寸必须恒定**：`ReaderView` 里读书区用**常量** `.ignoresSafeArea()`。之前把忽略的安全区边随 `showControls` 切换，导致控制条一显示/隐藏 WebView 就缩放 → 触发 `resize→recalculatePages` 重排 → 页面上下抽动、滑块翻页时文字乱跳。固定尺寸后翻页只剩纯水平位移。`applyScroll()` 里还顺手把 `scrollTop` 锁 0。
- **坑②——本地图片必须用 `loadFileURL(_:allowingReadAccessTo:)`**：把生成的 HTML 写到 `Extracted/<书>/_reader_generated.html` 再以 file URL 加载，才有本地文件读取权限；`loadHTMLString(baseURL:)` 不给权限，图片静默失败。

### 2. 设置注入：扁平 JSON + 引号转义
- 设置 Swift→JS 走**扁平** JSON 字典（枚举先解析成 `bgColor/fontFamilyCSS/textAlign` 等字符串），避免嵌套编码问题。
- **坑③（曾导致"所有交互都失效"）**：默认字体 CSS 里含单引号（`…'San Francisco'…`）。若把它裸拼进 JS 单引号字符串，会让整个 `<script>` 抛 SyntaxError → `goToPage/applySettings/measure` 全部未定义，正文还能显示但滑块/字号/翻页全哑。修法：所有 JS 侧默认值经 `JSONSerialization` 生成 `DEFAULTS`（JSON 自动转义），注入时再转义 `\` 和 `'`。

### 3. 断点续读：init 里就把状态喂满
- `ReaderView.init(book:)` 直接用 `book.currentPage/totalPages` 给 `@State` 播种；`buildReaderHTML(initialPage:)` 让 JS 初始就滚到该页；`loadContent` 里 `pendingPage = book.currentPage`。
- **坑④**：`currentPage` 与 `pendingPage` 起始相等，`updateUIView` 就不会误发 `goToPage(0)`；否则那次 0 会被 `.onChange(of: currentPage)` 存回，**把进度清成 0%**（表现为"书库进度条卡在 0%")。切记别在 `loadContent` 时机读 `@Binding`（那时还是 0）。

### 4. 手势：点击与滑动合成一个
- 读书区盖一层透明 `Color.clear`，用**单个** `DragGesture(minimumDistance:0)` 同时判定：明显水平拖 → 翻页；几乎没动（当点击）→ 左 1/3 上一页 / 右 1/3 下一页 / 中间呼出控制条。
- **坑⑤**：早期"三个点击区 + 单独一个滑动手势"会在 WebView 上争手势（tap vs drag 竞技场冲突），滑动经常不识别。合成一个手势后独占、稳定。
- 控制条显示时，其 ZStack 底层垫一层全屏透明捕获层，中间单击即收起（直接把 `.onTapGesture` 挂 VStack 会漏掉 `Spacer` 空白区的点击）。

### 5. 音量键翻页（真机待验证）
- KVO 监听 `AVAudioSession.outputVolume`；`.playback + .mixWithOthers` 且激活会话；**循环播放内存里生成的静音 WAV（volume=0）**保持会话有输出——否则 outputVolume 的 KVO 常常不触发（模拟器尤甚），按键会退回改铃声音量。
- 在 key window 里放一个 1×1、几乎透明的 `MPVolumeView` 抑制系统音量 HUD，并借它的 `UISlider` 把音量**复位到 0.5 基准**，保证上/下都还有变化量可测。
- **坑⑥/未决**：模拟器里可能只加音量、不翻页——这是模拟器限制，**必须真机验证**。

### 6. EPUB 解析与解压
- EPUB 本质是 ZIP：`ZipReader` 手写最小解析（stored + deflate）；`EPUBParser` 走 `META-INF/container.xml` → OPF（元数据/manifest/spine）→ NCX/TOC。
- 解压时**所有路径扁平化**（`/`→`_`）落到 `Documents/Extracted/<书名>/`；章节 HTML 里的图片引用再用 `rewriteResourceRefs` 按"扁平全路径→文件名→`_文件名`后缀"改写到真实解压文件名。

---

## 已知限制

- **音量键翻页**在模拟器上不可信，需真机确认（见上 §5）。
- 只支持 EPUB（无 PDF）；无书签/笔记、无全文搜索、无 TTS、无同步（按产品范围有意排除搜索/快捷指令）。
- 阅读区常驻全屏（忽略安全区）——刘海机型极端小边距下，正文首行可能靠近状态栏；目前靠 `marginV` 留白，未做单独安全区内衬。

后续计划见 [TODO.md](TODO.md)。

## License
MIT
