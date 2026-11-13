import XCTest
@testable import MARQUEE

final class RatingTests: XCTestCase {
    func testStoredAsHalfStars() {
        XCTAssertEqual(Rating.fromStars(4.5), 9)
        XCTAssertEqual(Rating.fromStars(0.5), 1)
        XCTAssertEqual(Rating.fromStars(5), 10)
        XCTAssertNil(Rating.fromStars(0))
        XCTAssertNil(Rating.fromStars(.nan))
        XCTAssertEqual(Rating.fromStars(7), 10, "Clamps above five stars")
    }

    func testNormalisedTreatsZeroAsUnrated() {
        XCTAssertNil(Rating.normalised(0))
        XCTAssertNil(Rating.normalised(-3))
        XCTAssertEqual(Rating.normalised(12), 10)
        XCTAssertEqual(Rating.normalised(7), 7)
    }

    func testStarText() {
        XCTAssertEqual(Rating.starText(9), "4½")
        XCTAssertEqual(Rating.starText(1), "½")
        XCTAssertEqual(Rating.starText(10), "5")
        XCTAssertEqual(Rating.display(9, style: .outOfTen), "9/10")
    }

    func testSpokenRating() {
        XCTAssertEqual(Rating.spoken(9), "rated 4 and a half stars")
        XCTAssertEqual(Rating.spoken(2), "rated 1 star")
        XCTAssertEqual(Rating.spoken(1), "rated half a star")
    }
}

final class TitleUIDTests: XCTestCase {
    func testParsesEverySource() {
        XCTAssertEqual(TitleUID("tmdb-movie-603")?.kind, .film)
        XCTAssertEqual(TitleUID("tmdb-tv-1399")?.kind, .show)
        XCTAssertEqual(TitleUID("ol-OL82563W")?.kind, .book)
        XCTAssertEqual(TitleUID("tmdb-movie-603")?.description, "tmdb-movie-603")
    }

    func testRejectsGarbage() {
        for bad in ["", "tmdb-movie-", "tmdb-movie-abc", "tmdb-movie--4", "ol-", "ol-12345", "ol-OL1/../x", "imdb-tt123"] {
            XCTAssertNil(TitleUID(bad), bad)
        }
    }
}

final class LibraryQueryTests: XCTestCase {
    private func item(_ uid: String, _ name: String, kind: MediaKind = .film, status: EntryStatus = .finished,
                      rating: Int? = nil, year: Int? = nil, added: Double = 0, finished: Double? = nil, deleted: Bool = false) -> LibraryTitle {
        LibraryTitle(uid: uid, kind: kind, name: name, year: year, creators: ["Someone"], genres: [], overview: "",
                    runtimeMinutes: nil, pageCount: nil, posterURL: nil, backdropURL: nil, status: status, rating: rating,
                    isFavourite: false, addedAt: Date(timeIntervalSince1970: added),
                    finishedAt: finished.map { Date(timeIntervalSince1970: $0) }, currentPage: nil,
                    deletedAt: deleted ? Date() : nil, detailsPending: false)
    }

    func testFiltersCombine() {
        let items = [
            item("a", "Alien", status: .finished),
            item("b", "Arrival", status: .wantTo),
            item("c", "Atonement", kind: .book, status: .wantTo),
            item("d", "Aliens", status: .finished, deleted: true),
        ]
        let result = LibraryQuery(kind: .film, status: .finished).apply(to: items)
        XCTAssertEqual(result.map(\.uid), ["a"], "Deleted items never appear")
        XCTAssertEqual(LibraryQuery(kind: nil, status: .wantTo).apply(to: items).count, 2)
        XCTAssertEqual(LibraryQuery(text: "someone").apply(to: items).count, 3, "Matches creators too")
    }

    func testSortsAreStable() {
        let items = [item("a", "The Zebra", rating: 6, year: 2001, added: 3, finished: 5), item("b", "Apple", rating: 9, year: 1999, added: 1),
                     item("c", "A Bear", rating: 9, year: 2001, added: 2, finished: 9)]
        XCTAssertEqual(LibraryQuery(sort: .title).apply(to: items).map(\.uid), ["b", "c", "a"], "Ignores leading articles")
        XCTAssertEqual(LibraryQuery(sort: .rating).apply(to: items).map(\.uid), ["b", "c", "a"])
        XCTAssertEqual(LibraryQuery(sort: .added).apply(to: items).map(\.uid), ["a", "c", "b"])
        XCTAssertEqual(LibraryQuery(sort: .finished).apply(to: items).map(\.uid), ["c", "a", "b"], "Unfinished last")
        XCTAssertEqual(LibraryQuery(sort: .year).apply(to: items).map(\.uid), ["c", "a", "b"])
    }

