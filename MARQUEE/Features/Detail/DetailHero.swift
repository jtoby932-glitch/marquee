import SwiftUI

/// Everything the detail page shows, merged from the library, the search
/// result that opened it, and freshly fetched details (newest wins).
struct DetailDisplay {
    let uid: String
    let kind: MediaKind
    let name: String
    let year: Int?
    let creators: [String]
    let genres: [String]
    let overview: String
    let runtimeMinutes: Int?
    let pageCount: Int?
    let posterURL: URL?
    let backdropURL: URL?
    let certificate: String?
    let seed: SearchResult?
    let item: LibraryTitle?

    init(uid: String, item: LibraryTitle?, seed: SearchResult?, details: TitleDetails?) {
        self.uid = uid
        self.item = item
        self.seed = seed
        kind = item?.kind ?? seed?.kind ?? details?.kind ?? TitleUID(uid)?.kind ?? .film
        name = details?.name ?? item?.name ?? seed?.name ?? ""
        year = details?.year ?? item?.year ?? seed?.year
        let detailCreators = details?.creators ?? []
        creators = !detailCreators.isEmpty ? detailCreators : (item?.creators ?? seed?.creator.map { [$0] } ?? [])
        let detailGenres = details?.genres ?? []
        genres = !detailGenres.isEmpty ? detailGenres : (item?.genres ?? seed?.genres ?? [])
        let detailOverview = details?.overview ?? ""
        overview = !detailOverview.isEmpty ? detailOverview : (item?.overview.isEmpty == false ? item?.overview ?? "" : seed?.overview ?? "")
        runtimeMinutes = details?.runtimeMinutes ?? item?.runtimeMinutes ?? seed?.runtimeMinutes
        pageCount = item?.pageCount ?? seed?.pageCount ?? details?.pageCount
        posterURL = details?.posterURL ?? item?.posterURL ?? seed?.posterURL
        backdropURL = details?.backdropURL ?? item?.backdropURL ?? seed?.backdropURL
        certificate = details?.ukCertificate
    }

    /// True when we have little more than a name, so an error is worth showing.
    var isThin: Bool { overview.isEmpty && creators.isEmpty }

    var poster: PosterContent {
        if let item { return PosterContent(item) }
        return PosterContent(asSearchResult ?? SearchResult(uid: uid, kind: kind, name: name, year: year, creator: nil, overview: "", posterURL: posterURL, backdropURL: nil, genres: [], runtimeMinutes: nil, pageCount: nil, popularity: 0))
    }

    var asSearchResult: SearchResult? {
        guard !name.isEmpty else { return nil }
        return SearchResult(uid: uid, kind: kind, name: name, year: year, creator: creators.first, overview: overview,
                            posterURL: posterURL, backdropURL: backdropURL, genres: genres,
                            runtimeMinutes: runtimeMinutes, pageCount: pageCount, popularity: seed?.popularity ?? 0)
    }

    var meta: String {
        MetaLine.make(kind: kind, year: year, runtimeMinutes: runtimeMinutes, pageCount: pageCount, genre: nil, certificate: certificate)
    }
}

/// A stretchy backdrop (or an enlarged blurred cover for books), with the
/// poster overlapping it and the title beside.
struct DetailHero: View {
    @Environment(\.theme) private var theme
    let display: DetailDisplay
    private let height: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { proxy in
                let pull = max(0, proxy.frame(in: .global).minY)
                backdrop
                    .frame(width: proxy.size.width, height: height + pull)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [theme.background.opacity(0.0), theme.background.opacity(0.55), theme.background],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .offset(y: -pull)
            }
            .frame(height: height)

            HStack(alignment: .bottom, spacing: Space.m) {
                PosterCard(item: display.poster, size: .m, showsRating: false, showsStatus: false)
                    .frame(width: 112)
                    .floatingShadow()
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(display.name)
                        .font(.system(.title2, design: theme.titleDesign).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("detail.title")
                    if !display.meta.isEmpty {
                        Text(display.meta)
                            .font(.meta.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                    if !display.creators.isEmpty {
                        Text(display.creators.prefix(2).joined(separator: ", "))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.textPrimary.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .padding(.bottom, Space.xxs)
            }
            .padding(.horizontal, Space.margin)
            .padding(.top, -96)
        }
    }

    @ViewBuilder private var backdrop: some View {
        if display.kind == .book || display.backdropURL == nil {
            RemoteImage(url: display.posterURL) {
                PlaceholderBackdrop(name: display.name)
            }
            .blur(radius: 28)
            .scaleEffect(1.3)
        } else {
            RemoteImage(url: display.backdropURL) {
                PlaceholderBackdrop(name: display.name)
            }
        }
    }
}

struct PlaceholderBackdrop: View {
    @Environment(\.theme) private var theme
    let name: String

    var body: some View {
        let tint = PlaceholderTint.colours(for: name, look: theme.look)
        LinearGradient(colors: [tint.top.color, theme.background], startPoint: .topTrailing, endPoint: .bottomLeading)
    }
}
