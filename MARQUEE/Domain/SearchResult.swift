import Foundation

/// One title found by search, before it is in my library.
struct SearchResult: Identifiable, Hashable, Codable {
    let uid: String
    let kind: MediaKind
    let name: String
    let year: Int?
    let creator: String?
    let overview: String
    let posterURL: URL?
    let backdropURL: URL?
    let genres: [String]
    let runtimeMinutes: Int?
    let pageCount: Int?
    /// Source popularity, used only to order results.
    let popularity: Double

    var id: String { uid }
}

/// A group of results of one kind, in the order the Search screen shows them.
struct SearchSection: Identifiable, Equatable {
    let kind: MediaKind
    let results: [SearchResult]
    var id: MediaKind { kind }
}

enum SearchFilter: String, CaseIterable, Identifiable {
    case all, films, tv, books

    var id: String { rawValue }

    var kind: MediaKind? {
        switch self {
        case .all: return nil
        case .films: return .film
        case .tv: return .show
        case .books: return .book
        }
    }

    var displayName: String {
        switch self {
        case .all: return String(localized: "All")
        case .films: return String(localized: "Films")
        case .tv: return String(localized: "TV")
        case .books: return String(localized: "Books")
        }
    }
}

enum SearchRanking {
    /// Groups results by kind, drops duplicates and disabled kinds, and orders each group.
    /// Exact title matches come first, then popularity.
    static func sections(_ results: [SearchResult], query: String, filter: SearchFilter, enabledKinds: Set<MediaKind>) -> [SearchSection] {
        var seen = Set<String>()
        let unique = results.filter { seen.insert($0.uid).inserted }
        let wanted = MediaKind.allCases.filter { enabledKinds.contains($0) && (filter.kind == nil || filter.kind == $0) }
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return wanted.compactMap { kind in
            let group = unique.filter { $0.kind == kind }.sorted { a, b in
                let ea = a.name.lowercased() == needle, eb = b.name.lowercased() == needle
                if ea != eb { return ea }
                return a.popularity > b.popularity
            }
            return group.isEmpty ? nil : SearchSection(kind: kind, results: group)
        }
    }

    /// Offline fallback: searches my own library by title and creator.
    static func libraryMatches(_ items: [LibraryItem], query: String, filter: SearchFilter) -> [LibraryItem] {
        LibraryQuery(kind: filter.kind, status: nil, sort: .title, text: query).apply(to: items)
    }
}
