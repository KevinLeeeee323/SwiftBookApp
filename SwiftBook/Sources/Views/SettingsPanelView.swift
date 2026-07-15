import SwiftUI

// MARK: - Reading Settings Panel
struct SettingsPanelView: View {
    @Binding var settings: ReadingSettings
    @Binding var isPresented: Bool
    @Binding var isControlsShown: Bool

    @State private var brightness: CGFloat

    init(settings: Binding<ReadingSettings>, isPresented: Binding<Bool>, isControlsShown: Binding<Bool>) {
        self._settings = settings
        self._isPresented = isPresented
        self._isControlsShown = isControlsShown
        self._brightness = State(initialValue: CGFloat(UIScreen.main.brightness))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Spacer()

            VStack(spacing: 0) {
                // Handle
                handleBar
                    .padding(.top, 8)

                // Title
                HStack {
                    Text("阅读设置")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                ScrollView {
                    VStack(spacing: 22) {
                        // Font size
                        fontSizeSection
                        Divider().padding(.horizontal, 24)

                        // Font family
                        fontFamilySection
                        Divider().padding(.horizontal, 24)

                        // Theme
                        themeSection
                        Divider().padding(.horizontal, 24)

                        // Line spacing
                        lineSpacingSection
                        Divider().padding(.horizontal, 24)

                        // Text alignment
                        textAlignmentSection
                        Divider().padding(.horizontal, 24)

                        // Page turn mode
                        pageTurnModeSection
                        Divider().padding(.horizontal, 24)

                        // Brightness
                        brightnessSection
                        Divider().padding(.horizontal, 24)

                        // Volume buttons toggle
                        volumeButtonsSection
                    }
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: -6)
            )
            .frame(maxHeight: UIScreen.main.bounds.height * 0.60)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.clear)
        .onTapGesture {
            withAnimation { isPresented = false }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            brightness = CGFloat(UIScreen.main.brightness)
        }
        .onChange(of: brightness) { newValue in
            UIScreen.main.brightness = newValue
        }
    }

    // MARK: - Handle Bar
    private var handleBar: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
    }

    // MARK: - Font Size
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("字号")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(settings.fontSize))pt")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.primary)
            }

            HStack(spacing: 14) {
                Text("A")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(
                    value: $settings.fontSize,
                    in: ReadingSettings.minFontSize...ReadingSettings.maxFontSize,
                    step: 1
                )
                .tint(.accentColor)

                Text("A")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }

            // Preset buttons
            HStack(spacing: 8) {
                ForEach([14.0, 18.0, 22.0, 26.0, 30.0], id: \.self) { size in
                    Button {
                        withAnimation { settings.fontSize = CGFloat(size) }
                    } label: {
                        Text("\(Int(size))")
                            .font(.caption)
                            .fontWeight(settings.fontSize == CGFloat(size) ? .bold : .regular)
                            .foregroundColor(settings.fontSize == CGFloat(size) ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(settings.fontSize == CGFloat(size) ? Color.accentColor : Color.secondary.opacity(0.12))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Font Family
    private var fontFamilySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("字体")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FontFamily.allCases, id: \.self) { font in
                        Button {
                            withAnimation { settings.fontFamily = font }
                        } label: {
                            VStack(spacing: 6) {
                                Text(font.sample)
                                    .font(.custom(font.uiFontName, size: 20))
                                    .frame(width: 52, height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(settings.fontFamily == font ? Color.accentColor : Color.secondary.opacity(0.1))
                                    )
                                    .foregroundColor(settings.fontFamily == font ? .white : .primary)

                                Text(font.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(settings.fontFamily == font ? .accentColor : .secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, -24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Theme
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主题")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(ReadingTheme.allCases, id: \.self) { theme in
                    Button {
                        withAnimation { settings.theme = theme }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: theme.bgColor))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(settings.theme == theme ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                                Image(systemName: theme.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: theme.textColor))
                            }

                            Text(theme.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(settings.theme == theme ? .accentColor : .secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Line Spacing
    private var lineSpacingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("行间距")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1fx", settings.lineSpacing))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.primary)
            }

            Slider(value: $settings.lineSpacing, in: 1.0...2.8, step: 0.1)
                .tint(.accentColor)

            HStack {
                Text("紧凑")
                    .font(.caption2)
                Spacer()
                Text("宽松")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Text Alignment
    private var textAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("对齐方式")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(TextAlignment.allCases, id: \.self) { alignment in
                    Button {
                        withAnimation { settings.textAlignment = alignment }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: alignment == .justified ? "text.alignleft" : "text.alignleft")
                                .font(.caption)

                            Text(alignment.displayName)
                                .font(.subheadline)
                        }
                        .foregroundColor(settings.textAlignment == alignment ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(settings.textAlignment == alignment ? Color.accentColor : Color.secondary.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page Turn Mode
    private var pageTurnModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("翻页方式")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(PageTurnMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation { settings.pageTurnMode = mode }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .scroll ? "scroll" : "book.pages")
                                .font(.caption)
                            Text(mode.displayName)
                                .font(.subheadline)
                        }
                        .foregroundColor(settings.pageTurnMode == mode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(settings.pageTurnMode == mode ? Color.accentColor : Color.secondary.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Brightness
    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("屏幕亮度")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(brightness * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.primary)
            }

            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $brightness, in: 0.05...1.0, step: 0.05)
                    .tint(.accentColor)

                Image(systemName: "sun.max")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Volume Buttons
    private var volumeButtonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("音量键翻页")
                        .font(.subheadline)
                    Text("使用设备的音量键进行翻页")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $settings.enableVolumeButtons)
                    .tint(.accentColor)
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}
