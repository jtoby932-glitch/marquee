import SwiftUI

/// The detail page. Opens instantly from the library or the search result,
/// then quietly fills in details. Rating, review, diary and the rest arrive in
/// milestone 2; here: artwork, facts, overview, status, add and remove.
struct TitleDetailView: View {
    let uid: String
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.dismiss) private var dismiss
    @State private var details: TitleDetails?
    @State private var loadError: UserFacingError.Message?
    @State private var loading = false
    @State private var overviewExpanded = false
    @State private var confirmRemove = false

    private var item: LibraryItem? { library.item(uid) }
    private var display: DetailDisplay { DetailDisplay(uid: uid, item: item, seed: router.seeds[uid], details: details) }

    var body: some View {
        let d = display
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                DetailHero(display: d)
                VStack(alignment: .leading, spacing: Space.xl) {
                    actions(d)
                    if !d.genres.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: Space.xs) {
                                ForEach(d.genres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(theme.textSecondary)
                                        .padding(.horizontal, Space.s)
                                        .padding(.vertical, 6)
                                        .background(theme.surface2, in: Capsule())
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    overview(d)
                    if let loadError, d.isThin {
                        InlineError(message: loadError) { Task { await load() } }
                    }
                }
                .padding(.horizontal, Space.margin)
            }
            .padding(.bottom, Space.xxxl)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if item != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { confirmRemove = true } label: {
                            Label(String(localized: "Remove from library"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: Touch.minimum, height: Touch.minimum)
                    }
                    .accessibilityLabel(Text("More"))
                    .accessibilityIdentifier("detail.more")
                }
            }
        }
        .confirmationDialog(String(localized: "Remove \(d.name)?"), isPresented: $confirmRemove, titleVisibility: .visible) {
            Button(String(localized: "Remove"), role: .destructive) { remove(d) }
                .accessibilityIdentifier("detail.confirmRemove")
        } message: {
            Text("It goes to Recently deleted for 30 days, with everything you've logged.")
        }
        .task { await load() }
    }

    @ViewBuilder private func actions(_ d: DetailDisplay) -> some View {
        if let item {
            HStack(spacing: Space.s) {
                Menu {
                    ForEach(EntryStatus.allCases) { status in
                        Button {
                            Haptics.selection()
                            library.setStatus(uid, status)
                        } label: {
                            if status == item.status {
                                Label(status.label(for: item.kind), systemImage: "checkmark")
                            } else {
                                Text(status.label(for: item.kind))
                            }
                        }
                    }
                } label: {
                    Label(item.status.label(for: item.kind), systemImage: item.status.symbol)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, Space.l)
                        .frame(minHeight: Touch.minimum)
                        .foregroundStyle(theme.onAccent)
                        .background(theme.accentGradient, in: Capsule())
                }
                .accessibilityIdentifier("detail.status")
                if let rating = item.rating {
                    Label(Rating.starText(rating), systemImage: "star.fill")
                        .font(.body.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.star)
                        .accessibilityLabel(Text(Rating.spoken(rating)))
                }
                Spacer()
            }
        } else {
            HStack(spacing: Space.s) {
                Button {
                    add(d, .wantTo)
                } label: {
                    Label(EntryStatus.wantTo.label(for: d.kind), systemImage: "bookmark.fill")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("detail.addWantTo")
                Menu {
                    ForEach([EntryStatus.inProgress, .finished], id: \.self) { status in
                        Button(status.label(for: d.kind)) { add(d, status) }
                    }
                } label: {
                    Text("Other status")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, Space.l)
                        .frame(minHeight: Touch.minimum)
                        .foregroundStyle(theme.textPrimary)
                        .background(theme.surface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.strokeStrong, lineWidth: 1))
                }
                .accessibilityIdentifier("detail.addOther")
            }
        }
    }

    @ViewBuilder private func overview(_ d: DetailDisplay) -> some View {
        if !d.overview.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Eyebrow(String(localized: "Overview"))
                Text(d.overview)
                    .font(.bodyText(theme.titleDesign))
                    .foregroundStyle(theme.textPrimary.opacity(0.92))
                    .lineSpacing(3)
                    .lineLimit(overviewExpanded ? nil : 5)
                    .fixedSize(horizontal: false, vertical: true)
                if d.overview.count > 260 {
                    Button(overviewExpanded ? String(localized: "Show less") : String(localized: "Read more")) {
                        withAnimation(.easeInOut(duration: 0.2)) { overviewExpanded.toggle() }
                    }
                    .buttonStyle(.ghost)
                    .accessibilityIdentifier("detail.readMore")
                }
            }
        } else if loading {
            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(0..<3, id: \.self) { _ in Capsule().fill(theme.surface2).frame(height: 12) }
            }
            .shimmer()
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let kind = TitleUID(uid)?.kind else { return }
        do {
            let fetched = try await (kind == .book ? services.books.details(uid: uid) : services.filmTV.details(uid: uid))
            details = fetched
            loadError = nil
            if item != nil { library.apply(fetched) }
        } catch {
            let mapped = UserFacingError.map(error)
            if mapped != .cancelled { loadError = UserFacingError.message(for: mapped) }
        }
    }

    private func add(_ d: DetailDisplay, _ status: EntryStatus) {
        guard let result = d.asSearchResult, library.add(result, status: status) else { return }
        if let details { library.apply(details) }
        Haptics.light()
        toasts.show(String(localized: "Added to \(status.label(for: d.kind))"), poster: PosterContent(result, status: status)) {
            library.discardJustAdded(uid)
        }
    }

    private func remove(_ d: DetailDisplay) {
        Haptics.warning()
        library.remove(uid)
        toasts.show(String(localized: "Removed. You can restore it from Recently deleted for 30 days."), poster: d.poster) {
            library.restore(uid)
        }
        dismiss()
    }
}

#Preview("Detail – film") {
    PreviewHost(demo: true) { TitleDetailView(uid: "tmdb-movie-693134") }
}

#Preview("Detail – book") {
    PreviewHost(demo: true, look: .paper) { TitleDetailView(uid: "ol-OL893415W") }
}
