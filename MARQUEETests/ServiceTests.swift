import UIKit
import XCTest
@testable import MARQUEE

/// Stubs the network at the URLProtocol level, so the real URLSession path runs.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        var status: Int
        var headers: [String: String] = [:]
        var body = Data()
        var error: URLError?
    }

    static var replies: [Reply] = []
    static var requests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset(_ replies: [Reply]) {
        lock.lock(); defer { lock.unlock() }
        self.replies = replies
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let reply = Self.replies.isEmpty ? Reply(status: 500) : Self.replies.removeFirst()
        Self.lock.unlock()
        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func transport() -> URLSessionTransport {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSessionTransport(session: URLSession(configuration: config))
    }
}

final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []
    func record(_ value: Double) { lock.lock(); values.append(value); lock.unlock() }
    var all: [Double] { lock.lock(); defer { lock.unlock() }; return values }
}

final class HTTPClientTests: XCTestCase {
    private let recorder = SleepRecorder()
    private var sleeps: [Double] { recorder.all }

    private func client() -> HTTPClient {
        var c = HTTPClient(transport: StubURLProtocol.transport())
        let recorder = self.recorder
        c.sleep = { seconds in recorder.record(seconds) }
        return c
    }

    private let request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/x")!)

    func testRetriesServerErrorsTwiceThenSucceeds() async throws {
        StubURLProtocol.reset([.init(status: 503), .init(status: 502), .init(status: 200, body: Data("ok".utf8))])
        let data = try await client().data(for: request)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "ok")
        XCTAssertEqual(StubURLProtocol.requests.count, 3)
        XCTAssertEqual(sleeps.count, 2)
        XCTAssertLessThan(sleeps[0], sleeps[1], "Backs off")
    }

    func testGivesUpAfterTwoRetries() async {
        StubURLProtocol.reset([.init(status: 500), .init(status: 500), .init(status: 500), .init(status: 200)])
        do {
            _ = try await client().data(for: request)
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? AppError, .server(status: 500))
            XCTAssertEqual(StubURLProtocol.requests.count, 3)
        }
    }

    func testRespectsRetryAfterOn429() async throws {
        StubURLProtocol.reset([.init(status: 429, headers: ["Retry-After": "3"]), .init(status: 200)])
        _ = try await client().data(for: request)
        XCTAssertEqual(sleeps, [3])
    }

    func testRetriesTimeouts() async throws {
        StubURLProtocol.reset([.init(status: 0, error: URLError(.timedOut)), .init(status: 200)])
        _ = try await client().data(for: request)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
    }

    func testMapsErrors() async {
        for (reply, expected) in [(StubURLProtocol.Reply(status: 401), AppError.invalidTMDBKey), (.init(status: 404), .notFound),
                                  (.init(status: 0, error: URLError(.notConnectedToInternet)), .offline)] {
            StubURLProtocol.reset([reply])
            do {
                _ = try await client().data(for: request)
                XCTFail("Should throw")
            } catch {
                XCTAssertEqual(error as? AppError, expected)
            }
        }
    }

    func testFriendlyMessages() {
        XCTAssertEqual(UserFacingError.message(for: AppError.missingTMDBKey).title, "Film and TV search needs a TMDB key")
        XCTAssertEqual(UserFacingError.message(for: AppError.server(status: 500)).title, "That didn't load")
        XCTAssertEqual(UserFacingError.map(URLError(.timedOut)), .timedOut)
    }
}

