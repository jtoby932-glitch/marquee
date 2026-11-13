import SwiftUI

/// My library as a poster grid: a segment per type, status chips and sorting.
/// List and shelf layouts, filters, pinch and multi-select arrive in milestone 4.
struct LibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(LibraryStore.self) private var library
    @Environment(PreferencesStore.self) private var preferences
    @Environment(Router.self) private var router
    @SceneStorage("library.kind") private var kindRaw = MediaKind.film.rawValue
    @SceneStorage("library.sort") private var sortRaw = LibrarySort.added.rawValue
    @State private var status: EntryStatus?

    private var kinds: [MediaKind] { MediaKind.allCases.filter { preferences.enabledKinds.contains($0) } }
    private var kind: MediaKind {
        let chosen = MediaKind(rawValue: kindRaw) ?? .film
        return kinds.contains(chosen) ? chosen : (kinds.first ?? .film)
    }
    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .added }

    var body: some View {
        let query = LibraryQuery(kind: kind, status: status, sort: sort)
        let items = query.apply(to: library.activeItems)
        let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s, alignment: .top), count: preferences.gridColumns)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    header.id("top")
                    if kinds.count > 1 {
                        SegmentedPicker(options: kinds, selection: Binding(get: { kind }, set: { kindRaw = $0.rawValue }),
                                        title: { $0.pluralName }, identifier: "library.kind")
                            .padding(.horizontal, Space.margin)
                    }
                    statusChips
                    if library.activeItems.isEmpty {
                        EmptyStateView(illustration: .projector,
                                       message: String(localized: "Your library's empty. Search for a film, show or book to add your first."),
                                       actionTitle: String(localized: "Search"), action: { router.quickAdd() }, identifier: "library.empty")
                    } else if items.isEmpty {
                        EmptyStateView(illustration: kind == .book ? .books : (kind == .show ? .television : .ticket),
                                       message: emptyMessage, identifier: "library.filterEmpty")
                    } else {
                        LazyVGrid(columns: columns, spacing: Space.m) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button { router.push(.title(uid: item.uid), on: .library) } label: {
                                    PosterCard(item: PosterContent(item))
                                }
                                .buttonStyle(PressableStyle())
                                .appear(index)
                                .accessibilityIdentifier("library.poster.\(item.uid)")
                            }
                        }
                        .padding(.horizontal, Space.margin)
                        Text(countLine(items.count))
                            .font(.footnote)
                            .foregroundStyle(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Space.xs)
                    }
                }
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: router.scrollToTopRequest[.library]) {
                withAnimation { proxy.scrollTo("top", anchor: .top) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Library")
                .font(.screenTitle(theme.titleDesign))
                .foregroundStyle(theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Menu {
                Picker(String(localized: "Sort by"), selection: Binding(get: { sort }, set: { sortRaw = $0.rawValue })) {
                    ForEach(LibrarySort.allCases) { Text($0.displayName).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.body.weight(.semibold))
                    .frame(width: Touch.minimum, height: Touch.minimum)
            }
            .accessibilityLabel(Text("Sort"))
            .accessibilityIdentifier("library.sort")
            Menu {
                Button { router.push(.recentlyDeleted, on: .library) } label: {
                    Label(String(localized: "Recently deleted"), systemImage: "trash")
                }
                Button { router.push(.settings, on: .library) } label: {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
                    .frame(width: Touch.minimum, height: Touch.minimum)
            }
            .accessibilityLabel(Text("More"))
            .accessibilityIdentifier("library.more")
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, Space.margin)
        .padding(.top, Space.s)
    }

    private var statusChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.xs) {
                FilterChip(title: String(localized: "All"), isSelected: status == nil) { status = nil }
                    .accessibilityIdentifier("library.status.all")
                ForEach(EntryStatus.allCases) { s in
                    FilterChip(title: s.chipLabel, isSelected: status == s) {
                        Haptics.selection()
                        status = (status == s) ? nil : s
                    }
                    .accessibilityIdentifier("library.status.\(s.rawValue)")
                }
            }
            .padding(.horizontal, Space.margin)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyMessage: String {
        guard let status else {
            return String(localized: "No \(kind.pluralName.lowercased()) yet. Search to add some.")
        }
        return String(localized: "Nothing marked \(status.chipLabel.lowercased()) in \(kind.pluralName.lowercased()).")
    }

    private func countLine(_ count: Int) -> String {
        count == 1 ? String(localized: "1 title") : String(localized: "\(count) titles")
    }
}

/// Everything removed in the last 30 days, with all its history intact.
struct RecentlyDeletedView: View {
    @Environment(\.theme) private var theme
    @Environment(LibraryStore.self) private var library
    @Environment(ToastCenter.self) private var toasts
    @State private var confirmDelete: LibraryItem?

    var body: some View {
        List {
            if library.recentlyDeleted.isEmpty {
                EmptyStateView(illustration: .ticket, message: String(localized: "Nothing here. Anything you remove stays here for 30 days."), identifier: "deleted.empty")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(library.recentlyDeleted) { item in
                        HStack {
                            LibraryRow(item: item)
                            Button(String(localized: "Restore")) {
                                library.restore(item.uid)
                                toasts.show(String(localized: "Restored \(item.name)."))
                            }
                            .buttonStyle(.secondary)
                            .accessibilityIdentifier("deleted.restore.\(item.uid)")
                            Button { confirmDelete = item } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(theme.danger)
                                    .frame(width: Touch.minimum, height: Touch.minimum)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Delete \(item.name) now"))
                            .accessibilityIdentifier("deleted.deleteNow.\(item.uid)")
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button(String(localized: "Delete now"), role: .destructive) { confirmDelete = item }
                        }
                    }
                } footer: {
                    Text("Items are deleted for good 30 days after you remove them.")
                        .font(.footnote)
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(String(localized: "Recently deleted"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(String(localized: "Delete for good?"), isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            Button(String(localized: "Delete now"), role: .destructive) {
                if let item = confirmDelete {
                    Haptics.warning()
                    library.deletePermanently(item.uid)
                }
                confirmDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }
}

#Preview("Library") {
    PreviewHost(demo: true) { LibraryView() }
}

#Preview("Library – Paper") {
    PreviewHost(demo: true, look: .paper) { LibraryView() }
}
