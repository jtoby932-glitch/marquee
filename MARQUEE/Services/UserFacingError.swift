import Foundation

/// Every error a service can throw. Views never show these directly:
/// `UserFacingError` turns them into friendly copy in one place.
enum AppError: Error, Equatable {
    case offline
    case timedOut
    case rateLimited
    case server(status: Int)
    case missingTMDBKey
    case invalidTMDBKey
    case notFound
    case decoding
    case storage
    case cancelled
}

enum UserFacingError {
    struct Message: Equatable {
        let title: String
        let detail: String
    }

    static func message(for error: Error) -> Message {
        let appError = (error as? AppError) ?? map(error)
        switch appError {
        case .offline:
            return Message(title: String(localized: "You're offline"), detail: String(localized: "Check your connection and try again."))
        case .missingTMDBKey:
            return Message(title: String(localized: "Film and TV search needs a TMDB key"), detail: String(localized: "Books still work."))
        case .invalidTMDBKey:
            return Message(title: String(localized: "The TMDB key isn't working"), detail: String(localized: "Books still work. The key may need replacing."))
        case .notFound:
            return Message(title: String(localized: "That couldn't be found"), detail: String(localized: "It may have been removed from the catalogue."))
        case .storage:
            return Message(title: String(localized: "That couldn't be saved"), detail: String(localized: "Your iPhone may be low on storage. Free some space and try again."))
        case .rateLimited:
            return Message(title: String(localized: "That didn't load"), detail: String(localized: "Too many requests at once. Try again in a moment."))
        case .timedOut, .server, .decoding, .cancelled:
            return Message(title: String(localized: "That didn't load"), detail: String(localized: "Check your connection and try again."))
        }
    }

    /// Maps system errors to app errors.
    static func map(_ error: Error) -> AppError {
        if let app = error as? AppError { return app }
        if error is CancellationError { return .cancelled }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return .offline
            case .timedOut:
                return .timedOut
            case .cancelled:
                return .cancelled
            default:
                return .server(status: url.errorCode)
            }
        }
        if error is DecodingError { return .decoding }
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && (ns.code == NSFileWriteOutOfSpaceError) { return .storage }
        return .server(status: ns.code)
    }
}
