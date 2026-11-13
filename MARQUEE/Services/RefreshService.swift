import Foundation

/// Fills in and refreshes title details in the background. Never blocks launch
/// or the UI; anything added offline is queued and filled in later.
@MainActor
final class RefreshService {
    private let store: LibraryStore
    private let filmTV: FilmTVService
    private let books: BookService
    private var running = false

    init(store: LibraryStore, filmTV: FilmTVService, books: BookService) {
        self.store = store
        self.filmTV = filmTV
        self.books = books
    }

    /// Fetches details for everything still pending, a few at a time.
    func fillPending() async {
        guard !running else { return }
        running = true
        defer { running = false }
        for uid in store.pendingDetailUIDs.prefix(25) {
            if Task.isCancelled { return }
            await fill(uid)
        }
    }

    func fill(_ uid: String) async {
        guard let kind = TitleUID(uid)?.kind else { return }
        if kind.isScreen && !filmTV.hasKey { return }
        do {
            let details = try await (kind == .book ? books.details(uid: uid) : filmTV.details(uid: uid))
            store.apply(details)
        } catch {
            AppLog.info(.network, "Details not filled yet (\(UserFacingError.map(error)))")
        }
    }
}
