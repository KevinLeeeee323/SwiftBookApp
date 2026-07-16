# SwiftBook · 仿 Apple Books 的 iOS EPUB 阅读器

[English Version (英文版)](README_EN.md)

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB)

一个用 SwiftUI + WKWebView 实现的 iOS EPUB 电子书阅读器，UI 仿 Apple Books：导入 EPUB、左右翻页（点击 / 滑动 / 底部进度条 / 音量键）、调节字号字体主题。

![display_pic](Display.JPEG)

> **当前状态**：MVP 可用。已实测环境：macOS 15.6 / Xcode 26.3 / iOS 18.6 真机 & iOS 26 模拟器。逐项状态见 [TODO.md](TODO.md)。

---

## 功能

| 功能 | 状态 |
|------|------|
| EPUB 导入（文件 App → .epub） | ✅ |
| 分页 & 翻页：点击左右区 / 左右滑动 / 底部进度条 | ✅ |
| 单击屏幕中部：呼出 / 收起控制条 | ✅ |
| 断点续读（记住上次页码，书库进度条同步） | ✅ |
| 字号(12–40) / 字体(苹方·思源宋体·Georgia 等) / 行距 / 对齐 / 主题(白·暖黄·暗黑·护眼绿) / 页边距 | ✅ |
| EPUB 内嵌图片 / 封面图渲染 | ✅ |
| 音量键翻页（音量+ 上一页，音量- 下一页，不改系统音量） | ✅ |
| 目录: 点击可跳转到对应章节, 但是部分目录识别不准确 | ✅ |

---

## 项目结构

```
Reader/
├── README.md                 # 本文件
├── README_EN.md              # 英文版 README
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
        └── Resources/
            ├── Info.plist
            └── Fonts/                         # 思源宋体 (Git LFS 管理)
```

**改动最集中的文件是 [SwiftBook/Sources/Views/ReaderView.swift](SwiftBook/Sources/Views/ReaderView.swift)** —— 阅读与分页、手势、设置注入、断点续读、图片改写都在这里（含 `BookWebView` 这个 `UIViewRepresentable` 和内嵌的分页 JS）。

---

## 构建 & 运行（仅 Mac + Xcode）

```bash
git clone git@github.com:KevinLeeeee323/SwiftBookApp.git
cd SwiftBookApp
open SwiftBook/SwiftBook.xcodeproj
```

> 💡 **如需思源宋体 / 思源宋体·粗**：项目中的中文字体文件使用 Git LFS 管理，直接 `git clone` 得到的只是指针。请先安装 Git LFS 并拉取字体：
>
> ```bash
> brew install git-lfs
> git lfs install
> git lfs pull          # 拉取 .otf 字体文件（约 75MB，三个字重）
> ```
>
> 如果不需要这两种字体，可跳过 `git lfs pull`，App 仍可正常编译运行（中文只有苹方）。

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

### 系统要求

| | 最低版本 |
|---|---|
| iOS | 16.0 |
| macOS | 14.0 (Sonoma) |
| Xcode | 15.0 |
| Swift | 5.9 |

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

### 5. 音量键翻页（真机已验证）
- KVO 监听 `AVAudioSession.outputVolume`；`.playback + .mixWithOthers` 且激活会话；**循环播放内存里生成的静音 WAV（volume=0）**保持会话有输出——否则 outputVolume 的 KVO 常常不触发（模拟器尤甚），按键会退回改铃声音量。
- 在 key window 里放一个 1×1、几乎透明的 `MPVolumeView` 抑制系统音量 HUD，并借它的 `UISlider` 把音量**复位到 0.5 基准**，保证上/下都还有变化量可测。
- **真机已验证通过。** 模拟器不可测（属模拟器限制）。

### 6. 中文字体：打包思源宋体
- iOS 只自带苹方（PingFang SC）一种中文字体，宋体/楷体是 macOS 字体、iOS 上没有。要提供真正的宋体阅读体验，必须**打包开源字体**。
- 项目通过 Git LFS 管理了 **Source Han Serif SC** Regular + SemiBold + Bold（思源宋体，OFL 许可，免费可商用）。
- 字体约 25MB/个，三个共约 75MB。clone 后需执行 `git lfs pull` 拉取实际字体文件。

### 6. EPUB 解析与解压
- EPUB 本质是 ZIP：`ZipReader` 手写最小解析（stored + deflate）；`EPUBParser` 走 `META-INF/container.xml` → OPF（元数据/manifest/spine）→ NCX/TOC。
- 解压时**所有路径扁平化**（`/`→`_`）落到 `Documents/Extracted/<书名>/`；章节 HTML 里的图片引用再用 `rewriteResourceRefs` 按"扁平全路径→文件名→`_文件名`后缀"改写到真实解压文件名。

---

## 已知限制

- **音量键翻页**在模拟器不可测（模拟器限制），真机已通过。
- 只支持 EPUB（无 PDF）；无书签/笔记、无全文搜索、无 TTS、无同步。
- 阅读区常驻全屏（忽略安全区）；靠 `marginV` + `env(safe-area-inset-*)` 避让灵动岛。
- 中文字体目前提供苹方和思源宋体两种风格（宋体/楷体需要打包额外字体，见 §6）。

后续计划见 [TODO.md](TODO.md)。

## Co-Contributors / 鸣谢

本项目在开发过程中获得以下 AI 工具协助：
- Claude
- Codex
- DeepSeek

## License
MIT

---

[English Version (英文版)](README_EN.md)