    func testAccessibilityDescription() {
        let dune = item("x", "Dune: Part Two", status: .finished, rating: 9, year: 2024)
        XCTAssertEqual(dune.accessibilityDescription, "Dune: Part Two, 2024, film, finished, rated 4 and a half stars")
    }
}

final class SearchRankingTests: XCTestCase {
    private func result(_ uid: String, _ name: String, _ kind: MediaKind, _ popularity: Double) -> SearchResult {
        SearchResult(uid: uid, kind: kind, name: name, year: nil, creator: nil, overview: "", posterURL: nil, backdropURL: nil,
                     genres: [], runtimeMinutes: nil, pageCount: nil, popularity: popularity)
    }

    func testGroupsExactMatchesFirstAndDropsDuplicates() {
        let results = [result("tmdb-movie-2", "Dune: Part Two", .film, 300), result("tmdb-movie-1", "Dune", .film, 100),
                       result("tmdb-movie-1", "Dune", .film, 100), result("ol-OL1W", "Dune", .book, 50)]
        let sections = SearchRanking.sections(results, query: "dune", filter: .all, enabledKinds: Set(MediaKind.allCases))
        XCTAssertEqual(sections.map(\.kind), [.film, .book])
        XCTAssertEqual(sections[0].results.map(\.uid), ["tmdb-movie-1", "tmdb-movie-2"])
    }

    func testRespectsFilterAndDisabledKinds() {
        let results = [result("tmdb-movie-1", "Dune", .film, 1), result("ol-OL1W", "Dune", .book, 1)]
        XCTAssertEqual(SearchRanking.sections(results, query: "dune", filter: .books, enabledKinds: Set(MediaKind.allCases)).map(\.kind), [.book])
        XCTAssertEqual(SearchRanking.sections(results, query: "dune", filter: .all, enabledKinds: [.book]).map(\.kind), [.book])
    }
}

final class DeepLinkTests: XCTestCase {
    func testParsesLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "marquee://title/tmdb-movie-603")!), .title(uid: "tmdb-movie-603"))
        XCTAssertEqual(DeepLink(url: URL(string: "marquee://season/tmdb-tv-1399/2")!), .season(uid: "tmdb-tv-1399", number: 2))
        XCTAssertEqual(DeepLink(url: URL(string: "marquee://search?q=dune%20two")!), .search(query: "dune two"))
        XCTAssertEqual(DeepLink(url: URL(string: "marquee://decide")!), .decide)
        XCTAssertEqual(DeepLink(url: URL(string: "marquee://timer/ol-OL893415W")!), .timer(uid: "ol-OL893415W"))
    }

    func testRejectsBadLinks() {
        XCTAssertNil(DeepLink(url: URL(string: "marquee://title/nonsense")!))
        XCTAssertNil(DeepLink(url: URL(string: "marquee://season/tmdb-movie-603/1")!), "Films have no seasons")
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com/title/tmdb-movie-603")!))
        XCTAssertNil(DeepLink(url: URL(string: "marquee://timer/tmdb-movie-603")!), "Timers are for books")
    }

    func testRoundTrips() {
        for link in [DeepLink.title(uid: "tmdb-tv-1"), .search(query: "a & b"), .decide] {
            XCTAssertEqual(link.url.flatMap(DeepLink.init(url:)), link)
        }
    }
}

final class AppCalendarTests: XCTestCase {
    private let london = AppCalendar.calendar(timeZone: TimeZone(identifier: "Europe/London")!)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        london.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testWeeksStartOnMonday() {
        XCTAssertEqual(london.firstWeekday, 2)
    }

    func testGreeting() {
        XCTAssertEqual(AppCalendar.greeting(at: date(2026, 11, 12, 19), name: "Toby", calendar: london), "Good evening, Toby")
        XCTAssertEqual(AppCalendar.greeting(at: date(2026, 11, 12, 8), name: "  ", calendar: london), "Good morning")
        XCTAssertEqual(AppCalendar.greeting(at: date(2026, 11, 12, 14), name: nil, calendar: london), "Good afternoon")
    }

    func testEyebrowAndShortDates() {
        XCTAssertEqual(AppCalendar.eyebrowDate(date(2026, 11, 12), calendar: london), "THURSDAY 12 NOVEMBER")
        XCTAssertEqual(AppCalendar.shortDate(date(2026, 11, 12), calendar: london), "12 Nov 2026")
    }

    func testRuntime() {
        XCTAssertEqual(AppCalendar.runtime(166), "2 h 46 m")
        XCTAssertEqual(AppCalendar.runtime(48), "48 m")
        XCTAssertEqual(AppCalendar.runtime(120), "2 h")
        XCTAssertEqual(AppCalendar.runtime(0), "")
    }

