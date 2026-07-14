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
enum FontFamily: String, CaseIterable, Codable {
    case system       = "San Francisco"
    case georgia      = "Georgia"
    case timesNewRoman = "Times New Roman"
    case palatino     = "Palatino"
    case helvetica    = "Helvetica"
    case courier      = "Courier"

    var cssName: String {
        switch self {
        case .system:        return "-apple-system, BlinkMacSystemFont, 'San Francisco', sans-serif"
        case .georgia:       return "'Georgia', serif"
        case .timesNewRoman: return "'Times New Roman', Times, serif"
        case .palatino:      return "'Palatino', 'Palatino Linotype', serif"
        case .helvetica:     return "'Helvetica Neue', Helvetica, Arial, sans-serif"
        case .courier:       return "'Courier New', Courier, monospace"
        }
    }

    var displayName: String { rawValue }

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
