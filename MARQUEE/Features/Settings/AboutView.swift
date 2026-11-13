import SwiftUI

/// Version, required credits, and the hidden door to Diagnostics
/// (tap the version seven times).
struct AboutView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(Router.self) private var router
    @State private var taps = 0

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                VStack(spacing: Space.s) {
                    LogoMark().frame(height: 96)
                    Wordmark(size: 26)
                    Button {
                        taps += 1
                        if taps >= 7 {
                            taps = 0
                            Haptics.success()
                            router.push(.diagnostics)
                        }
                    } label: {
                        Text("Version \(services.appVersion) (\(services.build))")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                            .frame(minHeight: Touch.minimum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("about.version")
                    .accessibilityHint(Text("Shows the app version"))
                }
                .padding(.top, Space.xl)

                Text("A personal record of every film, show and book in your life. Everything stays on your phone: no accounts, no ads, no tracking.")
                    .font(.bodyText(theme.titleDesign))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.m) {
                    Eyebrow(String(localized: "Data and credits"))
                    CreditRow(symbol: "film", title: "TMDB",
                              detail: String(localized: "This product uses the TMDB API but is not endorsed or certified by TMDB."))
                    CreditRow(symbol: "tv", title: "JustWatch",
                              detail: String(localized: "Where-to-watch data from JustWatch."))
                    CreditRow(symbol: "book.closed", title: "Open Library",
                              detail: String(localized: "Book data and covers from Open Library, part of the Internet Archive."))
                }
                .padding(Space.card)
                .card()
            }
            .padding(.horizontal, Space.margin)
            .padding(.bottom, Space.xxxl)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "About"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One credit line. TMDB's text is the wording their terms require.
struct CreditRow: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            IconBubble(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(detail).font(.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("About") {
    PreviewHost(demo: true) { AboutView() }
}
