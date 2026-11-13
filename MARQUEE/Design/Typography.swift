import SwiftUI

/// Type roles from §5.10. Text styles keep Dynamic Type working everywhere;
/// the wordmark is the only fixed size.
extension Font {
    static func screenTitle(_ design: Font.Design = .default) -> Font { .system(.largeTitle, design: design).weight(.bold) }
    static func sectionTitle(_ design: Font.Design = .default) -> Font { .system(.title3, design: design).weight(.semibold) }
    static func cardTitle(_ design: Font.Design = .default) -> Font { .system(.headline, design: design) }
    static func bodyText(_ design: Font.Design) -> Font { .system(.body, design: design) }
    static let meta = Font.subheadline
    static let captionMedium = Font.caption.weight(.medium)
    static let eyebrow = Font.caption2.weight(.semibold)
}

/// Small uppercase label above sections and stats.
struct Eyebrow: View {
    @Environment(\.theme) private var theme
    let text: String
    var color: Color?

    init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.eyebrow)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color ?? theme.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Condensed, monospaced digits for every number (§5.3), scaled with Dynamic Type.
struct NumberText: View {
    enum Size { case hero, stat, inline }

    let text: String
    var size: Size = .stat
    @ScaledMetric(relativeTo: .largeTitle) private var hero: CGFloat = 50
    @ScaledMetric(relativeTo: .title2) private var stat: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var inline: CGFloat = 17

    var body: some View {
        Text(text)
            .font(.system(size: pointSize, weight: .bold).width(.condensed).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var pointSize: CGFloat {
        switch size {
        case .hero: return hero
        case .stat: return stat
        case .inline: return inline
        }
    }
}

/// The heavy, expanded MARQUEE wordmark. The only fixed font size in the app.
struct Wordmark: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 22

    var body: some View {
        Text("MARQUEE")
            .font(.system(size: size, weight: .black).width(.expanded))
            .tracking(size * 0.08)
            .foregroundStyle(theme.accentGradient)
            .accessibilityLabel("MARQUEE")
    }
}
