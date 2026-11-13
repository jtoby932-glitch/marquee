import SwiftUI
import UIKit

extension RGB {
    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

/// The active Look plus the user's appearance settings, as SwiftUI values.
/// Read it with `@Environment(\.theme)`; never hard-code a colour in a view.
struct Theme: Equatable {
    var look: Look
    var posterRadius: CGFloat = Radius.poster
    var reduceTransparency = false

    var background: Color { look.background.color }
    var surface1: Color { look.surface1.color }
    var surface2: Color { look.surface2.color }
    var surface3: Color { look.surface3.color }
    var textPrimary: Color { look.textPrimary.color }
    var textSecondary: Color { look.textSecondary.color }
    var textTertiary: Color { look.textTertiary.color }
    var accent: Color { look.accent.color }
    var onAccent: Color { look.onAccent.color }
    var success: Color { look.success.color }
    var warning: Color { look.warning.color }
    var danger: Color { look.danger.color }
    var star: Color { look.star.color }

    /// Hairline strokes are the primary text colour at 8% and 14%.
    var stroke: Color { textPrimary.opacity(0.08) }
    var strokeStrong: Color { textPrimary.opacity(0.14) }
    var shimmer: Color { textPrimary.opacity(look.isLight ? 0.06 : 0.07) }
    /// Darkens artwork so text over it stays readable.
    var scrim: LinearGradient {
        LinearGradient(colors: [.black.opacity(0), .black.opacity(0.35), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: look.accentGradient.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var chartPalette: [Color] { look.chartPalette.map(\.color) }

    var colorScheme: ColorScheme { look.isLight ? .light : .dark }

    /// Titles and reviews use New York in Bookshop and Paper, SF Pro elsewhere.
    var titleDesign: Font.Design { look.usesSerif ? .serif : .default }

    static let cinema = Theme(look: .cinema)
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.cinema
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// A card surface: fill plus hairline stroke, no shadow (§5.4).
struct CardSurface: ViewModifier {
    @Environment(\.theme) private var theme
    var radius: CGFloat = Radius.card
    var level: Int = 1

    func body(content: Content) -> some View {
        content
            .background(level == 2 ? theme.surface2 : theme.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(theme.stroke, lineWidth: 1))
    }
}

/// Only floating elements get a shadow: 40% black, radius 16, y 8.
struct FloatingShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

/// A blurred material, or a solid surface when Reduce Transparency is on.
struct GlassBackground<S: Shape>: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var shape: S

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(theme.surface2, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .background(theme.surface1.opacity(0.55), in: shape)
        }
    }
}

extension View {
    func card(radius: CGFloat = Radius.card, level: Int = 1) -> some View { modifier(CardSurface(radius: radius, level: level)) }
    func floatingShadow() -> some View { modifier(FloatingShadow()) }
    func glass<S: Shape>(_ shape: S) -> some View { modifier(GlassBackground(shape: shape)) }
}
