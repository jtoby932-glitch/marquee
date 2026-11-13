import Foundation
import Observation

/// Drives the Search screen: debounced, cancellable requests to TMDB and
/// Open Library, grouped results, and an offline fallback to my own library.
@MainActor @Observable
final class SearchModel {
    enum Phase: Equatable {
        case idle
        case loading
        case results
        case empty
        case failed(UserFacingError.Message)
    }

    /// Set by the field; the view calls `queryChanged()` / `filterChanged()` on change.
    var query = ""
    var filter: SearchFilter = .all
    private(set) var phase: Phase = .idle
    private(set) var sections: [SearchSection] = []
    private(set) var trending: [SearchResult] = []
    private(set) var popularBooks: [SearchResult] = []
    private(set) var filmTVUnavailable: UserFacingError.Message?
    private(set) var recentSearches: [String] = []

    @ObservationIgnored private var raw: [SearchResult] = []
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    private let filmTV: FilmTVService
    private let books: BookService
    private let defaults: UserDefaults
    @ObservationIgnored var enabledKinds: Set<MediaKind> = Set(MediaKind.allCases)
    @ObservationIgnored var debounce: Double = 0.3
    static let recentKey = "search.recent"

    init(filmTV: FilmTVService, books: BookService, defaults: UserDefaults = .standard) {
        self.filmTV = filmTV
        self.books = books
        self.defaults = defaults
        recentSearches = defaults.stringArray(forKey: Self.recentKey) ?? []
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Loads the empty-state rows: trending films and TV, popular books.
    func loadDiscovery() async {
        let filmTV = self.filmTV, books = self.books
        async let films = Self.capture(enabled: filmTV.hasKey) { try await filmTV.trending() }
        async let popular = Self.capture(enabled: true) { try await books.popular() }
        let f = (try? await films.get()) ?? []
        let p = (try? await popular.get()) ?? []
        trending = f.filter { enabledKinds.contains($0.kind) }
        popularBooks = enabledKinds.contains(.book) ? p : []
    }

    func retry() { scheduleSearch(immediately: true) }

    func queryChanged() { scheduleSearch() }

    func filterChanged() { regroup() }

    private func scheduleSearch(immediately: Bool = false) {
        searchTask?.cancel()
        let text = trimmedQuery
        guard !text.isEmpty else {
            raw = []
            sections = []
            phase = .idle
            return
        }
        phase = .loading
        let delay = immediately ? 0 : debounce
        searchTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled, let self else { return }
            await self.run(text)
        }
    }

    private func run(_ text: String) async {
        let filmTV = self.filmTV, books = self.books
        let wantsScreen = enabledKinds.contains(.film) || enabledKinds.contains(.show)
        let wantsBooks = enabledKinds.contains(.book)
        async let screen = Self.capture(enabled: wantsScreen) { try await filmTV.search(text) }
        async let bookResults = Self.capture(enabled: wantsBooks) { try await books.search(text) }
        let s = await screen
        let b = await bookResults
        guard !Task.isCancelled, text == trimmedQuery else { return }

        var combined: [SearchResult] = []
        var errors: [Error] = []
        switch s {
        case .success(let r): combined += r; filmTVUnavailable = nil
        case .failure(let e):
            errors.append(e)
            let mapped = UserFacingError.map(e)
            filmTVUnavailable = (mapped == .missingTMDBKey || mapped == .invalidTMDBKey) ? UserFacingError.message(for: mapped) : nil
        }
        switch b {
        case .success(let r): combined += r
        case .failure(let e): errors.append(e)
        }
        raw = combined
        regroup()
        if sections.isEmpty {
            let realErrors = errors.map(UserFacingError.map).filter { $0 != .missingTMDBKey && $0 != .cancelled }
            if let first = realErrors.first {
                phase = .failed(UserFacingError.message(for: first))
            } else {
                phase = .empty
            }
        }
        remember(text)
        AppLog.info(.network, "Search finished: \(combined.count) results")
    }

    private func regroup() {
        sections = SearchRanking.sections(raw, query: trimmedQuery, filter: filter, enabledKinds: enabledKinds)
        if !trimmedQuery.isEmpty, !raw.isEmpty {
            phase = sections.isEmpty ? .empty : .results
        }
    }

    private func remember(_ text: String) {
        var list = recentSearches.filter { $0.caseInsensitiveCompare(text) != .orderedSame }
        list.insert(text, at: 0)
        recentSearches = Array(list.prefix(8))
        defaults.set(recentSearches, forKey: Self.recentKey)
    }

    /// Runs a request, turning a thrown error into a value so both sources can finish.
    private static func capture(enabled: Bool, _ body: @Sendable () async throws -> [SearchResult]) async -> Result<[SearchResult], Error> {
        guard enabled else { return .success([]) }
        do {
            return .success(try await body())
        } catch {
            return .failure(error)
        }
    }

    func clearRecent() {
        recentSearches = []
        defaults.removeObject(forKey: Self.recentKey)
    }
}

