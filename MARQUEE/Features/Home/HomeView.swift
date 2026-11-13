import SwiftUI

/// Home: what I'm in the middle of and what's next. Every section is calm and
/// artwork-led; Up Next, Reading now and This week arrive in milestone 3.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(LibraryStore.self) private var library
    @Environment(PreferencesStore.self) private var preferences
    @Environment(Router.self) private var router

    var body: some View {
        let sections = HomeSections(items: library.activeItems, enabledKinds: preferences.enabledKinds)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    HomeHeader()
                        .id("top")
                        .appear(0)
                    if library.activeItems.isEmpty {
                        EmptyStateView(
                            illustration: .projector,
                            message: String(localized: "Your library's empty. Search for a film, show or book to add your first."),
                            actionTitle: String(localized: "Search"),
                            action: { router.quickAdd() },
                            identifier: "home.empty")
                        .appear(1)
                    } else {
                        if let hero = sections.continueItem {
                            ContinueCard(item: hero)
                                .padding(.horizontal, Space.margin)
                                .appear(1)
                        } else {
                            EmptyStateView(
                                illustration: .popcorn,
                                message: String(localized: "Nothing on the go. Find something good to start."),
                                actionTitle: String(localized: "Search"),
                                action: { router.quickAdd() },
                                identifier: "home.nothingOnTheGo")
                            .card()
                            .padding(.horizontal, Space.margin)
                            .appear(1)
                        }
                        ForEach(Array(sections.rows.enumerated()), id: \.element.id) { index, row in
                            PosterRow(row: row)
                                .appear(index + 2)
                        }
                    }
                }
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: router.scrollToTopRequest[.home]) {
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
        }
    }
}

struct HomeHeader: View {
    @Environment(\.theme) private var theme
    @Environment(PreferencesStore.self) private var preferences
    @Environment(Router.self) private var router

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .top, spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Eyebrow(AppCalendar.eyebrowDate(context.date))
                    Text(AppCalendar.greeting(at: context.date, name: preferences.displayName))
                        .font(.screenTitle(theme.titleDesign))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: Space.s)
                Button { router.quickAdd() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.onAccent)
                        .frame(width: Touch.minimum, height: Touch.minimum)
                        .background(theme.accentGradient, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Quick add"))
                .accessibilityIdentifier("home.quickAdd")
                Button { router.push(.settings, on: .home) } label: {
                    Avatar(name: preferences.displayName)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Settings"))
                .accessibilityIdentifier("home.avatar")
            }
            .padding(.horizontal, Space.margin)
            .padding(.top, Space.s)
        }
    }
}

/// Initials on the accent gradient, or a person glyph when no name is set.
struct Avatar: View {
    @Environment(\.theme) private var theme
    let name: String
    var size: CGFloat = Touch.minimum

    var body: some View {
        let initials = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        ZStack {
            Circle().fill(theme.surface2)
            Circle().strokeBorder(theme.accentGradient, lineWidth: 2)
            if initials.isEmpty {
                Image(systemName: "person.fill").font(.system(size: size * 0.4)).foregroundStyle(theme.textSecondary)
            } else {
                Text(initials).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A side-scrolling row of posters with a section header.
struct PosterRow: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    let row: HomeSections.Row

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionHeader(eyebrow: row.eyebrow, title: row.title, identifier: "home.\(row.id)")
                .padding(.horizontal, Space.margin)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Space.s) {
                    ForEach(row.items) { item in
                        Button { router.push(.title(uid: item.uid), on: .home) } label: {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                PosterCard(item: PosterContent(item), size: .m, showsStatus: false)
                                Text(item.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(2)
                                    .frame(width: PosterCard.Size.m.width, alignment: .leading)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .posterAccessibility(item.accessibilityDescription)
                        .accessibilityIdentifier("home.\(row.id).\(item.uid)")
                    }
                }
                .padding(.horizontal, Space.margin)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// The hero card for the most recent thing in progress, over its blurred artwork.
struct ContinueCard: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    let item: LibraryTitle

    var body: some View {
        Button { router.push(.title(uid: item.uid), on: .home) } label: {
            HStack(alignment: .bottom, spacing: Space.m) {
                PosterCard(item: PosterContent(item), size: .m, showsRating: false, showsStatus: false)
                    .frame(width: 96)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Eyebrow(String(localized: "Continue"), color: theme.accent)
                    Text(item.name)
                        .font(.cardTitle(theme.titleDesign).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Text(MetaLine.make(item))
                        .font(.meta)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                    if let progress = item.readingProgress, let page = item.currentPage, let pages = item.pageCount {
                        ProgressView(value: progress)
                            .tint(theme.accent)
                            .padding(.top, Space.xxs)
                        Text("Page \(page) of \(pages)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.card)
            .background {
                ZStack {
                    theme.surface1
                    RemoteImage(url: item.backdropURL ?? item.posterURL) {
                        LinearGradient(colors: [theme.accent.opacity(0.22), theme.surface1], startPoint: .topTrailing, endPoint: .bottomLeading)
                    }
                    .blur(radius: 30)
                    .opacity(0.55)
                    LinearGradient(colors: [theme.surface1.opacity(0.1), theme.surface1.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .posterAccessibility(String(localized: "Continue: \(item.accessibilityDescription)"))
        .accessibilityIdentifier("home.continue")
    }
}

#Preview("Home – demo") {
    PreviewHost(demo: true) { HomeView() }
}

#Preview("Home – empty") {
    PreviewHost(demo: false) { HomeView() }
}
