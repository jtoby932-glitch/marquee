import SwiftUI

/// Grouped results with swipe-to-add, loading skeletons, empty and error states.
struct SearchResultsList: View {
    @Environment(\.theme) private var theme
    @Environment(LibraryStore.self) private var library
    @Environment(Router.self) private var router
    @Environment(ToastCenter.self) private var toasts
    let model: SearchModel
    @State private var statusSheetFor: SearchResult?

    var body: some View {
        List {
            if let notice = model.filmTVUnavailable {
                InlineError(message: notice)
                    .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.margin, bottom: Space.xs, trailing: Space.margin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("search.noKey")
            }
            switch model.phase {
            case .loading where model.sections.isEmpty:
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonRow()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            case .failed(let message):
                InlineError(message: message) { model.retry() }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .empty:
                EmptyStateView(illustration: .ticket, message: String(localized: "Nothing found for “\(model.trimmedQuery)”. Try a shorter title or check the spelling."), identifier: "search.noResults")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            default:
                ForEach(model.sections) { section in
                    Section {
                        ForEach(section.results) { result in
                            row(result)
                        }
                    } header: {
                        Eyebrow(section.kind.pluralName)
                            .padding(.top, Space.xs)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .sheet(item: $statusSheetFor) { result in
            AddStatusSheet(result: result) { status in add(result, status: status) }
                .presentationDetents([.height(340)])
                .presentationCornerRadius(Radius.sheet)
                .presentationDragIndicator(.visible)
        }
    }

    private func row(_ result: SearchResult) -> some View {
        let existing = library.item(result.uid)
        return SearchResultRow(result: result, existing: existing,
                               onOpen: { router.openResult(result, on: .search) },
                               onAdd: { statusSheetFor = result })
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(theme.stroke)
            .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.margin, bottom: Space.xs, trailing: Space.s))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if existing == nil {
                    Button { add(result, status: .wantTo) } label: {
                        Label(EntryStatus.wantTo.label(for: result.kind), systemImage: "bookmark.fill")
                    }
                    .tint(theme.accent)
                }
            }
    }

    private func add(_ result: SearchResult, status: EntryStatus) {
        guard library.add(result, status: status) else { return }
        Haptics.light()
        let label = status.label(for: result.kind)
        toasts.show(String(localized: "Added to \(label)"), poster: PosterContent(result, status: status)) {
            library.discardJustAdded(result.uid)
        }
    }
}

/// Poster, title, year, creator and a type badge; shows my status if I have it.
/// The row and the + are sibling buttons so both stay tappable and findable.
struct SearchResultRow: View {
    @Environment(\.theme) private var theme
    let result: SearchResult
    let existing: LibraryItem?
    let onOpen: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            Button(action: onOpen) {
                HStack(spacing: Space.s) {
                    PosterCard(item: PosterContent(result, status: existing?.status), showsRating: false, showsStatus: false)
                        .frame(width: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.name)
                            .font(.cardTitle(theme.titleDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)
                        Text([result.year.map(String.init), result.creator].compactMap { $0 }.joined(separator: " · "))
                            .font(.meta)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: Space.xs) {
                            TypeBadge(kind: result.kind)
                            if let existing {
                                Text(MetaLine.libraryState(status: existing.status, rating: existing.rating, kind: existing.kind))
                                    .font(.captionMedium)
                                    .foregroundStyle(theme.accent)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("search.result.\(result.uid)")
            if existing == nil {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 36, height: 36)
                        .background(theme.accent.opacity(0.14), in: Circle())
                        .frame(width: Touch.minimum, height: Touch.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Add \(result.name)"))
                .accessibilityIdentifier("search.add.\(result.uid)")
            }
        }
    }
}

struct TypeBadge: View {
    @Environment(\.theme) private var theme
    let kind: MediaKind

    var body: some View {
        Label(kind.displayName, systemImage: kind.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.surface2, in: Capsule())
    }
}

/// A compact library row, used by offline search and lists.
struct LibraryRow: View {
    @Environment(\.theme) private var theme
    let item: LibraryItem

    var body: some View {
        HStack(spacing: Space.s) {
            PosterCard(item: PosterContent(item), showsRating: false, showsStatus: false)
                .frame(width: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.cardTitle(theme.titleDesign)).foregroundStyle(theme.textPrimary).lineLimit(2)
                Text(MetaLine.make(item)).font(.meta).foregroundStyle(theme.textSecondary).lineLimit(1)
                Text(MetaLine.libraryState(status: item.status, rating: item.rating, kind: item.kind))
                    .font(.captionMedium).foregroundStyle(theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
