import Foundation

/// Pure grouping of library items into Home's sections.
struct HomeSections {
    struct Row: Identifiable {
        let id: String
        let eyebrow: String
        let title: String
        let items: [LibraryTitle]
        let status: EntryStatus?
    }

    let continueItem: LibraryTitle?
    let rows: [Row]

    init(items: [LibraryTitle], enabledKinds: Set<MediaKind>) {
        let visible = items.filter { enabledKinds.contains($0.kind) && $0.deletedAt == nil }
        let inProgress = visible.filter { $0.status == .inProgress }.sorted { $0.addedAt > $1.addedAt }
        continueItem = inProgress.first
        var rows: [Row] = []
        let others = Array(inProgress.dropFirst())
        if !others.isEmpty {
            rows.append(Row(id: "inProgress", eyebrow: String(localized: "On the go"), title: String(localized: "Also in progress"), items: Array(others.prefix(12)), status: .inProgress))
        }
        let wantWatch = visible.filter { $0.status == .wantTo && $0.kind.isScreen }.sorted { $0.addedAt > $1.addedAt }
        if !wantWatch.isEmpty {
            rows.append(Row(id: "wantWatch", eyebrow: String(localized: "Your list"), title: String(localized: "Want to watch"), items: Array(wantWatch.prefix(15)), status: .wantTo))
        }
        let wantRead = visible.filter { $0.status == .wantTo && $0.kind == .book }.sorted { $0.addedAt > $1.addedAt }
        if !wantRead.isEmpty {
            rows.append(Row(id: "wantRead", eyebrow: String(localized: "Your list"), title: String(localized: "Want to read"), items: Array(wantRead.prefix(15)), status: .wantTo))
        }
        let finished = visible.filter { $0.status == .finished }
            .sorted { ($0.finishedAt ?? $0.addedAt) > ($1.finishedAt ?? $1.addedAt) }
        if !finished.isEmpty {
            rows.append(Row(id: "finished", eyebrow: String(localized: "Lately"), title: String(localized: "Recently finished"), items: Array(finished.prefix(15)), status: .finished))
        }
        self.rows = rows
    }
}