    func testAirDatesStartAtLocalMidnightAcrossClockChange() {
        // 29 March 2026 is when the UK clocks go forward.
        let d = TMDBDate.date("2026-03-29", calendar: london)!
        XCTAssertEqual(london.component(.hour, from: d), 0)
        XCTAssertEqual(london.component(.day, from: d), 29)
        XCTAssertNil(TMDBDate.date("2026-03", calendar: london))
    }
}

final class MetaLineTests: XCTestCase {
    func testMetaLines() {
        XCTAssertEqual(MetaLine.make(kind: .film, year: 2024, runtimeMinutes: 166, pageCount: nil, genre: "Sci-fi", certificate: "12A"),
                       "2024 · 2 h 46 m · 12A · Sci-fi")
        XCTAssertEqual(MetaLine.make(kind: .book, year: 1965, runtimeMinutes: nil, pageCount: 658, genre: nil), "1965 · 658 pages")
        XCTAssertEqual(MetaLine.make(kind: .show, year: nil, runtimeMinutes: nil, pageCount: nil, genre: nil), "")
        XCTAssertEqual(MetaLine.libraryState(status: .finished, rating: 9, kind: .film), "Watched ★4½")
    }
}

final class HomeSectionsTests: XCTestCase {
    func testGroupsAndHidesDisabledKinds() {
        func item(_ uid: String, _ kind: MediaKind, _ status: EntryStatus, added: Double) -> LibraryTitle {
            LibraryTitle(uid: uid, kind: kind, name: uid, year: nil, creators: [], genres: [], overview: "", runtimeMinutes: nil,
                        pageCount: nil, posterURL: nil, backdropURL: nil, status: status, rating: nil, isFavourite: false,
                        addedAt: Date(timeIntervalSince1970: added), finishedAt: nil, currentPage: nil, deletedAt: nil, detailsPending: false)
        }
        let items = [item("a", .show, .inProgress, added: 1), item("b", .book, .inProgress, added: 2),
                     item("c", .film, .wantTo, added: 3), item("d", .book, .wantTo, added: 4), item("e", .film, .finished, added: 5)]
        let all = HomeSections(items: items, enabledKinds: Set(MediaKind.allCases))
        XCTAssertEqual(all.continueItem?.uid, "b", "Most recently added in-progress title")
        XCTAssertEqual(all.rows.map(\.id), ["inProgress", "wantWatch", "wantRead", "finished"])
        let screenOnly = HomeSections(items: items, enabledKinds: [.film, .show])
        XCTAssertEqual(screenOnly.continueItem?.uid, "a")
        XCTAssertFalse(screenOnly.rows.contains { $0.id == "wantRead" })
    }
}

final class FeatureFlagsTests: XCTestCase {
    /// Unfinished tabs stay hidden so no half-built screen can be reached.
    func testOnlyFinishedTabsShow() {
        XCTAssertEqual(FeatureFlags.visibleTabs.first, .home)
        XCTAssertTrue(FeatureFlags.visibleTabs.contains(.search))
        XCTAssertEqual(FeatureFlags.visibleTabs.contains(.stats), FeatureFlags.stats)
        XCTAssertEqual(FeatureFlags.visibleTabs.contains(.profile), FeatureFlags.profile)
    }
}

final class DiagnosticsReportTests: XCTestCase {
    func testSummaryAndProblemReport() {
        let report = DiagnosticsReport(appVersion: "0.1.0", build: "7", schemaVersion: "1.0.0", iOSVersion: "17.5", device: "iPhone",
                                       counts: [.film: 3, .book: 1], deletedCount: 2, imageCacheBytes: 2048, lastRefresh: nil,
                                       tmdbKeyPresent: false, tmdbReachable: nil, openLibraryReachable: true, lastBackup: nil,
                                       logLines: ["12:00:00 [data] Added film"])
        XCTAssertTrue(report.summary.contains("MARQUEE 0.1.0 (7), schema 1.0.0"))
        XCTAssertTrue(report.summary.contains("3 films, 0 shows, 1 books, 2 recently deleted"))
        XCTAssertTrue(report.summary.contains("TMDB key: missing"))
        let problem = report.problemReport(whatHappened: " It froze ", expected: "Not to")
        XCTAssertTrue(problem.hasPrefix("What happened:\nIt froze\n"))
        XCTAssertTrue(problem.contains("---\nMARQUEE 0.1.0"))
    }
}

final class LogBufferTests: XCTestCase {
    func testKeepsTheLastLines() {
        let buffer = LogBuffer(capacity: 3)
        for i in 1...5 { buffer.append("line \(i)") }
        XCTAssertEqual(buffer.snapshot.count, 3)
        XCTAssertTrue(buffer.snapshot.last?.hasSuffix("line 5") ?? false)
        XCTAssertTrue(buffer.snapshot.first?.hasSuffix("line 3") ?? false)
    }
}
