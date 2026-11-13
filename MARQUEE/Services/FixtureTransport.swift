import Foundation

/// Answers network requests from bundled JSON so screenshots and UI tests are
/// repeatable and never touch the real network. Only used with `-stubNetwork`.
struct FixtureTransport: HTTPTransport {
    var bundle: Bundle = .main
    /// Simulated delay, for testing slow connections.
    var delay: Double = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        guard let url = request.url else { throw AppError.notFound }
        let name = Self.fixtureName(for: url)
        let data = name.flatMap { bundle.url(forResource: $0, withExtension: "json") }.flatMap { try? Data(contentsOf: $0) }
        let status = data == nil ? 404 : 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        guard let response else { throw AppError.server(status: -1) }
        return (data ?? Data(), response)
    }

    /// Maps a request to a fixture file name, or nil for a 404.
    static func fixtureName(for url: URL) -> String? {
        let path = url.path
        switch url.host {
        case "api.themoviedb.org":
            if path.hasSuffix("/search/multi") { return "fixture-tmdb-search" }
            if path.hasSuffix("/trending/all/week") { return "fixture-tmdb-trending" }
            if path.hasSuffix("/configuration") { return "fixture-tmdb-configuration" }
            if let id = path.split(separator: "/").last, path.contains("/movie/") { return "fixture-tmdb-movie-\(id)" }
            if let id = path.split(separator: "/").last, path.contains("/tv/") { return "fixture-tmdb-tv-\(id)" }
            return nil
        case "openlibrary.org":
            if path == "/search.json" { return "fixture-ol-search" }
            if path == "/trending/weekly.json" { return "fixture-ol-trending" }
            if path.hasPrefix("/works/") { return "fixture-ol-work-" + url.deletingPathExtension().lastPathComponent }
            if path.hasPrefix("/authors/") { return "fixture-ol-author" }
            return nil
        default:
            return nil
        }
    }
}
