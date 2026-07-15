import SwiftUI

// MARK: - Reading Settings
struct ReadingSettings: Equatable, Codable {
    // Font
    var fontSize: CGFloat = 18
    var fontFamily: FontFamily = .system

    // Theme (background/text colors)
    var theme: ReadingTheme = .white

    // Layout
    var lineSpacing: CGFloat = 1.6
    var paragraphSpacing: CGFloat = 12
    var textAlignment: TextAlignment = .justified
    var marginHorizontal: CGFloat = 20
    var marginVertical: CGFloat = 16

    // Page turning
    var pageTurnMode: PageTurnMode = .scroll
    var enableVolumeButtons: Bool = true

    // Brightness (nil = use system brightness)
    var customBrightness: CGFloat? = nil

    // MARK: - Computed
    var lineHeight: CGFloat { fontSize * lineSpacing }

    // MARK: - Defaults
    static let defaultFontSize: CGFloat = 18

    // Clamp font size
    static let minFontSize: CGFloat = 12
    static let maxFontSize: CGFloat = 32
}

// MARK: - Font Family
// NOTE: iOS ships essentially ONE Chinese font family — PingFang SC (苹方). Songti/
// Kaiti SC are macOS-only fonts and are NOT present on iOS or the Simulator (verified
// against the iOS 26.3 runtime font list), so offering them just falls back to PingFang
// and looks identical. Every stack therefore ends in 'PingFang SC' before the generic,
// so Chinese text always has a real glyph source and never renders as tofu boxes — even
// when a Latin-only face (e.g. San Francisco) is chosen. To truly offer 宋体/楷体 like
// Apple Books, an open-source CJK font (e.g. Noto Serif SC, OFL) would have to be bundled.
enum FontFamily: String, CaseIterable, Codable {
    case system        = "San Francisco"
    case pingfang      = "苹方"
    case georgia       = "Georgia"
    case timesNewRoman = "Times New Roman"
    case palatino      = "Palatino"
    case helvetica     = "Helvetica"
    case courier       = "Courier"

    var cssName: String {
        switch self {
        case .system:        return "-apple-system, 'PingFang SC', sans-serif"
        case .pingfang:      return "'PingFang SC', sans-serif"
        case .georgia:       return "Georgia, 'PingFang SC', serif"
        case .timesNewRoman: return "'Times New Roman', 'PingFang SC', serif"
        case .palatino:      return "Palatino, 'PingFang SC', serif"
        case .helvetica:     return "'Helvetica Neue', Helvetica, 'PingFang SC', sans-serif"
        case .courier:       return "'Courier New', Courier, 'PingFang SC', monospace"
        }
    }

    var displayName: String { rawValue }

    /// Real iOS font family name for the SwiftUI picker chip preview.
    var uiFontName: String {
        switch self {
        case .system:        return "PingFang SC"
        case .pingfang:      return "PingFang SC"
        case .georgia:       return "Georgia"
        case .timesNewRoman: return "Times New Roman"
        case .palatino:      return "Palatino"
        case .helvetica:     return "Helvetica Neue"
        case .courier:       return "Courier New"
        }
    }

    /// Sample glyphs shown on the picker chip.
    var sample: String {
        switch self {
        case .pingfang: return "字"
        case .system:   return "字Aa"
        default:        return "Aa"
        }
    }

    var isSerif: Bool {
        switch self {
        case .georgia, .timesNewRoman, .palatino: return true
        default: return false
        }
    }
}

// MARK: - Reading Theme
enum ReadingTheme: String, CaseIterable, Codable {
    case white = "白色"
    case sepia = "暖黄"
    case dark  = "暗黑"
    case green = "护眼绿"

    var bgColor: String {
        switch self {
        case .white: return "#FEFEFE"
        case .sepia: return "#F5EFDF"
        case .dark:  return "#1A1A1E"
        case .green: return "#E2EFDA"
        }
    }

    var textColor: String {
        switch self {
        case .white: return "#1C1C1E"
        case .sepia: return "#4A3520"
        case .dark:  return "#D1D1D6"
        case .green: return "#2C3E20"
        }
    }

    var accentColor: Color {
        switch self {
        case .white: return .accentColor
        case .sepia: return .orange
        case .dark:  return .orange
        case .green: return Color(red: 0.3, green: 0.5, blue: 0.2)
        }
    }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .white: return "sun.max.fill"
        case .sepia: return "mug.fill"
        case .dark:  return "moon.fill"
        case .green: return "leaf.fill"
        }
    }
}

// MARK: - Page Turn Mode
enum PageTurnMode: String, CaseIterable, Codable {
    case scroll = "滚动"
    case curl   = "仿真翻页"

    var displayName: String { rawValue }
}

// MARK: - Text Alignment
enum TextAlignment: String, CaseIterable, Codable {
    case justified = "两端对齐"
    case left      = "左对齐"

    var displayName: String { rawValue }

    var cssValue: String {
        switch self {
        case .justified: return "justify"
        case .left:      return "left"
        }
    }
}
