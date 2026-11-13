import Foundation

/// A plain value copy of a Title and my Entry for it. Screens read these from
/// `LibraryStore`'s snapshot, so they never query the database while rendering.
struct LibraryItem: Identifiable, Hashable {
    let uid: String
    let kind: MediaKind
    var name: String
    var year: Int?
    var creators: [String]
    var genres: [String]
    var overview: String
    var runtimeMinutes: Int?
    var pageCount: Int?
    var posterURL: URL?
    var backdropURL: URL?
    var status: EntryStatus
    var rating: Int?
    var isFavourite: Bool
    var addedAt: Date
    var finishedAt: Date?
    var currentPage: Int?
    var deletedAt: Date?
    var detailsPending: Bool

    var id: String { uid }

    var primaryCreator: String? { creators.first }

    /// Book progress from 0 to 1, when there is a page count.
    var readingProgress: Double? {
        guard kind == .book, let pageCount, pageCount > 0, let currentPage else { return nil }
        return min(1, max(0, Double(currentPage) / Double(pageCount)))
    }

    /// "Dune: Part Two, 2024, film, finished, rated 4 and a half stars"
    var accessibilityDescription: String {
        var parts = [name]
        if let year { parts.append(String(year)) }
        parts.append(kind.spokenName)
        parts.append(status.spokenName)
        if let rating { parts.append(Rating.spoken(rating)) }
        return parts.joined(separator: ", ")
    }
}

enum LibrarySort: String, CaseIterable, Identifiable, Codable {
    case added, finished, rating, title, year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .added: return String(localized: "Date added")
        case .finished: return String(localized: "Date finished")
        case .rating: return String(localized: "Rating")
        case .title: return String(localized: "Title")
        case .year: return String(localized: "Year")
        }
    }
}

/// Pure filtering and sorting for the Library screen.
struct LibraryQuery: Equatable {
    var kind: MediaKind?
    var status: EntryStatus?
    var sort: LibrarySort = .added
    var text: String = ""

    func apply(to items: [LibraryItem]) -> [LibraryItem] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            guard item.deletedAt == nil else { return false }
            if let kind, item.kind != kind { return false }
            if let status, item.status != status { return false }
            if !needle.isEmpty {
                let haystack = ([item.name] + item.creators).joined(separator: " ")
                if haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) == nil { return false }
            }
            return true
        }
        return filtered.sorted(by: sort.comparator)
    }
}

extension LibrarySort {
    /// Newest, highest and A→Z first; ties fall back to the title so order is stable.
    var comparator: (LibraryItem, LibraryItem) -> Bool {
        switch self {
        case .added:
            return { a, b in a.addedAt != b.addedAt ? a.addedAt > b.addedAt : LibrarySort.byTitle(a, b) }
        case .finished:
            return { a, b in
                switch (a.finishedAt, b.finishedAt) {
                case let (x?, y?) where x != y: return x > y
                case (.some, nil): return true
                case (nil, .some): return false
                default: return LibrarySort.byTitle(a, b)
                }
            }
        case .rating:
            return { a, b in (a.rating ?? 0) != (b.rating ?? 0) ? (a.rating ?? 0) > (b.rating ?? 0) : LibrarySort.byTitle(a, b) }
        case .title:
            return LibrarySort.byTitle
        case .year:
            return { a, b in (a.year ?? 0) != (b.year ?? 0) ? (a.year ?? 0) > (b.year ?? 0) : LibrarySort.byTitle(a, b) }
        }
    }

    static func byTitle(_ a: LibraryItem, _ b: LibraryItem) -> Bool {
        let order = sortKey(a.name).localizedStandardCompare(sortKey(b.name))
        return order == .orderedSame ? a.uid < b.uid : order == .orderedAscending
    }

    /// Ignores a leading "The", "A" or "An" when sorting by title.
    static func sortKey(_ name: String) -> String {
        for article in ["The ", "A ", "An "] where name.hasPrefix(article) && name.count > article.count {
            return String(name.dropFirst(article.count))
        }
        return name
    }
}
