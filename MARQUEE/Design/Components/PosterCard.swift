import SwiftUI

/// A 2:3 poster or cover with optional overlays. Size S for grids and rows,
/// M for Home rows, L for heroes. Artwork is always the hero.
struct PosterCard: View {
    enum Size {
        case s, m, l
        var width: CGFloat? {
            switch self {
            case .s: return nil
            case .m: return 124
            case .l: return 168
            }
        }
    }

    @Environment(\.theme) private var theme
    let item: PosterContent
    var size: Size = .s
    var showsRating = true
    var showsStatus = true

    var body: some View {
        artwork
            .aspectRatio(AspectRatio.poster, contentMode: .fit)
            .frame(width: size.width)
            .clipShape(RoundedRectangle(cornerRadius: theme.posterRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.posterRadius, style: .continuous).strokeBorder(theme.stroke, lineWidth: 1))
            .overlay(alignment: .bottomLeading) { overlays }
            .contentShape(RoundedRectangle(cornerRadius: theme.posterRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.accessibilityLabel)
    }

    private var artwork: some View {
        Color.clear.overlay {
            RemoteImage(url: item.posterURL) {
                CoverPlaceholder(name: item.name, kind: item.kind, year: item.year, compact: size == .s)
            }
            .background {
                // Covers that aren't 2:3 sit on a blurred copy of themselves (§3.5).
                if item.kind == .book, item.posterURL != nil {
                    RemoteImage(url: item.posterURL) { Color.clear }.blur(radius: 18).opacity(0.7)
                }
            }
        }
    }

    @ViewBuilder private var overlays: some View {
        HStack(spacing: 4) {
            if showsStatus, let status = item.status, status != .finished || item.rating == nil {
                StatusDot(status: status)
            }
            if showsRating, let rating = item.rating {
                Label {
                    Text(Rating.starText(rating)).font(.caption2.weight(.bold).monospacedDigit())
                } icon: {
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                }
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .foregroundStyle(theme.star)
                .background(.black.opacity(0.62), in: Capsule())
            }
            Spacer(minLength: 0)
            if let progress = item.progress {
                ProgressRing(value: progress, lineWidth: 3)
                    .frame(width: 22, height: 22)
                    .padding(3)
                    .background(.black.opacity(0.55), in: Circle())
            }
        }
        .padding(6)
    }
}

/// What a poster needs to draw itself, from a library item or a search result.
struct PosterContent: Hashable {
    let uid: String
    let kind: MediaKind
    let name: String
    let year: Int?
    let posterURL: URL?
    var status: EntryStatus?
    var rating: Int?
    var progress: Double?
    let accessibilityLabel: String

    init(_ item: LibraryTitle) {
        uid = item.uid
        kind = item.kind
        name = item.name
        year = item.year
        posterURL = item.posterURL
        status = item.status
        rating = item.rating
        progress = item.status == .inProgress ? item.readingProgress : nil
        accessibilityLabel = item.accessibilityDescription
    }

    init(_ result: SearchResult, status: EntryStatus? = nil) {
        uid = result.uid
        kind = result.kind
        name = result.name
        year = result.year
        posterURL = result.posterURL
        self.status = status
        rating = nil
        progress = nil
        accessibilityLabel = [result.name, result.year.map(String.init), result.kind.spokenName].compactMap { $0 }.joined(separator: ", ")
    }
}

/// A small coloured dot for status, with a shape so it never relies on colour alone.
struct StatusDot: View {
    @Environment(\.theme) private var theme
    let status: EntryStatus

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(theme.onAccent)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch status {
        case .wantTo: return "bookmark.fill"
        case .inProgress: return "play.fill"
        case .finished: return "checkmark"
        case .dropped: return "xmark"
        case .paused: return "pause.fill"
        }
    }

    private var color: Color {
        switch status {
        case .wantTo: return theme.textSecondary
        case .inProgress: return theme.accent
        case .finished: return theme.success
        case .dropped: return theme.danger
        case .paused: return theme.warning
        }
    }
}

/// A ring that animates from its previous value and reads out a percentage.
struct ProgressRing: View {
    @Environment(\.theme) private var theme
    @Environment(\.motion) private var motion
    let value: Double
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(theme.textPrimary.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(theme.accentGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(motion.animation(.spring(response: 0.6, dampingFraction: 0.85)), value: value)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text("\(Int((value * 100).rounded())) percent"))
    }
}
