import SwiftUI

enum AnimationLevel: String, CaseIterable, Identifiable, Codable {
    case full, reduced, off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return String(localized: "Full")
        case .reduced: return String(localized: "Reduced")
        case .off: return String(localized: "Off")
        }
    }
}

/// Combines the in-app animation level with iOS Reduce Motion, which always
/// forces at least Reduced (§5.5).
struct MotionPolicy: Equatable {
    let level: AnimationLevel

    init(level: AnimationLevel, systemReduceMotion: Bool = false) {
        self.level = (systemReduceMotion && level == .full) ? .reduced : level
    }

    static let full = MotionPolicy(level: .full)

    var allowsMovement: Bool { level == .full }
    var allowsAnimation: Bool { level != .off }

    static let standardSpring = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let pressSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let reducedFade = Animation.easeInOut(duration: 0.18)

    /// The spring at Full, a short fade at Reduced, nothing at Off.
    func animation(_ full: Animation = MotionPolicy.standardSpring) -> Animation? {
        switch level {
        case .full: return full
        case .reduced: return MotionPolicy.reducedFade
        case .off: return nil
        }
    }

    /// Staggered appear delay: 0.03 s per index, capped at 0.3 s.
    static func staggerDelay(index: Int) -> Double { min(0.3, Double(max(0, index)) * 0.03) }

    /// Image fade-in: 0.2 s, instant when motion is reduced or off.
    var imageFade: Animation? { allowsMovement ? .easeOut(duration: 0.2) : nil }
}

private struct MotionKey: EnvironmentKey {
    static let defaultValue = MotionPolicy.full
}

extension EnvironmentValues {
    var motion: MotionPolicy {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

/// Runs `body` with the policy's animation, or without animation when Off.
func withMotion(_ policy: MotionPolicy, _ full: Animation = MotionPolicy.standardSpring, _ body: () -> Void) {
    if let animation = policy.animation(full) {
        withAnimation(animation, body)
    } else {
        body()
    }
}

/// Fades and lifts content 8 pt once per screen load, staggered. Never blocks touches.
struct AppearModifier: ViewModifier {
    let index: Int
    @Environment(\.motion) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !motion.allowsAnimation ? 1 : 0)
            .offset(y: shown || !motion.allowsMovement ? 0 : 8)
            .onAppear {
                guard !shown else { return }
                if let animation = motion.animation() {
                    withAnimation(animation.delay(MotionPolicy.staggerDelay(index: index))) { shown = true }
                } else {
                    shown = true
                }
            }
    }
}

/// Spring press feedback: scale to 0.97 with a slight brightness change.
struct PressableStyle: ButtonStyle {
    @Environment(\.motion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && motion.allowsMovement ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(motion.animation(MotionPolicy.pressSpring), value: configuration.isPressed)
    }
}

/// A soft band of light for skeletons and celebrations; static when motion is reduced.
struct ShimmerModifier: ViewModifier {
    var active: Bool
    @Environment(\.motion) private var motion
    @Environment(\.theme) private var theme
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active && motion.allowsMovement {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, theme.textPrimary.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.7)
                            .offset(x: phase * proxy.size.width * 1.7)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
                    }
                }
            }
    }
}

extension View {
    func appear(_ index: Int = 0) -> some View { modifier(AppearModifier(index: index)) }
    func shimmer(_ active: Bool = true) -> some View { modifier(ShimmerModifier(active: active)) }
}

/// Animates a number from its previous value, never from zero after first show.
struct CountingText: View, Animatable {
    var value: Double
    var format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text(format(value)) }
}
