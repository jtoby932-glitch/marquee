import Foundation

/// The "Year · runtime · genre" line used under titles everywhere.
enum MetaLine {
    static func make(kind: MediaKind, year: Int?, runtimeMinutes: Int?, pageCount: Int?, genre: String?, certificate: String? = nil) -> String {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        switch kind {
        case .film:
            if let runtimeMinutes, runtimeMinutes > 0 { parts.append(AppCalendar.runtime(runtimeMinutes)) }
        case .show:
            if let runtimeMinutes, runtimeMinutes > 0 { parts.append(String(localized: "\(runtimeMinutes) m episodes")) }
        case .book:
            if let pageCount, pageCount > 0 { parts.append(String(localized: "\(pageCount) pages")) }
        }
        if let certificate, !certificate.isEmpty { parts.append(certificate) }
        if let genre, !genre.isEmpty { parts.append(genre) }
        return parts.joined(separator: " · ")
    }

    static func make(_ item: LibraryItem) -> String {
        make(kind: item.kind, year: item.year, runtimeMinutes: item.runtimeMinutes, pageCount: item.pageCount, genre: item.genres.first)
    }

    /// "Finished ★4½" — what a search row shows when the title is already mine.
    static func libraryState(status: EntryStatus, rating: Int?, kind: MediaKind) -> String {
        guard let rating else { return status.label(for: kind) }
        return "\(status.label(for: kind)) ★\(Rating.starText(rating))"
    }
}
