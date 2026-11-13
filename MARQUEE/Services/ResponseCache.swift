import CryptoKit
import Foundation

/// How long each kind of JSON response stays fresh on disk (§3.4).
enum CacheLifetime {
    static let details: TimeInterval = 7 * 24 * 3600
    static let trending: TimeInterval = 6 * 3600
    static let airingSeason: TimeInterval = 24 * 3600
    static let configuration: TimeInterval = 7 * 24 * 3600
    static let search: TimeInterval = 3600
}

/// A small on-disk JSON cache keyed by request URL. Stale entries are still
/// returned by `stale(_:)` so screens can show something when offline.
actor ResponseCache {
    private let directory: URL
    private let now: @Sendable () -> Date

    init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func standard() -> ResponseCache {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return ResponseCache(directory: base.appendingPathComponent("responses", isDirectory: true))
    }

    private func path(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }

    /// Returns cached data younger than `maxAge`.
    func fresh(_ key: String, maxAge: TimeInterval) -> Data? {
        let url = path(for: key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              now().timeIntervalSince(modified) < maxAge else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Returns cached data of any age.
    func stale(_ key: String) -> Data? {
        try? Data(contentsOf: path(for: key))
    }

    func store(_ data: Data, for key: String) {
        let url = path(for: key)
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: url.path)
        } catch {
            AppLog.error(.data, "Couldn't write response cache")
        }
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
