import SwiftUI

/// Primary (accent gradient), Secondary (surface + stroke), Ghost (text) and
/// Destructive buttons, all with spring press feedback and a loading state.
struct MarqueeButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, destructive }

    @Environment(\.theme) private var theme
    @Environment(\.motion) private var motion
    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary
    var isLoading = false
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .opacity(isLoading ? 0 : 1)
            .overlay { if isLoading { ProgressView().tint(foreground) } }
            .padding(.horizontal, kind == .ghost ? Space.xs : Space.l)
            .padding(.vertical, Space.s)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Touch.minimum)
            .foregroundStyle(foreground)
            .background { background }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && motion.allowsMovement ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(motion.animation(MotionPolicy.pressSpring), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return theme.onAccent
        case .secondary: return theme.textPrimary
        case .ghost: return theme.accent
        case .destructive: return theme.danger
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary:
            Capsule().fill(theme.accentGradient)
        case .secondary:
            Capsule().fill(theme.surface2).overlay(Capsule().strokeBorder(theme.strokeStrong, lineWidth: 1))
        case .ghost:
            Color.clear
        case .destructive:
            Capsule().fill(theme.danger.opacity(0.12)).overlay(Capsule().strokeBorder(theme.danger.opacity(0.35), lineWidth: 1))
        }
    }
}

extension ButtonStyle where Self == MarqueeButtonStyle {
    static var primary: MarqueeButtonStyle { MarqueeButtonStyle(kind: .primary) }
    static var secondary: MarqueeButtonStyle { MarqueeButtonStyle(kind: .secondary) }
    static var ghost: MarqueeButtonStyle { MarqueeButtonStyle(kind: .ghost) }
    static var destructive: MarqueeButtonStyle { MarqueeButtonStyle(kind: .destructive) }
}

/// A capsule filter chip; the selected state uses the accent.
struct FilterChip: View {
    @Environment(\.theme) private var theme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.xs)
                .frame(minHeight: 36)
                .foregroundStyle(isSelected ? theme.onAccent : theme.textPrimary)
                .background {
                    if isSelected {
                        Capsule().fill(theme.accentGradient)
                    } else {
                        Capsule().fill(theme.surface2).overlay(Capsule().strokeBorder(theme.stroke, lineWidth: 1))
                    }
                }
                .frame(minHeight: Touch.minimum)
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// A custom segmented control with a sliding accent pill.
struct SegmentedPicker<Value: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.motion) private var motion
    @Namespace private var pill
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    var identifier: String = "segment"

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    guard !selected else { return }
                    Haptics.selection()
                    withMotion(motion) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(selected ? theme.onAccent : theme.textSecondary)
                        .background {
                            if selected {
                                Capsule().fill(theme.accentGradient).matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: Touch.minimum)
                .accessibilityIdentifier("\(identifier).\(String(describing: option))")
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(theme.surface1, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.stroke, lineWidth: 1))
    }
}

/// Eyebrow, title and an optional "See all".
struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let eyebrow: String
    let title: String
    var seeAll: (() -> Void)?
    var identifier: String = "section"

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(eyebrow)
                Text(title)
                    .font(.sectionTitle(theme.titleDesign))
                    .foregroundStyle(theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: Space.s)
            if let seeAll {
                Button(String(localized: "See all"), action: seeAll)
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("\(identifier).seeAll")
            }
        }
    }
}

/// A tinted rounded square holding a section icon.
struct IconBubble: View {
    @Environment(\.theme) private var theme
    let symbol: String
    var tint: Color?
    var size: CGFloat = 32

    var body: some View {
        let color = tint ?? theme.accent
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
            .accessibilityHidden(true)
    }
}