final class ClientDecodingTests: XCTestCase {
    private func cache() -> ResponseCache {
        ResponseCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString)"))
    }

    private func tmdb(token: String = "token") -> TMDBClient {
        TMDBClient(http: HTTPClient(transport: FixtureTransport()), cache: cache(), token: token)
    }

    func testTMDBSearchDecodesFixturesAndSkipsPeople() async throws {
        let results = try await tmdb().search("dune")
        XCTAssertEqual(results.count, 4)
        XCTAssertFalse(results.contains { $0.name == "Someone" })
        let dune = try XCTUnwrap(results.first { $0.uid == "tmdb-movie-438631" })
        XCTAssertEqual(dune.year, 2021)
        XCTAssertEqual(dune.genres, ["Sci-fi", "Adventure"])
        XCTAssertEqual(dune.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w342/d5NXSklXo0qyIYkgV94XAgMIckC.jpg")
        XCTAssertNil(results.first(where: { $0.uid == "tmdb-movie-841" })?.posterURL, "Missing artwork stays nil")
    }

    func testTMDBMovieDetailsIncludeUKCertificateAndDirector() async throws {
        let details = try await tmdb().details(uid: "tmdb-movie-438631")
        XCTAssertEqual(details.runtimeMinutes, 155)
        XCTAssertEqual(details.creators, ["Denis Villeneuve"])
        XCTAssertEqual(details.ukCertificate, "12A")
    }

    func testMissingKeyNeverHitsTheNetwork() async {
        do {
            _ = try await tmdb(token: "  ").search("dune")
            XCTFail("Should throw")
        } catch {
            XCTAssertEqual(error as? AppError, .missingTMDBKey)
        }
    }

    func testRequestsUseBritishEnglishAndBearer() {
        let request = tmdb().request("search/multi", ["query": "dune"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        let query = request.url?.query ?? ""
        XCTAssertTrue(query.contains("language=en-GB"))
        XCTAssertTrue(query.contains("region=GB"))
    }

    func testOpenLibrarySearchAndWork() async throws {
        let client = OpenLibraryClient(http: HTTPClient(transport: FixtureTransport()), cache: cache(), appVersion: "0.1.0")
        let results = try await client.search("dune")
        XCTAssertEqual(results.first?.uid, "ol-OL893415W")
        XCTAssertEqual(results.first?.pageCount, 658)
        XCTAssertEqual(results.first?.posterURL?.absoluteString, "https://covers.openlibrary.org/b/id/11481354-M.jpg?default=false")
        let work = try await client.details(uid: "ol-OL893415W")
        XCTAssertTrue(work.overview.hasPrefix("Set on the desert planet Arrakis"))
        XCTAssertEqual(work.creators, ["Frank Herbert"])
        XCTAssertTrue(client.userAgent.hasPrefix("MARQUEE/0.1.0"))
    }

    func testOpenLibraryYears() {
        XCTAssertEqual(OLDate.year("August 1965"), 1965)
        XCTAssertEqual(OLDate.year("1 Aug 1965"), 1965)
        XCTAssertNil(OLDate.year("unknown"))
    }
}

final class ResponseCacheTests: XCTestCase {
    func testFreshnessAndStaleFallback() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID().uuidString)")
        let box = ClockBox(clock)
        let cache = ResponseCache(directory: dir, now: { box.now })
        await cache.store(Data("hello".utf8), for: "k")
        let fresh = await cache.fresh("k", maxAge: 60)
        XCTAssertNotNil(fresh)
        clock.addTimeInterval(120)
        box.now = clock
        let expired = await cache.fresh("k", maxAge: 60)
        XCTAssertNil(expired)
        let stale = await cache.stale("k")
        XCTAssertEqual(stale, Data("hello".utf8))
    }
}

final class ClockBox: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

final class ImageCacheTests: XCTestCase {
    func testTrimRemovesLeastRecentlyUsedFirst() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("img-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let old = dir.appendingPathComponent("old"), recent = dir.appendingPathComponent("recent")
        try Data(count: 10_000).write(to: old)
        try Data(count: 10_000).write(to: recent)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: old.path)
        ImageCache.trim(directory: dir, limit: 15_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
    }

    func testDownsampleRespectsMaxPixel() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
        }
        let data = try XCTUnwrap(image.pngData())
        let small = try XCTUnwrap(ImageCache.downsample(data, maxPixel: 150))
        XCTAssertLessThanOrEqual(max(small.size.width * small.scale, small.size.height * small.scale), 150)
    }
}
