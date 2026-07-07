import SwiftUI

struct ThemePalette {
    let rose: Color
    let lavender: Color
    let blush: Color
    let cream: Color
    let deepRose: Color
    let softPurple: Color
    let textPrimary: Color
    let textSecondary: Color
    let cardHighlight: Color
    let searchBackground: Color
    let shadowColor: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [cream, blush, softPurple.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [cardHighlight, blush.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [rose, lavender], startPoint: .leading, endPoint: .trailing)
    }

    static func palette(for scheme: ColorScheme) -> ThemePalette {
        scheme == .dark ? .dark : .light
    }

    static let light = ThemePalette(
        rose: Color(red: 0.91, green: 0.63, blue: 0.75),
        lavender: Color(red: 0.73, green: 0.56, blue: 0.78),
        blush: Color(red: 0.97, green: 0.91, blue: 0.94),
        cream: Color(red: 1.0, green: 0.96, blue: 0.97),
        deepRose: Color(red: 0.72, green: 0.35, blue: 0.52),
        softPurple: Color(red: 0.85, green: 0.78, blue: 0.92),
        textPrimary: Color(red: 0.35, green: 0.22, blue: 0.32),
        textSecondary: Color(red: 0.55, green: 0.42, blue: 0.50),
        cardHighlight: Color.white.opacity(0.95),
        searchBackground: Color.white.opacity(0.9),
        shadowColor: Color(red: 0.91, green: 0.63, blue: 0.75).opacity(0.18)
    )

    static let dark = ThemePalette(
        rose: Color(red: 0.82, green: 0.52, blue: 0.66),
        lavender: Color(red: 0.68, green: 0.50, blue: 0.78),
        blush: Color(red: 0.22, green: 0.16, blue: 0.21),
        cream: Color(red: 0.12, green: 0.09, blue: 0.13),
        deepRose: Color(red: 0.92, green: 0.58, blue: 0.72),
        softPurple: Color(red: 0.28, green: 0.20, blue: 0.32),
        textPrimary: Color(red: 0.96, green: 0.91, blue: 0.94),
        textSecondary: Color(red: 0.72, green: 0.62, blue: 0.68),
        cardHighlight: Color(red: 0.20, green: 0.15, blue: 0.19).opacity(0.95),
        searchBackground: Color(red: 0.18, green: 0.13, blue: 0.17).opacity(0.95),
        shadowColor: Color.black.opacity(0.35)
    )
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.light
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

enum AppTheme {
    static func palette(for scheme: ColorScheme) -> ThemePalette {
        ThemePalette.palette(for: scheme)
    }
}

struct FeminineCardModifier: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .background(palette.cardGradient)
            .cornerRadius(20)
            .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 6)
    }
}

extension View {
    func feminineCard() -> some View {
        modifier(FeminineCardModifier())
    }
}
