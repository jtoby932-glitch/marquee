import SwiftData
import XCTest
@testable import MARQUEE

@MainActor
final class LibraryStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        container = try MarqueeStore.makeContainer(inMemory: true)
    }

    private func store() -> LibraryStore {
        LibraryStore(context: container.mainContext, now: { [unowned self] in self.clock })
    }

    private func dune(_ uid: String = "tmdb-movie-438631") -> SearchResult {
        SearchResult(uid: uid, kind: .film, name: "Dune", year: 2021, creator: "Denis Villeneuve", overview: "Spice.",
                     posterURL: URL(string: "https://image.tmdb.org/t/p/w342/x.jpg"), backdropURL: nil, genres: ["Sci-fi"],
                     runtimeMinutes: 155, pageCount: nil, popularity: 1)
    }

    func testAddingTwiceKeepsOne() {
        let library = store()
        XCTAssertTrue(library.add(dune(), status: .wantTo))
        XCTAssertFalse(library.add(dune(), status: .finished), "Second add is refused")
        XCTAssertEqual(library.activeItems.count, 1)
        XCTAssertEqual(library.item("tmdb-movie-438631")?.status, .wantTo)
        XCTAssertTrue(library.item("tmdb-movie-438631")?.detailsPending ?? false, "Details queued for later")
    }

    func testSnapshotReflectsChangesImmediately() {
        let library = store()
        library.add(dune(), status: .wantTo)
        library.setStatus("tmdb-movie-438631", .finished)
        XCTAssertEqual(library.item("tmdb-movie-438631")?.status, .finished)
        XCTAssertNotNil(library.item("tmdb-movie-438631")?.finishedAt)
        XCTAssertEqual(library.counts()[.film], 1)
    }

    func testRemoveGoesToRecentlyDeletedAndRestores() {
        let library = store()
        library.add(dune(), status: .finished)
        library.remove("tmdb-movie-438631")
        XCTAssertNil(library.item("tmdb-movie-438631"))
        XCTAssertEqual(library.recentlyDeleted.map(\.uid), ["tmdb-movie-438631"])
        library.restore("tmdb-movie-438631")
        XCTAssertNotNil(library.item("tmdb-movie-438631"))
        XCTAssertTrue(library.recentlyDeleted.isEmpty)
    }

    func testReAddingSomethingDeletedRestoresIt() {
        let library = store()
        library.add(dune(), status: .finished)
        library.remove("tmdb-movie-438631")
        XCTAssertTrue(library.add(dune(), status: .wantTo))
        XCTAssertEqual(library.activeItems.count, 1)
        XCTAssertEqual(library.item("tmdb-movie-438631")?.status, .wantTo)
    }

    func testPermanentDeleteOnlyFromRecentlyDeleted() {
        let library = store()
        library.add(dune(), status: .finished)
        library.deletePermanently("tmdb-movie-438631")
        XCTAssertNotNil(library.item("tmdb-movie-438631"), "Never deletes something that isn't in Recently deleted")
        library.remove("tmdb-movie-438631")
        library.deletePermanently("tmdb-movie-438631")
        XCTAssertTrue(library.items.isEmpty)
    }

    func testPurgesOnlyAfterThirtyDays() {
        let library = store()
        library.add(dune(), status: .finished)
        library.add(dune("tmdb-movie-1"), status: .finished)
        library.remove("tmdb-movie-438631")
        clock.addTimeInterval(20 * 86_400)
        library.remove("tmdb-movie-1")
        clock.addTimeInterval(11 * 86_400)
        library.purgeExpired()
        XCTAssertEqual(library.recentlyDeleted.map(\.uid), ["tmdb-movie-1"])
    }

    func testUndoingAnAddLeavesNoTrace() {
        let library = store()
        library.add(dune(), status: .wantTo)
        library.discardJustAdded("tmdb-movie-438631")
        XCTAssertTrue(library.items.isEmpty)
        XCTAssertTrue(library.recentlyDeleted.isEmpty)
    }

    func testApplyingDetailsKeepsWhatIsMine() {
        let library = store()
        library.add(dune(), status: .finished)
        library.apply(TitleDetails(uid: "tmdb-movie-438631", kind: .film, name: "Dune", originalName: nil, year: 2021, overview: "",
                                   genres: [], runtimeMinutes: 156, pageCount: nil, creators: [], posterURL: nil, backdropURL: nil,
                                   tvStatus: nil, seasonCount: nil, nextAirDate: nil, ukCertificate: "12A"))
        let item = library.item("tmdb-movie-438631")
        XCTAssertEqual(item?.runtimeMinutes, 156)
        XCTAssertEqual(item?.overview, "Spice.", "An empty overview never wipes the one we have")
        XCTAssertEqual(item?.creators, ["Denis Villeneuve"])
        XCTAssertEqual(item?.status, .finished)
        XCTAssertFalse(item?.detailsPending ?? true)
    }

    func testLargeLibrarySnapshot() {
        let library = store()
        for i in 1...2000 {
            library.context.insert(Title(uid: "tmdb-movie-\(i)", kind: .film, name: "Film \(i)"))
        }
        try? library.context.save()
        let titles = (try? library.context.fetch(FetchDescriptor<Title>())) ?? []
        for title in titles { title.entry = LibraryEntry(status: .finished, addedAt: clock) }
        try? library.context.save()
        measure { library.rebuildSnapshot() }
        XCTAssertEqual(library.activeItems.count, 2000)
    }
}

