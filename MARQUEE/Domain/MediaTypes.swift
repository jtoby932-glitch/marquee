import Foundation

/// The three kinds of Title the app tracks.
enum MediaKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case film, show, book

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .film: return String(localized: "Film")
        case .show: return String(localized: "TV")
        case .book: return String(localized: "Book")
        }
    }

    var pluralName: String {
        switch self {
        case .film: return String(localized: "Films")
        case .show: return String(localized: "TV")
        case .book: return String(localized: "Books")
        }
    }

    /// The word VoiceOver reads ("film", "show", "book").
    var spokenName: String {
        switch self {
        case .film: return String(localized: "film")
        case .show: return String(localized: "show")
        case .book: return String(localized: "book")
        }
    }

    var symbol: String {
        switch self {
        case .film: return "film"
        case .show: return "tv"
        case .book: return "book.closed"
        }
    }

    var isScreen: Bool { self != .book }
}

/// Where a Title sits in my library.
enum EntryStatus: String, CaseIterable, Identifiable, Codable, Hashable {
    case wantTo, inProgress, finished, dropped, paused

    var id: String { rawValue }

    func label(for kind: MediaKind) -> String {
        switch (self, kind) {
        case (.wantTo, .book): return String(localized: "Want to read")
        case (.wantTo, _): return String(localized: "Want to watch")
        case (.inProgress, .book): return String(localized: "Reading")
        case (.inProgress, .film): return String(localized: "Watching")
        case (.inProgress, .show): return String(localized: "Watching")
        case (.finished, .book): return String(localized: "Read")
        case (.finished, _): return String(localized: "Watched")
        case (.dropped, _): return String(localized: "Dropped")
        case (.paused, _): return String(localized: "Paused")
        }
    }

    /// Short, kind-neutral name used on filter chips.
    var chipLabel: String {
        switch self {
        case .wantTo: return String(localized: "Want to")
        case .inProgress: return String(localized: "In progress")
        case .finished: return String(localized: "Finished")
        case .dropped: return String(localized: "Dropped")
        case .paused: return String(localized: "Paused")
        }
    }

    var spokenName: String {
        switch self {
        case .wantTo: return String(localized: "want to")
        case .inProgress: return String(localized: "in progress")
        case .finished: return String(localized: "finished")
        case .dropped: return String(localized: "dropped")
        case .paused: return String(localized: "paused")
        }
    }

    var symbol: String {
        switch self {
        case .wantTo: return "bookmark"
        case .inProgress: return "play.circle"
        case .finished: return "checkmark.circle"
        case .dropped: return "xmark.circle"
        case .paused: return "pause.circle"
        }
    }
}

enum BookFormat: String, CaseIterable, Identifiable, Codable {
    case paper, ebook, audio
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .paper: return String(localized: "Paper")
        case .ebook: return String(localized: "Ebook")
        case .audio: return String(localized: "Audiobook")
        }
    }
}

/// Stable identifier for a Title across sources: `tmdb-movie-603`, `tmdb-tv-1399`, `ol-OL82563W`.
struct TitleUID: Hashable, CustomStringConvertible {
    enum Source: Hashable { case tmdbMovie(Int), tmdbTV(Int), openLibrary(String) }

    let source: Source

    init(source: Source) { self.source = source }

    init?(_ string: String) {
        if string.hasPrefix("tmdb-movie-"), let id = Int(string.dropFirst("tmdb-movie-".count)), id > 0 {
            source = .tmdbMovie(id)
        } else if string.hasPrefix("tmdb-tv-"), let id = Int(string.dropFirst("tmdb-tv-".count)), id > 0 {
            source = .tmdbTV(id)
        } else if string.hasPrefix("ol-") {
            let key = String(string.dropFirst(3))
            guard key.hasPrefix("OL"), key.count > 3, key.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
            source = .openLibrary(key)
        } else {
            return nil
        }
    }

    var description: String {
        switch source {
        case .tmdbMovie(let id): return "tmdb-movie-\(id)"
        case .tmdbTV(let id): return "tmdb-tv-\(id)"
        case .openLibrary(let key): return "ol-\(key)"
        }
    }

    var kind: MediaKind {
        switch source {
        case .tmdbMovie: return .film
        case .tmdbTV: return .show
        case .openLibrary: return .book
        }
    }
}
