import SwiftUI

/// Loads remote artwork through `ImageCache`, downsampled to the displayed size,
/// fading in over 0.2 s (instantly when motion is reduced). Falls back to `fallback`.
struct RemoteImage<Fallback: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var fallback: () -> Fallback
    @Environment(\.services) private var services
    @Environment(\.motion) private var motion
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    fallback()
                }
            }
            .task(id: url) { await load(size: proxy.size) }
        }
    }

    private func load(size: CGSize) async {
        guard let url else { return }
        let maxPixel = max(size.width, size.height) * displayScale
        guard maxPixel > 0 else { return }
        do {
            let loaded = try await services.images.image(for: url, maxPixel: maxPixel)
            if let fade = motion.imageFade {
                withAnimation(fade) { image = loaded }
            } else {
                image = loaded
            }
        } catch {
            failed = true
        }
    }
}

/// The designed fallback when a title has no artwork: its name in display type
/// on a gradient from the Look. Never a grey box.
struct CoverPlaceholder: View {
    @Environment(\.theme) private var theme
    let name: String
    let kind: MediaKind
    var year: Int?
    var compact = false

    var body: some View {
        let tint = PlaceholderTint.colours(for: name, look: theme.look)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [tint.top.color, tint.bottom.color], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: kind.symbol)
                .font(.system(size: compact ? 40 : 80, weight: .ultraLight))
                .foregroundStyle(tint.ink.color.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(compact ? 6 : 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Rectangle().fill(tint.ink.color.opacity(0.55)).frame(width: compact ? 14 : 22, height: 2)
                Text(name)
                    .font(.system(compact ? .footnote : .title3, design: .serif).weight(.bold))
                    .foregroundStyle(tint.ink.color)
                    .lineLimit(compact ? 4 : 5)
                    .minimumScaleFactor(0.7)
                if let year, !compact {
                    Text(String(year))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint.ink.color.opacity(0.7))
                }
            }
            .padding(compact ? 8 : 14)
        }
        .accessibilityHidden(true)
    }
}

/// Picks a stable, Look-aware gradient for a placeholder from the title's name.
enum PlaceholderTint {
    struct Colours { let top: RGB; let bottom: RGB; let ink: RGB }

    static func colours(for name: String, look: Look) -> Colours {
        let hash = name.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let accents = look.chartPalette + look.accentGradient
        let accent = accents[Int(hash % UInt32(accents.count))]
        let base = look.isLight ? look.surface3 : look.surface2
        let top = base.mixed(with: accent, amount: look.isLight ? 0.22 : 0.30)
        let bottom = look.background.mixed(with: accent, amount: look.isLight ? 0.08 : 0.10)
        return Colours(top: top, bottom: bottom, ink: look.textPrimary)
    }
}
