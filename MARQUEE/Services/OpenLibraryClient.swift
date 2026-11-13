import Foundation

protocol BookService: Sendable {
    func search(_ query: String) async throws -> [SearchResult]
    func popular() async throws -> [SearchResult]
    func details(uid: String) async throws -> TitleDetails
    func ping() async -> Bool
}

/// Open Library: no key needed. Asks only for the fields we use and identifies
/// itself with a descriptive User-Agent, as Open Library requests.
struct OpenLibraryClient: BookService {
    let http: HTTPClient
    let cache: ResponseCache
    let appVersion: String
    private let base = URL(string: "https://openlibrary.org/")!

    static let searchFields = "key,title,author_name,first_publish_year,cover_i,number_of_pages_median,subject,edition_count"

    func search(_ query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: OLSearchResponse = try await get("search.json", ["q": trimmed, "fields": Self.searchFields, "limit": "20"], maxAge: CacheLifetime.search)
        return response.docs.compactMap(\.searchResult)
    }

    func popular() async throws -> [SearchResult] {
        let response: OLTrendingResponse = try await get("trending/weekly.json", ["limit": "12"], maxAge: CacheLifetime.trending)
        return response.works.compactMap(\.searchResult)
    }

    func details(uid: String) async throws -> TitleDetails {
        guard let parsed = TitleUID(uid), case .openLibrary(let key) = parsed.source else { throw AppError.notFound }
        let work: OLWork = try await get("works/\(key).json", [:], maxAge: CacheLifetime.details)
        var authors: [String] = []
        for ref in (work.authors ?? []).prefix(2) {
            let authorKey = ref.author.key.replacingOccurrences(of: "/authors/", with: "")
            if let author: OLAuthor = try? await get("authors/\(authorKey).json", [:], maxAge: CacheLifetime.details) {
                authors.append(author.name)
            }
        }
        return TitleDetails(
            uid: uid, kind: .book, name: work.title, originalName: nil, year: OLDate.year(work.first_publish_date),
            overview: work.description?.text ?? "", genres: Array((work.subjects ?? []).prefix(4)),
            runtimeMinutes: nil, pageCount: nil, creators: authors,
            posterURL: Self.coverURL(work.covers?.first(where: { $0 > 0 }), size: "L"), backdropURL: nil,
            tvStatus: nil, seasonCount: nil, nextAirDate: nil, ukCertificate: nil)
    }

    func ping() async -> Bool {
        guard let url = URL(string: "https://openlibrary.org/search.json?q=dune&limit=1&fields=key") else { return false }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return (try? await http.data(for: request)) != nil
    }

    var userAgent: String { "MARQUEE/\(appVersion) (iOS app; https://github.com/jtoby932-glitch/marquee)" }

    static func coverURL(_ id: Int?, size: String) -> URL? {
        guard let id, id > 0 else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(id)-\(size).jpg?default=false")
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String], maxAge: TimeInterval) async throws -> T {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        var request = URLRequest(url: components?.url ?? base)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let key = request.url?.absoluteString ?? path
        let decoder = JSONDecoder()
        if let cached = await cache.fresh(key, maxAge: maxAge), let value = try? decoder.decode(T.self, from: cached) {
            return value
        }
        do {
            let data = try await http.data(for: request)
            let value = try decoder.decode(T.self, from: data)
            await cache.store(data, for: key)
            return value
        } catch is DecodingError {
            AppLog.error(.network, "Open Library \(path) decode failed")
            throw AppError.decoding
        } catch {
            let mapped = UserFacingError.map(error)
            if mapped == .offline || mapped == .timedOut, let stale = await cache.stale(key), let value = try? decoder.decode(T.self, from: stale) {
                return value
            }
            throw mapped
        }
    }
}

// MARK: - Open Library JSON

struct OLSearchResponse: Decodable {
    let docs: [OLDoc]
}

struct OLTrendingResponse: Decodable {
    let works: [OLDoc]
}

struct OLDoc: Decodable {
    let key: String
    let title: String?
    let author_name: [String]?
    let first_publish_year: Int?
    let cover_i: Int?
    let number_of_pages_median: Int?
    let subject: [String]?
    let edition_count: Int?

    var searchResult: SearchResult? {
        let workKey = key.replacingOccurrences(of: "/works/", with: "")
        guard let title = title?.trimmingCharacters(in: .whitespaces), !title.isEmpty,
              TitleUID("ol-\(workKey)") != nil else { return nil }
        return SearchResult(
            uid: "ol-\(workKey)", kind: .book, name: title, year: first_publish_year, creator: author_name?.first,
            overview: "", posterURL: OpenLibraryClient.coverURL(cover_i, size: "M"), backdropURL: nil,
            genres: Array((subject ?? []).prefix(3)), runtimeMinutes: nil,
            pageCount: (number_of_pages_median ?? 0) > 0 ? number_of_pages_median : nil,
            popularity: Double(edition_count ?? 0))
    }
}

struct OLWork: Decodable {
    struct AuthorRef: Decodable {
        struct Key: Decodable { let key: String }
        let author: Key
    }

    /// Open Library returns descriptions as either a string or `{ "value": … }`.
    enum Description: Decodable {
        case text(String)

        var text: String {
            switch self { case .text(let s): return s }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .text(string)
            } else {
                struct Wrapped: Decodable { let value: String }
                self = .text(try container.decode(Wrapped.self).value)
            }
        }
    }

    let title: String
    let description: Description?
    let subjects: [String]?
    let covers: [Int]?
    let first_publish_date: String?
    let authors: [AuthorRef]?
}

struct OLAuthor: Decodable {
    let name: String
}

enum OLDate {
    /// Pulls a four-digit year out of strings like "1965", "August 1965" or "1 Aug 1965".
    static func year(_ string: String?) -> Int? {
        guard let string else { return nil }
        let digits = string.split(whereSeparator: { !$0.isNumber })
        return digits.compactMap { Int($0) }.first { $0 > 1000 && $0 < 3000 }
    }
}
