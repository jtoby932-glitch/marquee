import SwiftUI

/// Search opens with the keyboard up. Results are grouped by type; swipe right
/// adds to "Want to", + picks a status, tapping opens the detail page.
struct SearchView: View {
    @Environment(\.theme) private var theme
    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(PreferencesStore.self) private var preferences
    @Environment(NetworkMonitor.self) private var network
    @Environment(Router.self) private var router
    @State private var model: SearchModel?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                theme.background
            }
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard model == nil else { return }
            let m = SearchModel(filmTV: services.filmTV, books: services.books)
            m.enabledKinds = preferences.enabledKinds
            model = m
            if let pending = router.pendingSearchQuery {
                m.query = pending
                m.queryChanged()
                router.pendingSearchQuery = nil
            }
            fieldFocused = LaunchOptions.current.screen == nil
            await m.loadDiscovery()
        }
        .onChange(of: router.searchFocusRequest) {
            if let pending = router.pendingSearchQuery {
                model?.query = pending
                router.pendingSearchQuery = nil
            }
            fieldFocused = true
        }
    }

    @ViewBuilder private func content(_ model: SearchModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Space.s) {
                SearchField(text: $model.query, focused: $fieldFocused)
                ScrollView(.horizontal) {
                    HStack(spacing: Space.xs) {
                        ForEach(availableFilters) { filter in
                            FilterChip(title: filter.displayName, isSelected: model.filter == filter) {
                                Haptics.selection()
                                model.filter = filter
                            }
                            .accessibilityIdentifier("search.filter.\(filter.rawValue)")
                        }
                    }
                    .padding(.horizontal, Space.margin)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, Space.s)
            .padding(.bottom, Space.xs)

            if !network.isOnline {
                offlineResults(model)
            } else if model.trimmedQuery.isEmpty {
                SearchDiscovery(model: model)
            } else {
                SearchResultsList(model: model)
            }
        }
        .onChange(of: model.query) { model.queryChanged() }
        .onChange(of: model.filter) { model.filterChanged() }
    }

    private var availableFilters: [SearchFilter] {
        SearchFilter.allCases.filter { $0.kind.map { preferences.enabledKinds.contains($0) } ?? true }
    }

    /// Offline: say so calmly and search my own library instead.
    @ViewBuilder private func offlineResults(_ model: SearchModel) -> some View {
        let matches = SearchRanking.libraryMatches(library.activeItems, query: model.trimmedQuery, filter: model.filter)
        List {
            Section {
                HStack {
                    OfflineBanner(message: String(localized: "You're offline. Searching your library instead."))
                    Spacer(minLength: 0)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(matches) { item in
                Button { router.push(.title(uid: item.uid), on: .search) } label: {
                    LibraryRow(item: item)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(theme.stroke)
                .accessibilityIdentifier("search.library.\(item.uid)")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
}

/// The custom search field: icon, text, clear button.
struct SearchField: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var prompt = String(localized: "Films, shows and books")

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(theme.textPrimary)
                .accessibilityIdentifier("search.field")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: Touch.minimum, height: Touch.minimum)
                }
                .accessibilityLabel(Text("Clear search"))
                .accessibilityIdentifier("search.clear")
            }
        }
        .padding(.leading, Space.m)
        .padding(.trailing, text.isEmpty ? Space.m : 0)
        .frame(minHeight: 48)
        .background(theme.surface1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.strokeStrong, lineWidth: 1))
        .padding(.horizontal, Space.margin)
    }
}

#Preview("Search") {
    PreviewHost(demo: true) { SearchView() }
}

#Preview("Search – offline") {
    PreviewHost(demo: true, offline: true) { SearchView() }
}
