import CryptoKit
import Foundation
import ImageIO
import UIKit

/// Loads artwork with a memory cache, a 500 MB least-recently-used disk cache,
/// and ImageIO downsampling to the size actually shown.
actor ImageCache {
    static let shared = ImageCache(directory: ImageCache.defaultDirectory, transport: URLSessionTransport.shared)
    static let maxDiskBytes = 500 * 1024 * 1024

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private let transport: HTTPTransport
    private var inFlight: [String: Task<Data, Error>] = [:]
    /// When true (screenshots and tests) nothing is fetched from the network.
    var offlineOnly = false

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("artwork", isDirectory: true)
    }

    init(directory: URL, transport: HTTPTransport) {
        self.directory = directory
        self.transport = transport
        memory.totalCostLimit = 80 * 1024 * 1024
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func setOfflineOnly(_ value: Bool) { offlineOnly = value }

    /// Returns an image no larger than `maxPixel` on its longest side.
    func image(for url: URL, maxPixel: CGFloat) async throws -> UIImage {
        let key = "\(url.absoluteString)@\(Int(maxPixel))" as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let data = try await data(for: url)
        guard let image = Self.downsample(data, maxPixel: maxPixel) else { throw AppError.decoding }
        memory.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        return image
    }

    /// Warms the disk cache ahead of scrolling. Failures are ignored.
    func prefetch(_ urls: [URL]) {
        for url in urls {
            Task { _ = try? await self.data(for: url) }
        }
    }

    private func data(for url: URL) async throws -> Data {
        let file = path(for: url)
        if let data = try? Data(contentsOf: file) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            return data
        }
        if offlineOnly { throw AppError.offline }
        let key = url.absoluteString
        if let task = inFlight[key] { return try await task.value }
        let transport = self.transport
        let task = Task<Data, Error> {
            let (data, response) = try await transport.send(URLRequest(url: url, timeoutInterval: 15))
            guard (200..<300).contains(response.statusCode), !data.isEmpty else { throw AppError.notFound }
            return data
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let data = try await task.value
        try? data.write(to: file, options: .atomic)
        trimIfNeeded()
        return data
    }

    private func path(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }

    private var writesSinceTrim = 0

    /// Removes the least recently used files once the cache passes 500 MB.
    private func trimIfNeeded() {
        writesSinceTrim += 1
        guard writesSinceTrim >= 25 else { return }
        writesSinceTrim = 0
        Self.trim(directory: directory, limit: Self.maxDiskBytes)
    }

    static func trim(directory: URL, limit: Int) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        var entries = files.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.totalFileAllocatedSize ?? 0)
        }
        var total = entries.reduce(0) { $0 + $1.2 }
        guard total > limit else { return }
        entries.sort { $0.1 < $1.1 }
        for entry in entries where total > limit {
            try? FileManager.default.removeItem(at: entry.0)
            total -= entry.2
        }
    }

    func diskUsage() -> Int {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        return files.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: Set(keys)))?.totalFileAllocatedSize ?? 0)
        }
    }

    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: cg)
    }
}
