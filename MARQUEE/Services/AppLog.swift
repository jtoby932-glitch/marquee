import Foundation
import os

/// Logging with categories. Messages go to the unified log and to a 200-line
/// buffer the Diagnostics screen shows. Personal details (titles, notes) are
/// passed as `private` and never reach the buffer.
enum AppLog {
    enum Category: String, CaseIterable {
        case network, data, `import`, ui
    }

    private static let subsystem = "com.savonstudios.marquee"
    private static let loggers: [Category: Logger] = Dictionary(uniqueKeysWithValues: Category.allCases.map {
        ($0, Logger(subsystem: subsystem, category: $0.rawValue))
    })

    static let buffer = LogBuffer(capacity: 200)

    static func info(_ category: Category, _ message: String, private detail: String? = nil) {
        log(category, .info, message, detail)
    }

    static func error(_ category: Category, _ message: String, private detail: String? = nil) {
        log(category, .error, message, detail)
    }

    private static func log(_ category: Category, _ type: OSLogType, _ message: String, _ detail: String?) {
        let logger = loggers[category] ?? Logger(subsystem: subsystem, category: category.rawValue)
        if let detail {
            logger.log(level: type, "\(message, privacy: .public) \(detail, privacy: .private)")
        } else {
            logger.log(level: type, "\(message, privacy: .public)")
        }
        buffer.append("[\(category.rawValue)] \(type == .error ? "ERROR " : "")\(message)")
    }
}

/// A thread-safe ring buffer of recent log lines.
final class LogBuffer: @unchecked Sendable {
    private let capacity: Int
    private var lines: [String] = []
    private let lock = NSLock()
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(capacity: Int) { self.capacity = capacity }

    func append(_ line: String, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        lines.append("\(formatter.string(from: date)) \(line)")
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
    }

    var snapshot: [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines
    }
}
