import SwiftUI

/// What Search shows before I type: recent searches, trending films and TV
/// this week, and popular books.
struct SearchDiscovery: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    let model: SearchModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if !model.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack {
                            Eyebrow(String(localized: "Recent searches"))
                            Spacer()
                            Button(String(localized: "Clear")) { model.clearRecent() }
                                .buttonStyle(.ghost)
                                .accessibilityIdentifier("search.recent.clear")
                        }
                        FlowChips(items: model.recentSearches) { model.query = $0 }
                    }
                    .padding(.horizontal, Space.margin)
                }
                if !model.trending.isEmpty {
                    DiscoveryRow(eyebrow: String(localized: "This week"), title: String(localized: "Trending films and TV"), results: model.trending, id: "trending")
                }
                if !model.popularBooks.isEmpty {
                    DiscoveryRow(eyebrow: String(localized: "Readers love"), title: String(localized: "Popular books"), results: model.popularBooks, id: "popularBooks")
                }
                if model.trending.isEmpty && model.popularBooks.isEmpty && model.recentSearches.isEmpty {
                    EmptyStateView(illustration: .books, message: String(localized: "Search for a film, show or book by its title or who made it."), identifier: "search.empty")
                }
            }
            .padding(.vertical, Space.s)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
    }
}

struct DiscoveryRow: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    let eyebrow: String
    let title: String
    let results: [SearchResult]
    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHeader(eyebrow: eyebrow, title: title, identifier: "search.\(id)")
                .padding(.horizontal, Space.margin)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Space.s) {
                    ForEach(results) { result in
                        Button { router.openResult(result, on: .search) } label: {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                PosterCard(item: PosterContent(result), size: .m)
                                Text(result.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(2)
                                    .frame(width: PosterCard.Size.m.width, alignment: .leading)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("search.\(id).\(result.uid)")
                    }
                }
                .padding(.horizontal, Space.margin)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Wrapping chips for short strings, such as recent searches.
struct FlowChips: View {
    @Environment(\.theme) private var theme
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        WrappingLayout(spacing: Space.xs) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Label(item, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, Space.xs)
                        .background(theme.surface2, in: Capsule())
                        .frame(minHeight: Touch.minimum)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// Lays children out in rows, wrapping when a row is full.
struct WrappingLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(width, maxX), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
