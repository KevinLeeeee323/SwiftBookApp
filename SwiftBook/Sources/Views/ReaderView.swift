import SwiftUI
import WebKit
import AVFoundation

struct ChapterMetric {
    var pageOffset: Int
    var pageCount: Int
}

// MARK: - Reader View
struct ReaderView: View {
    @EnvironmentObject var bookManager: BookManager
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var currentPage: Int
    @State private var totalPages: Int
    @State private var showControls = false
    @State private var showSettings = false
    @State private var showTOC = false
    @State private var chapterTitle = ""
    @State private var chapters: [Chapter]
    @State private var activeChapterIndex: Int?

    @StateObject private var settings = ReadingSettingsStore()
    @StateObject private var volumeHandler = VolumeButtonHandler()

    init(book: Book) {
        self.book = book
        // Seed the reading position from the persisted value up front, so there is
        // never a 0 -> savedPage transition that could post/save page 0 and wipe
        // the stored progress.
        _currentPage = State(initialValue: max(0, book.currentPage))
        _totalPages = State(initialValue: max(book.totalPages, 1))
        _chapters = State(initialValue: book.chapters)
        _activeChapterIndex = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            // Reading content
            readingContent

            // Top/bottom controls overlay
            if showControls && !showSettings && !showTOC {
                controlsOverlay
            }

            // Settings panel
            if showSettings {
                settingsPanelOverlay
            }

            // Table of contents panel
            if showTOC {
                tocPanelOverlay
            }
        }
        .onAppear {
            setupVolumeButtons()
        }
        .onDisappear {
            volumeHandler.stop()
            saveProgress()
        }
        .onChange(of: currentPage) { _ in
            saveProgress()
        }
        .onChange(of: settings.settings.enableVolumeButtons) { enabled in
            if enabled {
                setupVolumeButtons()
            } else {
                volumeHandler.stop()
            }
        }
        .onChange(of: chapters) { _ in
            // Keep the top bar title in sync with the current chapter mapping.
            if let active = activeChapterIndex,
               active >= 0,
               active < chapters.count {
                chapterTitle = chapters[active].title
            }
        }
        .preferredColorScheme(colorSchemeForTheme)
        .statusBarHidden(!showControls)
        .animation(.easeInOut(duration: 0.25), value: showControls)
        .animation(.easeInOut(duration: 0.3), value: showSettings)
    }

    // MARK: - Reading Content (WKWebView)
    private var readingContent: some View {
        GeometryReader { geometry in
            BookWebView(
                book: book,
                settings: settings.settings,
                currentPage: $currentPage,
                totalPages: $totalPages,
                chapterTitle: $chapterTitle,
                chapterMetrics: Binding(
                    get: { chapters.map { ChapterMetric(pageOffset: $0.pageOffset, pageCount: $0.pageCount) } },
                    set: { metrics in
                        var updated = chapters
                        for index in updated.indices {
                            guard index < metrics.count else { break }
                            updated[index].pageOffset = metrics[index].pageOffset
                            updated[index].pageCount = metrics[index].pageCount
                        }
                        chapters = updated
                    }
                ),
                activeChapterIndex: $activeChapterIndex,
                viewportSize: geometry.size
            )
            // A single transparent layer over the WebView captures BOTH taps
            // (left/center/right zones) and horizontal swipes. Using one gesture
            // avoids the tap-vs-drag arena conflict that made swiping unreliable.
            .overlay {
                if !showControls && !showSettings {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleReadingGesture(value, width: geometry.size.width)
                                }
                        )
                }
            }
        }
        // Keep the WebView pinned to the WHOLE screen at all times. Previously the
        // ignored safe-area edges were toggled with `showControls`, so every time
        // the controls appeared/disappeared the WebView resized (full-screen <->
        // safe-area inset). That resize forced a CSS re-layout (resize ->
        // recalculatePages), which made the page jump vertically ("上下抽动") and
        // shifted the text when paging via the slider. A constant frame => the
        // geometry never changes => no reflow, so page turns stay purely horizontal.
        .ignoresSafeArea()
    }

    // MARK: - Reading gesture (unified tap + swipe)
    /// Interprets a touch on the reading area: a horizontal drag turns the page,
    /// a tap on the left/right third turns the page, and a tap in the middle
    /// reveals the controls.
    private func handleReadingGesture(_ value: DragGesture.Value, width: CGFloat) {
        let dx = value.translation.width
        let dy = value.translation.height

        // Horizontal swipe (must be clearly horizontal, not a vertical scroll)
        if abs(dx) > 45 && abs(dx) > abs(dy) * 1.4 {
            if dx < 0 { nextPage() } else { previousPage() }
            return
        }

        // Otherwise treat a near-stationary touch as a tap on a zone.
        if abs(dx) < 16 && abs(dy) < 16 {
            let x = value.startLocation.x
            if x < width * 0.28 {
                previousPage()
            } else if x > width * 0.72 {
                nextPage()
            } else {
                withAnimation { showControls = true }
            }
        }
    }

    // MARK: - Controls Overlay
    private var controlsOverlay: some View {
        ZStack {
            // Full-screen tap catcher: a single tap anywhere in the middle hides
            // the controls, so the user can immediately tap-to-turn again.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { showControls = false }
                }

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Bottom bar
                bottomBar
            }
        }
        .transition(.opacity)
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("书库")
                        .font(.body)
                }
                .foregroundColor(settings.settings.theme.accentColor)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(chapterTitle.isEmpty ? book.title : chapterTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(Color(hex: settings.settings.theme.textColor).opacity(0.8))

                if totalPages > 1 {
                    Text("\(currentPage + 1) / \(totalPages)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showSettings = true
                    showTOC = false
                }
            } label: {
                Image(systemName: "gear")
                    .font(.body.weight(.semibold))
                    .foregroundColor(settings.settings.theme.accentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 0)
        .background(.regularMaterial)
        .background(.shadow(.drop(color: .black.opacity(0.06), radius: 4, y: 2)))
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showTOC = true
                    showSettings = false
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .foregroundColor(settings.settings.theme.accentColor)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("目录")

            // Page slider
            if totalPages > 1 {
                HStack(spacing: 0) {
//                    Text("\(currentPage + 1)")
//                        .font(.caption.monospacedDigit())
//                        .foregroundColor(.secondary)
//                        .frame(width: 28)

                    Slider(
                        value: Binding(
                            get: { Double(currentPage) },
                            set: { currentPage = Int($0) }
                        ),
                        in: 0...Double(max(0, totalPages - 1)),
                        step: 1
                    )
                    .tint(settings.settings.theme.accentColor)

//                    Text("\(totalPages)")
//                        .font(.caption.monospacedDigit())
//                        .foregroundColor(.secondary)
//                        .frame(width: 28)
                }
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
//        .padding(.bottom, 12)
        .background(.regularMaterial)
        .background(.shadow(.drop(color: .black.opacity(0.06), radius: 4, y: -2)))
    }

    // MARK: - Settings Panel Overlay
    private var settingsPanelOverlay: some View {
        SettingsPanelView(
            settings: $settings.settings,
            isPresented: $showSettings,
            isControlsShown: $showControls
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(2)
    }

    // MARK: - Table of Contents Overlay
    private var tocPanelOverlay: some View {
        TOCPanelView(
            chapters: chapters,
            currentPage: $currentPage,
            isPresented: $showTOC,
            isControlsShown: $showControls
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(2)
    }

    // MARK: - Page Navigation
    private func nextPage() {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 1
        notifyWebViewPageChange()
        if !showControls {
            // Brief haptic
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    private func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        notifyWebViewPageChange()
        if !showControls {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    private func notifyWebViewPageChange() {
        NotificationCenter.default.post(
            name: .goToPage,
            object: nil,
            userInfo: ["page": currentPage]
        )
    }

    // MARK: - Volume Buttons
    private func setupVolumeButtons() {
        guard settings.settings.enableVolumeButtons else { return }
        volumeHandler.onVolumeUp = { previousPage() }
        volumeHandler.onVolumeDown = { nextPage() }
        volumeHandler.start()
    }

    // MARK: - Progress
    private func saveProgress() {
        bookManager.updateProgress(
            bookId: book.id,
            page: currentPage,
            totalPages: totalPages
        )
    }

    // MARK: - Theme color scheme
    private var colorSchemeForTheme: ColorScheme? {
        switch settings.settings.theme {
        case .dark: return .dark
        default:    return .light
        }
    }
}

// MARK: - Notification for page navigation
extension Notification.Name {
    static let goToPage = Notification.Name("goToPage")
    static let updateSettings = Notification.Name("updateSettings")
}

// MARK: - Reading Settings Store (ObservableObject wrapper)
final class ReadingSettingsStore: ObservableObject {
    @Published var settings: ReadingSettings {
        didSet { save() }
    }

    private let defaultsKey = "reading_settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(ReadingSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = ReadingSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - BookWebView (UIViewRepresentable)
struct BookWebView: UIViewRepresentable {
    let book: Book
    let settings: ReadingSettings
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var chapterTitle: String
    @Binding var chapterMetrics: [ChapterMetric]
    @Binding var activeChapterIndex: Int?
    let viewportSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.suppressesIncrementalRendering = false

        // Disable zooming but allow scroll
        let source = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        document.head.appendChild(meta);
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: "pageHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Pagination is driven entirely by JS (container.scrollLeft); disable the
        // native scroll view so it doesn't bounce/interfere with the tap zones.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.isPagingEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Disable selection for cleaner reading
        webView.configuration.preferences.isTextInteractionEnabled = true

        // Prevent system gestures from interfering
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load content on first render
        if context.coordinator.isContentLoaded == false {
            context.coordinator.loadContent(into: webView, book: book, settings: settings, viewportSize: viewportSize)
            context.coordinator.lastSettings = settings
        }

        // Detect settings changes and apply
        if context.coordinator.isContentLoaded && context.coordinator.lastSettings != settings {
            context.coordinator.lastSettings = settings
            applySettings(to: webView)
        }

        // Handle page change. currentPage is seeded from book.currentPage at init
        // and pendingPage from book.currentPage in loadContent, so they start equal
        // and a spurious goToPage never fires before the content is ready.
        if context.coordinator.pendingPage != currentPage {
            context.coordinator.pendingPage = currentPage
            goToPage(currentPage, in: webView)
        }

        // Store latest bindings
        context.coordinator.currentPageBinding = _currentPage
        context.coordinator.totalPagesBinding = _totalPages
        context.coordinator.chapterTitleBinding = _chapterTitle
        context.coordinator.chapterMetricsBinding = _chapterMetrics
        context.coordinator.activeChapterIndexBinding = _activeChapterIndex
        context.coordinator.parent = self
    }

    private func goToPage(_ page: Int, in webView: WKWebView) {
        let js = "goToPage(\(page));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func applySettings(to webView: WKWebView) {
        // Build a flat JS-friendly settings object (avoid enum/nested encoding issues)
        let dict: [String: Any] = [
            "fontSize": settings.fontSize,
            "fontFamilyCSS": settings.fontFamily.cssName,
            "bgColor": settings.theme.bgColor,
            "textColor": settings.theme.textColor,
            "lineSpacing": settings.lineSpacing,
            "textAlign": settings.textAlignment.cssValue,
            "marginH": settings.marginHorizontal,
            "marginV": settings.marginVertical,
            "paraSpacing": settings.paragraphSpacing,
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return }
        let escaped = jsonStr.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "applySettings('\(escaped)');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: BookWebView
        var isContentLoaded = false
        var lastSettings: ReadingSettings?
        var pendingPage: Int = 0
        var imageInlineBudget = 0   // bytes left for base64-inlining images this load

        var currentPageBinding: Binding<Int>?
        var totalPagesBinding: Binding<Int>?
        var chapterTitleBinding: Binding<String>?
        var chapterMetricsBinding: Binding<[ChapterMetric]>?
        var activeChapterIndexBinding: Binding<Int?>?

        init(_ parent: BookWebView) {
            self.parent = parent
        }

        // MARK: - Load Content
        func loadContent(into webView: WKWebView, book: Book, settings: ReadingSettings, viewportSize: CGSize) {
            let contentDir = getContentDirectory(book: book)
            var htmlChunks: [String] = []
            imageInlineBudget = 20_000_000   // inline up to ~20MB of images as data URIs

            // All extracted resource files (images/css) live flattened in contentDir.
            // We map each chapter's <img src="..."> to the actual extracted filename.
            let availableFiles = (try? FileManager.default.contentsOfDirectory(atPath: contentDir.path)) ?? []

            for (index, href) in book.spine.enumerated() {
                let fileName = href.replacingOccurrences(of: "/", with: "_")
                let fileURL = contentDir.appendingPathComponent(fileName)

                guard let htmlData = try? Data(contentsOf: fileURL) else { continue }

                // Try common encodings for EPUB (UTF-8 then UTF-16, Latin-1)
                let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .windowsCP1252]
                var htmlStr: String?
                for enc in encodings {
                    if let str = String(data: htmlData, encoding: enc) {
                        htmlStr = str
                        break
                    }
                }

                if var content = htmlStr {
                    // Extract body content, strip scripts
                    content = extractBodyContent(content)

                    // Point image references at the extracted (flattened) files. Passing
                    // the chapter's own directory lets refs like "../Images/x.png" resolve
                    // to the exact flattened filename instead of being guessed by basename.
                    let chapterDir = (href as NSString).deletingLastPathComponent
                    content = rewriteResourceRefs(content, availableFiles: availableFiles, chapterDir: chapterDir, contentDir: contentDir)

                    // Wrap in a div with an ID for page detection
                    htmlChunks.append("<div id='chunk_\(index)' class='content-chunk'>\(content)</div>")
                }
            }

            let fullHTML = buildReaderHTML(
                content: htmlChunks.joined(separator: "\n"),
                settings: settings,
                title: book.title,
                chapterTitle: chapterTitleForCurrentChunk(book: book, index: 0),
                viewportSize: viewportSize,
                initialPage: book.currentPage
            )

            isContentLoaded = true
            // Seed the pending page from the book's persisted position (authoritative),
            // not from the binding, which may still be 0 before onAppear runs.
            pendingPage = book.currentPage

            // Write the generated HTML into the content directory and load it as a
            // file URL. Unlike loadHTMLString(baseURL:), loadFileURL(allowingReadAccessTo:)
            // actually grants the WebView read access to the folder, so local images load.
            // Also copy the bundled serif font into the content dir so the @font-face rule
            // in the HTML can load it with a relative url() reference.
            let htmlURL = contentDir.appendingPathComponent("_reader_generated.html")
            // Copy bundled fonts into the content directory so the @font-face url()
            // fallback works. local() (UIAppFonts) is the primary source, but the
            // file fallback is kept as a safety net.
            func copyFont(_ filename: String, dest: String) {
                let destURL = contentDir.appendingPathComponent(dest)
                guard !FileManager.default.fileExists(atPath: destURL.path) else { return }
                let bundled = Bundle.main.url(forResource: filename, withExtension: "otf")
                           ?? Bundle.main.url(forResource: filename, withExtension: "otf", subdirectory: "Fonts")
                if let src = bundled { try? FileManager.default.copyItem(at: src, to: destURL) }
            }
            copyFont("SourceHanSerifSC-Regular", dest: "_reader_font_serif.otf")
            copyFont("SourceHanSerifSC-SemiBold", dest: "_reader_font_serif_semibold.otf")
            do {
                try fullHTML.data(using: .utf8)?.write(to: htmlURL)
                webView.loadFileURL(htmlURL, allowingReadAccessTo: contentDir)
            } catch {
                // Fallback: inline load (images may not resolve, but text will).
                webView.loadHTMLString(fullHTML, baseURL: contentDir)
            }
        }

        /// Rewrites `<img src>` / SVG `<image xlink:href>` paths so they point at the
        /// flattened resource files extracted into the content directory. Refs are
        /// resolved against `chapterDir` (the chapter's original folder) so a relative
        /// path maps to the EXACT flattened filename; a series of looser fallbacks
        /// (bare-flatten, basename, `_basename` suffix) keeps older libraries working.
        private func rewriteResourceRefs(_ html: String, availableFiles: [String], chapterDir: String, contentDir: URL) -> String {
            guard !availableFiles.isEmpty else { return html }

            var byFullName: [String: String] = [:]     // "oebps_images_foo.png" -> actual
            var byBasename: [String: String] = [:]      // "foo.png" -> actual
            for f in availableFiles {
                byFullName[f.lowercased()] = f
                let logicalBase = (f.split(separator: "_").last.map(String.init) ?? f).lowercased()
                byBasename[logicalBase] = f
            }

            // Resolve a (possibly relative) ref against the chapter dir into the
            // flattened full-path key, e.g. chapterDir "OEBPS/Text" + "../Images/x.png"
            // -> "oebps_images_x.png".
            func resolvedKey(_ ref: String) -> String {
                var comps = chapterDir.isEmpty ? [] : chapterDir.split(separator: "/").map(String.init)
                for part in ref.split(separator: "/").map(String.init) {
                    if part == "." || part.isEmpty { continue }
                    if part == ".." { if !comps.isEmpty { comps.removeLast() }; continue }
                    comps.append(part)
                }
                return comps.joined(separator: "_").lowercased()
            }

            func map(_ rawValue: String) -> String? {
                // Drop #fragment and percent-decode (files on disk are stored decoded).
                var value = rawValue
                if let h = value.firstIndex(of: "#") { value = String(value[..<h]) }
                value = value.removingPercentEncoding ?? value

                // 1. Exact: resolve against the chapter dir, match the full flattened path.
                if let hit = byFullName[resolvedKey(value)] { return hit }

                // 2. Flatten the ref alone (strip ./ and ../) and match the full path.
                var v = value.replacingOccurrences(of: "./", with: "")
                while v.hasPrefix("../") { v.removeFirst(3) }
                if let hit = byFullName[v.replacingOccurrences(of: "/", with: "_").lowercased()] { return hit }

                // 3. Basename fallbacks (last resort — can be ambiguous across folders).
                let base = (value as NSString).lastPathComponent.lowercased()
                if let hit = byFullName[base] { return hit }          // resource at root
                if let hit = byBasename[base] { return hit }          // logical basename
                return availableFiles.first { $0.lowercased().hasSuffix("_" + base) }
            }

            let pattern = #"(xlink:href|src|href)\s*=\s*(["'])([^"'>]*\.(?:png|jpe?g|gif|svg|webp|bmp))\2"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return html
            }

            let ns = html as NSString
            var result = ""
            var cursor = 0
            for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let attr = ns.substring(with: m.range(at: 1))
                let quote = ns.substring(with: m.range(at: 2))
                let value = ns.substring(with: m.range(at: 3))

                result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
                if let mapped = map(value) {
                    // Inline the image as a base64 data URI. This makes rendering
                    // independent of file-URL access scoping — once the file is on
                    // disk it WILL display. Large images (or once the budget is spent)
                    // fall back to a percent-encoded relative file reference.
                    let fileURL = contentDir.appendingPathComponent(mapped)
                    if imageInlineBudget > 0,
                       let data = try? Data(contentsOf: fileURL),
                       data.count <= 5_000_000 {
                        imageInlineBudget -= data.count
                        let ext = (mapped as NSString).pathExtension.lowercased()
                        result += "\(attr)=\(quote)data:\(Self.mimeType(for: ext));base64,\(data.base64EncodedString())\(quote)"
                    } else {
                        let encoded = mapped.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mapped
                        result += "\(attr)=\(quote)\(encoded)\(quote)"
                    }
                } else {
                    result += ns.substring(with: m.range)   // no match — leave as-is
                }
                cursor = m.range.location + m.range.length
            }
            result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            return result
        }

        /// MIME type for a base64 image data URI.
        private static func mimeType(for ext: String) -> String {
            switch ext {
            case "png":          return "image/png"
            case "jpg", "jpeg":  return "image/jpeg"
            case "gif":          return "image/gif"
            case "svg":          return "image/svg+xml"
            case "webp":         return "image/webp"
            case "bmp":          return "image/bmp"
            default:             return "application/octet-stream"
            }
        }

        private func getContentDirectory(book: Book) -> URL {
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("Extracted/\(book.filePath)")
        }

        private func extractBodyContent(_ html: String) -> String {
            var content = html

            // Extract <body>…</body> content if present (XHTML/HTML documents)
            if let bodyStart = content.range(of: "<body[^>]*>", options: [.regularExpression, .caseInsensitive]),
               let bodyEnd = content.range(of: "</body>", options: .caseInsensitive) {
                content = String(content[bodyStart.upperBound..<bodyEnd.lowerBound])
            }

            // Remove script tags
            let scriptPattern = #"<script[^>]*>.*?</script>"#
            if let regex = try? NSRegularExpression(
                pattern: scriptPattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                let range = NSRange(content.startIndex..., in: content)
                content = regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
            }

            return content
        }

        private func chapterTitleForCurrentChunk(book: Book, index: Int) -> String {
            if index < book.chapters.count {
                return book.chapters[index].title
            }
            return book.title
        }

        // MARK: - Build HTML
        private func buildReaderHTML(content: String, settings: ReadingSettings, title: String, chapterTitle: String, viewportSize: CGSize, initialPage: Int) -> String {
            let bgColor = settings.theme.bgColor
            let textColor = settings.theme.textColor
            let fontCSS = settings.fontFamily.cssName
            let fontSize = settings.fontSize
            let lineHeight = fontSize * settings.lineSpacing
            let marginH = settings.marginHorizontal
            let marginV = settings.marginVertical
            let textAlign = settings.textAlignment.cssValue
            let paraSpacing = settings.paragraphSpacing
            let initialColWidth = max(1, viewportSize.width - marginH * 2)
            let colGap = marginH * 2

            // Build the defaults as a JSON object so values that contain quotes
            // (e.g. the font-family CSS: ...'San Francisco'...) are safely escaped.
            // Injecting these raw into single-quoted JS strings would break the
            // entire <script> with a syntax error.
            let defaultsDict: [String: Any] = [
                "fontSize": fontSize,
                "fontFamilyCSS": fontCSS,
                "bgColor": bgColor,
                "textColor": textColor,
                "lineSpacing": settings.lineSpacing,
                "textAlign": textAlign,
                "marginH": marginH,
                "marginV": marginV,
                "paraSpacing": paraSpacing,
            ]
            let defaultsJSON = (try? JSONSerialization.data(withJSONObject: defaultsDict))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
            <style>
            /* Make the bundled serif font visible to the WebView even when loaded
               via loadFileURL (which grants access to the content directory, not the
               app bundle). The font file itself is copied to the content directory by
               loadContent so the relative path resolves. */
            /* Register the bundled serif font for the WebView. local() picks it up
               from UIAppFonts registration; the url() fallback uses the copy placed
               in the content directory by loadContent. */
            @font-face {
                font-family: 'Source Han Serif SC';
                src: local('Source Han Serif SC'),
                     url('_reader_font_serif.otf') format('opentype');
                font-weight: 400;
                font-display: swap;
            }
            @font-face {
                font-family: 'Source Han Serif SC';
                src: local('Source Han Serif SC'),
                     url('_reader_font_serif_semibold.otf') format('opentype');
                font-weight: 600;
                font-display: swap;
            }
            * { margin: 0; padding: 0; box-sizing: border-box; }

            html, body {
                width: 100%;
                height: 100%;
                overflow: hidden;
                background: \(bgColor);
                color: \(textColor);
                font-family: \(fontCSS);
                font-size: \(fontSize)px;
                line-height: \(lineHeight)px;
                text-align: \(textAlign);
                -webkit-text-size-adjust: 100%;
                -webkit-tap-highlight-color: transparent;
                -webkit-user-select: none;
                user-select: none;
            }

            /* The paged container. box-sizing:border-box keeps the padding INSIDE
               the viewport width, so each column == one screen exactly.
               column-width and column-gap are refined in JS (measure()). */
            #reader-container {
                width: 100%;
                height: 100%;
                box-sizing: border-box;
                /* Add the device safe-area insets on top of the reading margins so
                   text clears the Dynamic Island / notch and the home indicator.
                   viewport-fit=cover (in the viewport meta) makes env() available;
                   these resolve to a constant px per orientation, so toggling the
                   controls does NOT change them and the page never reflows. The
                   reading background still fills edge-to-edge behind the island. */
                padding-top: calc(\(marginV)px + env(safe-area-inset-top));
                padding-right: calc(\(marginH)px + env(safe-area-inset-right));
                padding-bottom: calc(\(marginV)px + env(safe-area-inset-bottom));
                padding-left: calc(\(marginH)px + env(safe-area-inset-left));
                overflow: hidden;
                column-width: \(initialColWidth)px;
                column-gap: \(colGap)px;
                column-fill: auto;
                -webkit-column-width: \(initialColWidth)px;
                -webkit-column-gap: \(colGap)px;
                -webkit-column-fill: auto;
            }

            /* Each chapter starts on a fresh page (like Apple Books). */
            .content-chunk {
                break-before: column;
                -webkit-column-break-before: always;
            }
            .content-chunk:first-child {
                break-before: avoid;
                -webkit-column-break-before: avoid;
            }

            p {
                margin-bottom: \(paraSpacing)px;
                text-indent: 2em;
                orphans: 2;
                widows: 2;
            }

            h1, h2, h3, h4, h5, h6 {
                margin: 20px 0 12px 0;
                font-weight: 700;
                line-height: 1.3;
                text-indent: 0;
                text-align: left;
                break-inside: avoid;
                -webkit-column-break-inside: avoid;
            }

            h1 { font-size: 1.6em; }
            h2 { font-size: 1.4em; }
            h3 { font-size: 1.2em; }

            img, svg {
                max-width: 100%;
                max-height: 85vh;
                height: auto;
                display: block;
                margin: 12px auto;
            }

            blockquote {
                margin: 16px 0;
                padding: 8px 16px;
                border-left: 3px solid \(textColor)44;
                opacity: 0.85;
            }

            hr { margin: 20px 0; border: none; border-top: 1px solid \(textColor)22; }

            a { color: \(textColor); text-decoration: underline; }
            </style>
            <script>
            var DEFAULTS = \(defaultsJSON);
            var currentPage = 0;
            var totalPages = 1;
            var pageStep = 1;
            var chapterMetrics = [];

            function readerContainer() {
                return document.getElementById('reader-container');
            }

            // Measure the container and set column-width = content width and
            // column-gap = combined side margins, so one page == container.clientWidth.
            function measure() {
                var c = readerContainer();
                if (!c) return;
                var cs = getComputedStyle(c);
                var padL = parseFloat(cs.paddingLeft) || 0;
                var padR = parseFloat(cs.paddingRight) || 0;
                var contentWidth = c.clientWidth - padL - padR;
                if (contentWidth < 1) { contentWidth = c.clientWidth; }
                c.style.columnWidth = contentWidth + 'px';
                c.style.webkitColumnWidth = contentWidth + 'px';
                c.style.columnGap = (padL + padR) + 'px';
                c.style.webkitColumnGap = (padL + padR) + 'px';
                pageStep = c.clientWidth;
                if (pageStep < 1) { pageStep = 1; }
                var sw = c.scrollWidth; // forces synchronous reflow
                totalPages = Math.max(1, Math.round(sw / pageStep));
                if (currentPage > totalPages - 1) { currentPage = totalPages - 1; }
                if (currentPage < 0) { currentPage = 0; }
                computeChapterMetrics();
            }

            function applyScroll() {
                var c = readerContainer();
                if (!c) return;
                c.scrollLeft = currentPage * pageStep;
            }

            function activeChunkIndex() {
                if (!chapterMetrics.length) { return null; }
                for (var i = 0; i < chapterMetrics.length; i++) {
                    var start = chapterMetrics[i].pageOffset;
                    var count = Math.max(1, chapterMetrics[i].pageCount || 1);
                    if (currentPage >= start && currentPage < start + count) {
                        return i;
                    }
                }
                return chapterMetrics.length - 1;
            }

            function computeChapterMetrics() {
                chapterMetrics = [];
                var chunks = document.querySelectorAll('.content-chunk');
                if (!chunks.length) { return; }
                for (var i = 0; i < chunks.length; i++) {
                    var chunk = chunks[i];
                    var startPage = Math.max(0, Math.round((chunk.offsetLeft || 0) / pageStep));
                    chapterMetrics.push({ pageOffset: startPage, pageCount: 1 });
                }
                for (var j = 0; j < chapterMetrics.length; j++) {
                    var nextStart = (j + 1 < chapterMetrics.length) ? chapterMetrics[j + 1].pageOffset : totalPages;
                    chapterMetrics[j].pageCount = Math.max(1, nextStart - chapterMetrics[j].pageOffset);
                }
            }

            function postChapterMetrics() {
                try {
                    window.webkit.messageHandlers.pageHandler.postMessage({
                        type: 'chapterMetrics',
                        chapters: chapterMetrics
                    });
                } catch (e) {}
            }

            function postPage() {
                try {
                    window.webkit.messageHandlers.pageHandler.postMessage({
                        type: 'pageChange',
                        currentPage: currentPage,
                        totalPages: totalPages,
                        activeChapterIndex: activeChunkIndex()
                    });
                } catch (e) {}
            }

            function goToPage(pageNum) {
                currentPage = Math.max(0, Math.min(pageNum, totalPages - 1));
                applyScroll();
                postPage();
            }

            function nextPage() { goToPage(currentPage + 1); }
            function previousPage() { goToPage(currentPage - 1); }

            function recalculatePages() {
                measure();
                applyScroll();
                postChapterMetrics();
                postPage();
            }

            function applySettings(settingsJSON) {
                var s;
                try { s = JSON.parse(settingsJSON); } catch (e) { return; }
                var old = document.getElementById('reader-dynamic-styles');
                if (old) { old.remove(); }
                var style = document.createElement('style');
                style.id = 'reader-dynamic-styles';
                var fs = s.fontSize || DEFAULTS.fontSize;
                var ls = s.lineSpacing || DEFAULTS.lineSpacing;
                var mV = (s.marginV != null) ? s.marginV : DEFAULTS.marginV;
                var mH = (s.marginH != null) ? s.marginH : DEFAULTS.marginH;
                var pSpace = (s.paraSpacing != null) ? s.paraSpacing : DEFAULTS.paraSpacing;
                style.textContent =
                    'html, body {' +
                    'background: ' + (s.bgColor || DEFAULTS.bgColor) + ';' +
                    'color: ' + (s.textColor || DEFAULTS.textColor) + ';' +
                    'font-family: ' + (s.fontFamilyCSS || DEFAULTS.fontFamilyCSS) + ';' +
                    'font-size: ' + fs + 'px;' +
                    'line-height: ' + (fs * ls) + 'px;' +
                    'text-align: ' + (s.textAlign || DEFAULTS.textAlign) + ';' +
                    '}' +
                    '#reader-container {' +
                    'padding-top: calc(' + mV + 'px + env(safe-area-inset-top));' +
                    'padding-right: calc(' + mH + 'px + env(safe-area-inset-right));' +
                    'padding-bottom: calc(' + mV + 'px + env(safe-area-inset-bottom));' +
                    'padding-left: calc(' + mH + 'px + env(safe-area-inset-left));' +
                    '}' +
                    'p { margin-bottom: ' + pSpace + 'px; }';
                document.head.appendChild(style);
                // Let layout settle across two frames, then re-paginate + restore page.
                requestAnimationFrame(function() {
                    requestAnimationFrame(function() {
                        recalculatePages();
                    });
                });
            }

            function bookInit() {
                measure();
                currentPage = Math.max(0, Math.min(
                    \(initialPage), totalPages - 1));
                applyScroll();
                postChapterMetrics();
                postPage();
            }

            if (document.readyState === 'complete' || document.readyState === 'interactive') {
                setTimeout(bookInit, 0);
            } else {
                window.addEventListener('load', bookInit);
            }

            window.addEventListener('resize', function() {
                setTimeout(recalculatePages, 200);
            });
            </script>
            </head>
            <body>
            <div id="reader-container">
            \(content)
            </div>
            </body>
            </html>
            """
        }


        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Re-paginate once the WebView reports load finished, then again a
            // bit later to catch layout that settles after images/fonts resolve.
            // recalculatePages() posts the page/total back via the message handler.
            let recalc: () -> Void = { webView.evaluateJavaScript("recalculatePages();", completionHandler: nil) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: recalc)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: recalc)
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "pageHandler",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            if type == "pageChange" {
                if let page = body["currentPage"] as? Int {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.pendingPage = page  // prevent double-navigation in updateUIView
                        self.parent.currentPage = page
                        self.currentPageBinding?.wrappedValue = page
                    }
                }
                if let total = body["totalPages"] as? Int {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.totalPages = total
                        self?.totalPagesBinding?.wrappedValue = total
                    }
                }
                if let activeIndex = body["activeChapterIndex"] as? Int {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.activeChapterIndexBinding?.wrappedValue = activeIndex
                        if let titleBinding = self.chapterTitleBinding,
                           activeIndex >= 0,
                           activeIndex < self.parent.book.chapters.count {
                            titleBinding.wrappedValue = self.parent.book.chapters[activeIndex].title
                        }
                    }
                }
            } else if type == "chapterMetrics" {
                guard let chapters = body["chapters"] as? [[String: Any]] else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let metrics = chapters.map { chapter in
                        ChapterMetric(
                            pageOffset: chapter["pageOffset"] as? Int ?? 0,
                            pageCount: chapter["pageCount"] as? Int ?? 1
                        )
                    }
                    self.chapterMetricsBinding?.wrappedValue = metrics
                }
            }
        }
    }
}

// MARK: - Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
