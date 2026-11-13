import Foundation
import SwiftData
import SwiftUI

/// Network and support services the views need, injected through the environment.
struct Services {
    var filmTV: FilmTVService
    var books: BookService
    var images: ImageCache
    var refresh: RefreshService?
    var appVersion: String
    var build: String

    static var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }
    static var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }

    static func make(stub: Bool, cache: ResponseCache, noKey: Bool = false) -> Services {
        let transport: HTTPTransport = stub ? FixtureTransport() : URLSessionTransport.shared
        let http = HTTPClient(transport: transport)
        let token = noKey ? "" : (stub ? "stub-token" : Secrets.tmdbReadToken)
        return Services(
            filmTV: TMDBClient(http: http, cache: cache, token: token),
            books: OpenLibraryClient(http: http, cache: cache, appVersion: appVersion),
            images: ImageCache.shared, refresh: nil, appVersion: appVersion, build: buildNumber)
    }

    /// Used by previews: canned responses only.
    static let preview: Services = {
        let cache = ResponseCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("preview-responses"))
        return make(stub: true, cache: cache)
    }()
}

private struct ServicesKey: EnvironmentKey {
    static let defaultValue = Services.preview
}

extension EnvironmentValues {
    var services: Services {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}

/// Builds everything the app needs at launch from the launch options.
@MainActor
final class AppEnvironment {
    let options: LaunchOptions
    let container: ModelContainer
    let library: LibraryStore
    let preferences: PreferencesStore
    let network: NetworkMonitor
    let services: Services
    let refresh: RefreshService

    init(options: LaunchOptions, now: @escaping () -> Date = { Date() }) throws {
        let container = try MarqueeStore.makeContainer(inMemory: options.usesInMemoryStore)
        let context = container.mainContext
        if options.demoData {
            DemoData.seed(into: context, now: now(), limit: options.demoSmall ? 40 : nil)
        }
        let library = LibraryStore(context: context, now: now)
        let preferences = PreferencesStore(context: context, overrideLook: options.look)
        if let level = options.animationLevel { preferences.setAnimationLevel(level) }
        let cache = options.stubNetwork
            ? ResponseCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("stub-responses-\(UUID().uuidString)"))
            : ResponseCache.standard()
        var services = Services.make(stub: options.stubNetwork, cache: cache, noKey: options.noKey)
        let refresh = RefreshService(store: library, filmTV: services.filmTV, books: services.books)
        services.refresh = refresh

        self.options = options
        self.container = container
        self.library = library
        self.preferences = preferences
        self.network = NetworkMonitor(forcedOffline: options.offline)
        self.services = services
        self.refresh = refresh
        if options.stubNetwork {
            Task { await ImageCache.shared.setOfflineOnly(true) }
        }
    }

    /// Quiet work after the first frame: purge expired deletions, fill pending details.
    func afterFirstFrame() async {
        library.purgeExpired()
        guard network.isOnline else { return }
        await refresh.fillPending()
        preferences.markRefreshed(Date())
    }
}

enum MarqueeStore {
    static let schemaVersion = "\(SchemaV1.versionIdentifier)"

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration("Marquee", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: MarqueeMigrationPlan.self, configurations: [configuration])
    }
}
