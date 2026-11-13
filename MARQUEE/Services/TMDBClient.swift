import Foundation

/// Full details for one Title, used to fill in or refresh the library record.
struct TitleDetails: Equatable {
    var uid: String
    var kind: MediaKind
    var name: String
    var originalName: String?
    var year: Int?
    var overview: String
    var genres: [String]
    var runtimeMinutes: Int?
    var pageCount: Int?
    var creators: [String]
    var posterURL: URL?
    var backdropURL: URL?
    var tvStatus: String?
    var seasonCount: Int?
    var nextAirDate: Date?
    var ukCertificate: String?
}

protocol FilmTVService: Sendable {
    var hasKey: Bool { get }
    func search(_ query: String) async throws -> [SearchResult]
    func trending() async throws -> [SearchResult]
    func details(uid: String) async throws -> TitleDetails
    func ping() async -> Bool
}

/// TMDB v3 with the Bearer read token, en-GB and region GB.
struct TMDBClient: FilmTVService {
    let http: HTTPClient
    let cache: ResponseCache
    let token: String
    private let base = URL(string: "https://api.themoviedb.org/3/")!
    static let imageBase = "https://image.tmdb.org/t/p/"

    var hasKey: Bool { !token.trimmingCharacters(in: .whitespaces).isEmpty }

    func search(_ query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let page: TMDBPage = try await get("search/multi", ["query": trimmed, "include_adult": "false"], maxAge: CacheLifetime.search)
        return page.results.compactMap(\.searchResult)
    }

    func trending() async throws -> [SearchResult] {
        let page: TMDBPage = try await get("trending/all/week", [:], maxAge: CacheLifetime.trending)
        return page.results.compactMap(\.searchResult)
    }

    func details(uid: String) async throws -> TitleDetails {
        guard let parsed = TitleUID(uid) else { throw AppError.notFound }
        switch parsed.source {
        case .tmdbMovie(let id):
            let movie: TMDBMovie = try await get("movie/\(id)", ["append_to_response": "credits,release_dates"], maxAge: CacheLifetime.details)
            return movie.details(uid: uid)
        case .tmdbTV(let id):
            let show: TMDBShow = try await get("tv/\(id)", ["append_to_response": "credits"], maxAge: CacheLifetime.details)
            return show.details(uid: uid)
        case .openLibrary:
            throw AppError.notFound
        }
    }

    func ping() async -> Bool {
        guard hasKey else { return false }
        do {
            let _: TMDBConfiguration = try await get("configuration", [:], maxAge: CacheLifetime.configuration)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Plumbing

    func request(_ path: String, _ query: [String: String]) -> URLRequest {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        let items = query.merging(["language": "en-GB", "region": "GB"]) { current, _ in current }
        components?.queryItems = items.keys.sorted().map { URLQueryItem(name: $0, value: items[$0]) }
        var request = URLRequest(url: components?.url ?? base)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String], maxAge: TimeInterval) async throws -> T {
        guard hasKey else { throw AppError.missingTMDBKey }
        let request = request(path, query)
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
        } catch let error as DecodingError {
            AppLog.error(.network, "TMDB \(path) decode failed: \(error.localizedDescription)")
            throw AppError.decoding
        } catch {
            let mapped = UserFacingError.map(error)
            if mapped == .offline || mapped == .timedOut, let stale = await cache.stale(key), let value = try? decoder.decode(T.self, from: stale) {
                return value
            }
            throw mapped
        }
    }

    static func imageURL(_ path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: imageBase + size + path)
    }
}

// MARK: - TMDB JSON

struct TMDBConfiguration: Decodable {
    struct Images: Decodable { let secure_base_url: String }
    let images: Images
}

struct TMDBPage: Decodable {
    let results: [TMDBListItem]
}

struct TMDBListItem: Decodable {
    let id: Int
    let media_type: String?
    let title: String?
    let name: String?
    let release_date: String?
    let first_air_date: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let popularity: Double?
    let genre_ids: [Int]?

    var searchResult: SearchResult? {
        let kind: MediaKind
        switch media_type {
        case "movie": kind = .film
        case "tv": kind = .show
        default: return nil
        }
        guard let name = (title ?? name)?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return nil }
        return SearchResult(
            uid: kind == .film ? "tmdb-movie-\(id)" : "tmdb-tv-\(id)",
            kind: kind, name: name, year: TMDBDate.year(release_date ?? first_air_date), creator: nil,
            overview: overview ?? "",
            posterURL: TMDBClient.imageURL(poster_path, size: "w342"),
            backdropURL: TMDBClient.imageURL(backdrop_path, size: "w1280"),
            genres: (genre_ids ?? []).compactMap { TMDBGenres.names[$0] },
            runtimeMinutes: nil, pageCount: nil, popularity: popularity ?? 0)
    }
}