@MainActor
final class StoreSetupTests: XCTestCase {
    func testSchemaOpensAndMigrationPlanCoversIt() throws {
        let container = try MarqueeStore.makeContainer(inMemory: true)
        XCTAssertNotNil(container)
        XCTAssertEqual(MarqueeMigrationPlan.schemas.count, 1)
        XCTAssertEqual(MarqueeStore.schemaVersion, "1.0.0")
    }

    func testDemoDataSeedsAnInMemoryStore() throws {
        let options = LaunchOptions(arguments: ["-demoData"])
        XCTAssertTrue(options.usesInMemoryStore, "Demo data must never touch the real store")
        XCTAssertTrue(options.stubNetwork)
        let container = try MarqueeStore.makeContainer(inMemory: true)
        DemoData.seed(into: container.mainContext, now: Date())
        let library = LibraryStore(context: container.mainContext)
        XCTAssertGreaterThan(library.activeItems.count, 250)
        XCTAssertEqual(Set(library.activeItems.map(\.uid)).count, library.activeItems.count)
        XCTAssertEqual(library.item("tmdb-movie-693134")?.rating, 9)
    }

    func testLaunchOptions() {
        let o = LaunchOptions(arguments: ["app", "-screen", "library", "-look", "paper", "-animation", "off"])
        XCTAssertEqual(o.screen, "library")
        XCTAssertEqual(o.look, .paper)
        XCTAssertEqual(o.animationLevel, .off)
        XCTAssertTrue(o.skipIntro)
        XCTAssertFalse(LaunchOptions(arguments: ["-screen", "launch"]).skipIntro)
        XCTAssertFalse(LaunchOptions(arguments: []).usesInMemoryStore)
    }

    func testPreferencesPersistAndClamp() throws {
        let container = try MarqueeStore.makeContainer(inMemory: true)
        let prefs = PreferencesStore(context: container.mainContext)
        XCTAssertEqual(prefs.look, .cinema)
        XCTAssertEqual(prefs.gridColumns, 3)
        prefs.setLook(.paper)
        prefs.setGridColumns(9)
        let again = PreferencesStore(context: container.mainContext)
        XCTAssertEqual(again.look, .paper)
        XCTAssertEqual(again.gridColumns, 4)
        let records = try container.mainContext.fetch(FetchDescriptor<Preferences>())
        XCTAssertEqual(records.count, 1, "Only ever one preferences record")
    }
}
