import SwiftUI

/// Cold-launch intro (§5.5): the mark draws itself, a shine sweeps across it,
/// then it scales and fades into Home. At most 1.6 s, skippable with a tap,
/// instant when animation is Off. Its first frame matches the static launch screen.
struct OpeningAnimation: View {
    @Environment(\.theme) private var theme
    @Environment(\.motion) private var motion
    let onFinished: () -> Void

    @State private var draw: CGFloat = 0
    @State private var fill = 0.0
    @State private var shine: CGFloat = -1
    @State private var exit = false
    @State private var finished = false

    static let totalDuration = 1.6

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ZStack {
                // Same faint mark as the static launch screen, so there's no jump.
                LogoMark().opacity(0.16 * (1 - fill))
                FrameBookmarkOutline()
                    .trim(from: 0, to: draw)
                    .stroke(theme.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ZStack {
                    FrameBookmarkOutline().fill(theme.accentGradient)
                    FrameBookmarkCutouts().fill(theme.background)
                }
                .opacity(fill)
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.65), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.55)
                            .rotationEffect(.degrees(20))
                            .offset(x: shine * proxy.size.width * 1.4)
                            .blendMode(.plusLighter)
                    }
                    .mask(FrameBookmarkOutline())
                    .opacity(fill)
                }
            }
            .frame(width: 96, height: 178)
            .scaleEffect(exit ? 1.6 : 1)
            .opacity(exit ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement()
        .accessibilityLabel(Text("MARQUEE"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double-tap to skip"))
        .accessibilityIdentifier("launch.intro")
        .task { await play() }
    }

    private func play() async {
        guard motion.allowsAnimation else {
            finish()
            return
        }
        if !motion.allowsMovement {
            withAnimation(.easeInOut(duration: 0.3)) { fill = 1 }
            try? await Task.sleep(nanoseconds: 450_000_000)
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.6)) { draw = 1 }
        try? await Task.sleep(nanoseconds: 450_000_000)
        withAnimation(.easeOut(duration: 0.3)) { fill = 1 }
        withAnimation(.easeInOut(duration: 0.5).delay(0.15)) { shine = 1 }
        try? await Task.sleep(nanoseconds: 750_000_000)
        withAnimation(.easeIn(duration: 0.35)) { exit = true }
        try? await Task.sleep(nanoseconds: 350_000_000)
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinished()
    }
}

#Preview("Intro") {
    OpeningAnimation {}
}
