import Foundation

/// Everything the hidden Diagnostics screen shows, and the text "Copy
/// diagnostics" puts on the clipboard. Holds no review text or other personal writing.
struct DiagnosticsReport: Equatable {
    var appVersion: String
    var build: String
    var schemaVersion: String
    var iOSVersion: String
    var device: String
    var counts: [MediaKind: Int]
    var deletedCount: Int
    var imageCacheBytes: Int
    var lastRefresh: Date?
    var tmdbKeyPresent: Bool
    var tmdbReachable: Bool?
    var openLibraryReachable: Bool?
    var lastBackup: Date?
    var logLines: [String]

    var summary: String {
        func yesNo(_ value: Bool?) -> String {
            switch value {
            case .some(true): return "ok"
            case .some(false): return "failed"
            case .none: return "not checked"
            }
        }
        let date: (Date?) -> String = { $0.map { ISO8601DateFormatter().string(from: $0) } ?? "never" }
        var lines = [
            "MARQUEE \(appVersion) (\(build)), schema \(schemaVersion)",
            "iOS \(iOSVersion), \(device)",
            "Library: \(counts[.film, default: 0]) films, \(counts[.show, default: 0]) shows, \(counts[.book, default: 0]) books, \(deletedCount) recently deleted",
            "Image cache: \(ByteCountFormatter.string(fromByteCount: Int64(imageCacheBytes), countStyle: .file))",
            "Last refresh: \(date(lastRefresh))",
            "TMDB key: \(tmdbKeyPresent ? "present" : "missing"), TMDB: \(yesNo(tmdbReachable)), Open Library: \(yesNo(openLibraryReachable))",
            "Last backup: \(date(lastBackup))",
            "",
            "Recent log (\(logLines.count) lines):",
        ]
        lines.append(contentsOf: logLines)
        return lines.joined(separator: "\n")
    }

    /// The text copied by "Report a problem": my answers, then the diagnostics.
    func problemReport(whatHappened: String, expected: String) -> String {
        """
        What happened:
        \(whatHappened.trimmingCharacters(in: .whitespacesAndNewlines))

        What I expected:
        \(expected.trimmingCharacters(in: .whitespacesAndNewlines))

        ---
        \(summary)
        """
    }
}
