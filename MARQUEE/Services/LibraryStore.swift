import Foundation
import Observation
import SwiftData

/// Owns my library. Every write goes through here, and every screen reads the
/// in-memory `items` snapshot instead of querying the database while rendering.
@MainActor @Observable
final class LibraryStore {
    private(set) var items: [LibraryTitle] = []
    private(set) var lastError: AppError?
    let context: ModelContext
    private let now: () -> Date
    static let recentlyDeletedDays = 30

    init(context: ModelContext, now: @escaping () -> Date = { Date() }) {
        self.context = context
        self.now = now
        rebuildSnapshot()
    }

    // MARK: Reading

    var activeItems: [LibraryTitle] { items.filter { $0.deletedAt == nil } }
    var recentlyDeleted: [LibraryTitle] {
        items.filter { $0.deletedAt != nil }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    func item(_ uid: String) -> LibraryTitle? { items.first { $0.uid == uid && $0.deletedAt == nil } }

    func counts() -> [MediaKind: Int] {
        Dictionary(grouping: activeItems, by: \.kind).mapValues(\.count)
    }

    // MARK: Writing

    /// Adds a search result. Adding something already in the library never
    /// creates a duplicate; adding something recently deleted restores it.
    @discardableResult
    func add(_ result: SearchResult, status: EntryStatus) -> Bool {
        if let existing = fetchTitle(result.uid) {
            if let entry = existing.entry, entry.deletedAt != nil {
                entry.deletedAt = nil
                entry.statusRaw = status.rawValue
                return save("Restored by re-adding")
            }
            if existing.entry == nil {
                existing.entry = LibraryEntry(status: status, addedAt: now())
                return save("Added entry")
            }
            return false
        }
        let title = Title(uid: result.uid, kind: result.kind, name: result.name)
        title.year = result.year
        title.overview = result.overview
        title.genres = result.genres
        title.creators = result.creator.map { [$0] } ?? []
        title.posterPath = result.posterURL?.absoluteString
        title.backdropPath = result.backdropURL?.absoluteString
        title.runtimeMinutes = result.runtimeMinutes
        title.pageCount = result.pageCount
        title.detailsPending = true
        let entry = LibraryEntry(status: status, addedAt: now())
        if status == .inProgress { entry.startedAt = now() }
        if status == .finished { entry.finishedAt = now() }
        context.insert(title)
        title.entry = entry
        return save("Added \(result.kind.rawValue)")
    }

    /// Undo for an add made moments ago: removes it as if it never happened.
    /// Anything older, or with a diary, goes to Recently deleted instead.
    func discardJustAdded(_ uid: String) {
        guard let title = fetchTitle(uid), let entry = title.entry else { return }
        if now().timeIntervalSince(entry.addedAt) < 120 && entry.diary.isEmpty {
            context.delete(title)
            save("Add undone")
        } else {
            remove(uid)
        }
    }

    func setStatus(_ uid: String, _ status: EntryStatus) {
        guard let entry = fetchTitle(uid)?.entry, entry.statusRaw != status.rawValue else { return }
        entry.statusRaw = status.rawValue
        switch status {
        case .inProgress where entry.startedAt == nil: entry.startedAt = now()
        case .finished: entry.finishedAt = now()
        default: break
        }
        save("Status changed")
    }

    /// Moves a title to Recently deleted. Nothing is permanently deleted here.
    func remove(_ uid: String) {
        guard let entry = fetchTitle(uid)?.entry, entry.deletedAt == nil else { return }
        entry.deletedAt = now()
        save("Moved to Recently deleted")
    }

    func restore(_ uid: String) {
        guard let entry = fetchTitle(uid)?.entry, entry.deletedAt != nil else { return }
        entry.deletedAt = nil
        save("Restored")
    }

    /// Only from Recently deleted's "Delete now", or the 30-day purge.
    func deletePermanently(_ uid: String) {
        guard let title = fetchTitle(uid), title.entry?.deletedAt != nil else { return }
        context.delete(title)
        save("Deleted permanently")
    }

    /// Purges anything removed more than 30 days ago. Runs once at launch.
    func purgeExpired() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.recentlyDeletedDays, to: now()) else { return }
        let expired = allTitles().filter { ($0.entry?.deletedAt).map { $0 < cutoff } ?? false }
        guard !expired.isEmpty else { return }
        for title in expired { context.delete(title) }
        save("Purged \(expired.count) expired")
    }

    /// Fills in details fetched from TMDB or Open Library, keeping anything I've set.
    func apply(_ details: TitleDetails) {
        guard let title = fetchTitle(details.uid) else { return }
        title.name = details.name
        title.originalName = details.originalName
        title.year = details.year ?? title.year
        if !details.overview.isEmpty { title.overview = details.overview }
        if !details.genres.isEmpty { title.genres = details.genres }
        title.runtimeMinutes = details.runtimeMinutes ?? title.runtimeMinutes
        title.pageCount = title.pageCount ?? details.pageCount
        if !details.creators.isEmpty { title.creators = details.creators }
        if let poster = details.posterURL { title.posterPath = poster.absoluteString }
        if let backdrop = details.backdropURL { title.backdropPath = backdrop.absoluteString }
        title.tvStatusRaw = details.tvStatus ?? title.tvStatusRaw
        title.seasonCount = details.seasonCount ?? title.seasonCount
        title.nextAirDate = details.nextAirDate
        title.lastRefreshed = now()
        title.detailsPending = false
        save("Details filled in")
    }

    var pendingDetailUIDs: [String] {
        items.filter { $0.detailsPending && $0.deletedAt == nil }.map(\.uid)
    }

    // MARK: Plumbing

    private func fetchTitle(_ uid: String) -> Title? {
        var descriptor = FetchDescriptor<Title>(predicate: #Predicate { $0.uid == uid })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func allTitles() -> [Title] {
        (try? context.fetch(FetchDescriptor<Title>())) ?? []
    }

    @discardableResult
    private func save(_ what: String) -> Bool {
        do {
            try context.save()
            lastError = nil
            AppLog.info(.data, what)
            rebuildSnapshot()
            return true
        } catch {
            AppLog.error(.data, "Save failed: \(what)")
            lastError = .storage
            context.rollback()
            rebuildSnapshot()
            return false
        }
    }

    func rebuildSnapshot() {
        items = allTitles().compactMap(Self.item(from:))
    }

    static func item(from title: Title) -> LibraryTitle? {
        guard let entry = title.entry, let kind = MediaKind(rawValue: title.kindRaw) else { return nil }
        return LibraryTitle(
            uid: title.uid, kind: kind, name: title.name, year: title.year, creators: title.creators,
            genres: title.genres, overview: title.overview, runtimeMinutes: title.runtimeMinutes,
            pageCount: title.pageCount, posterURL: title.posterPath.flatMap(URL.init(string:)),
            backdropURL: title.backdropPath.flatMap(URL.init(string:)),
            status: EntryStatus(rawValue: entry.statusRaw) ?? .wantTo, rating: Rating.normalised(entry.rating),
            isFavourite: entry.isFavourite, addedAt: entry.addedAt, finishedAt: entry.finishedAt,
            currentPage: entry.currentPage, deletedAt: entry.deletedAt, detailsPending: title.detailsPending)
    }
}
