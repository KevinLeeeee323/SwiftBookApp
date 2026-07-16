# SwiftBook · An Apple Books-style EPUB Reader for iOS

[中文版README (README in Chinese)](README_CN.md)

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-147EFB)
![License](https://img.shields.io/badge/license-MIT-green)

A SwiftUI + WKWebView EPUB reader for iOS, designed to look and feel like Apple Books. Import EPUBs, flip pages (tap / swipe / progress bar / **volume buttons**), and customize fonts, themes, and layouts.

![display_pic](Display.JPEG)

> **Status**: MVP — usable daily. Tested on: macOS 15.6 / Xcode 26.3 / iOS 18.6 device & iOS 26 simulator. See [TODO.md](TODO.md) for what's next.

---

## Why This Exists

iOS's built-in Books app — along with nearly every third-party reader (Kindle, Apple Books, etc.) — **does not let you turn pages with the volume buttons**. This has been a standard feature on Android and HarmonyOS for years, but Apple doesn't expose a public API for it.

I wanted to read in bed without reaching out of the covers to tap the screen every page. So I built SwiftBook.

---

## Features

| Feature | Status |
|---------|--------|
| EPUB import (Files app → .epub) | ✅ |
| Pagination & page-turn: tap left/right · swipe · progress bar | ✅ |
| Tap center to show/hide controls | ✅ |
| Resume reading (persists last page; progress bar syncs in library) | ✅ |
| Font size (12–40) · font family (PingFang · Source Han Serif · Georgia & more) · line spacing · alignment · themes (white · warm · dark · eye-care green) · margins | ✅ |
| Embedded images & cover rendering | ✅ |
| **Volume button page turn** (Vol+ = prev page, Vol- = next page; system volume unchanged) | ✅ |
| Table of contents with chapter jump (partial accuracy on complex EPUBs) | ✅ |

---

## Project Structure

```
Reader/
├── README.md                 # Chinese README (this file is English)
├── README_EN.md              # ← You are here
├── TODO.md                   # Progress & roadmap
├── create_project.sh         # One-click .xcodeproj generator
└── SwiftBook/
    ├── project.yml           # XcodeGen config
    ├── SwiftBook.xcodeproj/   # Pre-generated Xcode project
    └── Sources/
        ├── App/SwiftBookApp.swift              # App entry point
        ├── Models/
        │   ├── Book.swift                      # Book model (spine, chapters, progress, cover)
        │   └── ReadingSettings.swift           # Reading settings (font, theme, margins… enums)
        ├── Views/
        │   ├── LibraryView.swift               # Library grid + import
        │   ├── ReaderView.swift                # ★ Core reader (BookWebView)
        │   ├── SettingsPanelView.swift         # Bottom settings panel
        │   └── BookCardView.swift              # Library card + progress bar
        ├── Services/
        │   ├── BookManager.swift               # Library, import, unzip, progress persistence
        │   ├── EPUBParser.swift                # container.xml → OPF → spine / TOC
        │   └── VolumeButtonHandler.swift       # Volume key KVO → page turn
        ├── Utilities/ZipReader.swift           # Minimal ZIP decompressor (stored + deflate)
        └── Resources/
            ├── Info.plist
            └── Fonts/                         # Source Han Serif (Git LFS managed)
```

**The file you'll touch most is [SwiftBook/Sources/Views/ReaderView.swift](SwiftBook/Sources/Views/ReaderView.swift)** — pagination, gestures, settings injection, resume reading, and image rewriting all live here (including `BookWebView`, a `UIViewRepresentable` with inline pagination JS).

---

## Build & Run (macOS + Xcode only)

```bash
git clone git@github.com:KevinLeeeee323/SwiftBookApp.git
cd SwiftBookApp
open SwiftBook/SwiftBook.xcodeproj
```

> 💡 **For Source Han Serif fonts**: The Chinese serif font files are managed with Git LFS. A plain `git clone` only gets pointers. To pull the actual fonts:
>
> ```bash
> brew install git-lfs
> git lfs install
> git lfs pull          # Pulls ~75 MB of .otf files (three weights)
> ```
>
> If you don't need these two fonts, skip `git lfs pull` — the app compiles and runs fine (Chinese text will use PingFang only).

The Xcode project is pre-generated — just open and run:

```bash
open SwiftBook/SwiftBook.xcodeproj
```

If you add/remove files under `Sources/` and need to regenerate the project:

```bash
brew install xcodegen                 # first time only
cd SwiftBook && xcodegen generate     # regenerate .xcodeproj from project.yml
# or: ./create_project.sh
```

In Xcode: select the **SwiftBook** target → **Signing & Capabilities** → pick your development team, change the Bundle ID → choose device/simulator → ▶️.

### Requirements

| | Minimum |
|---|---|
| iOS | 16.0 |
| macOS | 14.0 (Sonoma) |
| Xcode | 15.0 |
| Swift | 5.9 |

---

## Implementation Deep-Dive (Lessons Learned)

> More granular notes live in my Claude memory (`reader-webview-architecture.md`). Below is the human-readable version.

### 1. Pagination: WKWebView + CSS Multi-Column

- All spine chapters are assembled into a **single HTML** document inside `#reader-container`. Each chapter is a `.content-chunk` with `break-before: column` so chapters start on a fresh "page".
- CSS multi-column layout: `column-width = viewport width`, `column-gap = 2 × horizontal margin`. This makes **one column = exactly one screen page**. Page-turning is `container.scrollLeft = page × pageStep`; `measure()` divides `scrollWidth / pageStep` to compute total pages.
- **Native `scrollView` scrolling is disabled** — all page navigation is driven by JS `scrollLeft`.
- **Gotcha ① — WebView dimensions must be constant**: `ReaderView` uses **constant** `.ignoresSafeArea()`. I previously toggled safe area insets based on `showControls`, causing the WebView to resize every time the control bar appeared/disappeared → `resize → recalculatePages` → pages jumped vertically, and progress-bar navigation would jitter text. With a fixed frame, page-turning is pure horizontal displacement. `applyScroll()` also locks `scrollTop` to 0.
- **Gotcha ② — local images need `loadFileURL(_:allowingReadAccessTo:)`**: Generated HTML is written to `Extracted/<book>/_reader_generated.html` and loaded as a file URL for local file read permissions. `loadHTMLString(baseURL:)` silently blocks images.

### 2. Settings Injection: Flat JSON + Quote Escaping

- Settings go Swift→JS as a **flat** JSON dictionary (enums resolved to strings like `bgColor`, `fontFamilyCSS`, `textAlign` upfront) to avoid nested encoding headaches.
- **Gotcha ③ (once broke ALL interactivity)**: The default font CSS contains single quotes (`…'San Francisco'…`). If you interpolate that raw into a JS single-quoted string, the entire `<script>` block throws a SyntaxError → `goToPage`, `applySettings`, `measure` are all undefined. The body renders, but sliders, font buttons, and page-turning are all dead. Fix: all JS-side defaults are generated via `JSONSerialization` into a `DEFAULTS` object (JSON handles escaping automatically); on injection, additionally escape `\` and `'`.

### 3. Resume Reading: Seed State in `init`

- `ReaderView.init(book:)` seeds `@State` variables directly from `book.currentPage`/`totalPages`; `buildReaderHTML(initialPage:)` scrolls JS to the right page on load; `loadContent` sets `pendingPage = book.currentPage`.
- **Gotcha ④**: If `currentPage` equals `pendingPage` initially, `updateUIView` won't fire a spurious `goToPage(0)`. That spurious 0 would be saved by `.onChange(of: currentPage)`, **wiping progress to 0%** (symptom: library card progress bar stuck at 0%). Moral: never read `@Binding` during `loadContent` — it's still 0 then.

### 4. Gestures: Tap & Swipe Unified

- A transparent `Color.clear` overlay captures a **single** `DragGesture(minimumDistance: 0)`: significant horizontal drag → page turn; near-zero movement (treated as tap) → left third = prev page / right third = next page / middle = toggle controls.
- **Gotcha ⑤**: An earlier approach with three separate tap zones + a standalone swipe gesture caused gesture conflicts over the WebView (tap vs. drag arena dispute); swipe often wouldn't register. A single combined gesture owns the interaction exclusively and is stable.
- When controls are visible, a full-screen transparent capture layer underneath the control ZStack catches center taps to dismiss (`.onTapGesture` on the VStack alone misses taps on `Spacer` regions).

### 5. Volume Button Page Turn (Verified on Device)

- KVO on `AVAudioSession.outputVolume`; `.playback + .mixWithOthers` with an active audio session; **a silent WAV (volume = 0) loops in-memory** to keep the session "playing". Without an active output, `outputVolume` KVO often doesn't fire (especially on simulator) — button presses fall back to changing ringer volume.
- A 1×1 nearly-transparent `MPVolumeView` in the key window suppresses the system volume HUD. Its internal `UISlider` resets volume to a **0.5 baseline** after each detection, ensuring both up and down always have room to produce a delta.
- **Verified on real device.** Not testable on simulator (simulator limitation).

### 6. Chinese Fonts: Bundling Source Han Serif

- iOS ships only one Chinese font: PingFang SC. Serif and KaiTi are macOS fonts — unavailable on iOS. To offer genuine serif reading, you must **bundle an open-source font**.
- This project manages **Source Han Serif SC** (Regular + SemiBold + Bold) via Git LFS. OFL license — free for commercial use.
- Font files are ~25 MB each, ~75 MB total. Run `git lfs pull` after cloning to retrieve them.

### 7. EPUB Parsing & Unzipping

- EPUB is essentially a ZIP file: `ZipReader` is a hand-rolled minimal decompressor (stored + deflate); `EPUBParser` traverses `META-INF/container.xml` → OPF (metadata / manifest / spine) → NCX / TOC.
- All extracted paths are **flattened** (`/`→`_`) into `Documents/Extracted/<book>/`. Image references in chapter HTML are rewritten via `rewriteResourceRefs`: try the flattened full path → fall back to filename → suffix-match against `_filename`.

---

## Known Limitations

- **Volume button page-turn** is not testable on simulator (simulator limitation). Works on real devices.
- EPUB only (no PDF). No bookmarks / notes, no full-text search, no TTS, no sync.
- Reading area is full-screen (ignores safe area); uses `marginV` + `env(safe-area-inset-*)` to avoid the Dynamic Island.
- Chinese fonts: currently PingFang + Source Han Serif (Song/Ming style). KaiTi (regular script) would require bundling an additional font.

See [TODO.md](TODO.md) for the roadmap.

---

## Co-Contributors / Acknowledgments

This project was developed with AI assistance from:

- Claude (Anthropic)
- Codex (OpenAI)
- DeepSeek

---

## License

MIT — see [LICENSE](LICENSE) (if present) or the repository metadata.

---

[中文版 (Chinese README)](README.md)