struct TMDBGenre: Decodable { let name: String }
struct TMDBPerson: Decodable { let name: String; let job: String? }
struct TMDBCredits: Decodable { let crew: [TMDBPerson]? }

struct TMDBMovie: Decodable {
    struct ReleaseDates: Decodable {
        struct Country: Decodable {
            struct Release: Decodable { let certification: String? }
            let iso_3166_1: String
            let release_dates: [Release]
        }
        let results: [Country]
    }

    let id: Int
    let title: String
    let original_title: String?
    let release_date: String?
    let overview: String?
    let runtime: Int?
    let genres: [TMDBGenre]?
    let poster_path: String?
    let backdrop_path: String?
    let credits: TMDBCredits?
    let release_dates: ReleaseDates?

    func details(uid: String) -> TitleDetails {
        let directors = (credits?.crew ?? []).filter { $0.job == "Director" }.map(\.name)
        let gb = release_dates?.results.first(where: { $0.iso_3166_1 == "GB" })
        let uk = gb?.release_dates.compactMap(\.certification).first(where: { !$0.isEmpty })
        return TitleDetails(
            uid: uid, kind: .film, name: title, originalName: original_title == title ? nil : original_title,
            year: TMDBDate.year(release_date), overview: overview ?? "", genres: (genres ?? []).map(\.name),
            runtimeMinutes: (runtime ?? 0) > 0 ? runtime : nil, pageCount: nil, creators: directors,
            posterURL: TMDBClient.imageURL(poster_path, size: "w780"), backdropURL: TMDBClient.imageURL(backdrop_path, size: "w1280"),
            tvStatus: nil, seasonCount: nil, nextAirDate: nil, ukCertificate: uk)
    }
}

struct TMDBShow: Decodable {
    struct Creator: Decodable { let name: String }
    struct Episode: Decodable { let air_date: String? }

    let id: Int
    let name: String
    let original_name: String?
    let first_air_date: String?
    let overview: String?
    let episode_run_time: [Int]?
    let genres: [TMDBGenre]?
    let poster_path: String?
    let backdrop_path: String?
    let created_by: [Creator]?
    let status: String?
    let number_of_seasons: Int?
    let next_episode_to_air: Episode?

    func details(uid: String) -> TitleDetails {
        let runtimes = (episode_run_time ?? []).filter { $0 > 0 }
        let average = runtimes.isEmpty ? nil : runtimes.reduce(0, +) / runtimes.count
        return TitleDetails(
            uid: uid, kind: .show, name: name, originalName: original_name == name ? nil : original_name,
            year: TMDBDate.year(first_air_date), overview: overview ?? "", genres: (genres ?? []).map(\.name),
            runtimeMinutes: average, pageCount: nil, creators: (created_by ?? []).map(\.name),
            posterURL: TMDBClient.imageURL(poster_path, size: "w780"), backdropURL: TMDBClient.imageURL(backdrop_path, size: "w1280"),
            tvStatus: (status == "Ended" || status == "Canceled") ? "ended" : "returning",
            seasonCount: number_of_seasons, nextAirDate: TMDBDate.date(next_episode_to_air?.air_date), ukCertificate: nil)
    }
}

enum TMDBDate {
    static func year(_ string: String?) -> Int? {
        guard let string, string.count >= 4, let year = Int(string.prefix(4)), year > 1800 else { return nil }
        return year
    }

    /// TMDB air dates have no time: an episode counts as aired from the start of that day in my timezone.
    static func date(_ string: String?, calendar: Calendar = AppCalendar.calendar()) -> Date? {
        guard let string else { return nil }
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// TMDB's fixed genre IDs for films and TV, in British English.
enum TMDBGenres {
    static let names: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime", 99: "Documentary",
        18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
        9648: "Mystery", 10749: "Romance", 878: "Sci-fi", 10770: "TV film", 53: "Thriller", 10752: "War",
        37: "Western", 10759: "Action & adventure", 10762: "Kids", 10763: "News", 10764: "Reality",
        10765: "Sci-fi & fantasy", 10766: "Soap", 10767: "Talk", 10768: "War & politics",
    ]
}
