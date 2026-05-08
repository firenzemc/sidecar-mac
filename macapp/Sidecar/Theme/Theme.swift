import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Hashable {
    case grid       // 默认：深灰底 + 网格背景 + 青色 accent
    case phosphor   // 近黑底 + 单一品红/绿色 accent，CRT 微光
    case glass      // macOS 原生 material + accent 描边

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .grid:     return "Grid"
        case .phosphor: return "Phosphor"
        case .glass:    return "Glass"
        }
    }

    var accent: Color {
        switch self {
        case .grid:     return Color(red: 0.30, green: 0.85, blue: 0.95)   // cyan
        case .phosphor: return Color(red: 0.35, green: 0.95, blue: 0.55)   // CRT green
        case .glass:    return Color.accentColor
        }
    }

    var background: Color {
        switch self {
        case .grid:     return Color(red: 0.07, green: 0.08, blue: 0.10)
        case .phosphor: return Color(red: 0.04, green: 0.04, blue: 0.05)
        case .glass:    return Color.clear
        }
    }

    var cardBackground: Color {
        switch self {
        case .grid:     return Color(red: 0.10, green: 0.12, blue: 0.15).opacity(0.85)
        case .phosphor: return Color(red: 0.06, green: 0.07, blue: 0.06).opacity(0.90)
        case .glass:    return Color(nsColor: .windowBackgroundColor).opacity(0.6)
        }
    }

    var cardBorder: Color { accent.opacity(0.35) }
    var dimText: Color    { Color.white.opacity(0.55) }
    var brightText: Color { Color.white.opacity(0.92) }

    /// Whether to render the dotted-grid background overlay behind the content.
    var showsGridBackdrop: Bool { self == .grid }
}

// MARK: - Tokens

enum Tokens {
    static let cardCorner: CGFloat = 12
    static let gridSpacing: CGFloat = 12
    static let monoDigits = Font.system(.body, design: .monospaced).weight(.medium)
    static let monoSmall  = Font.system(.caption, design: .monospaced)
}
