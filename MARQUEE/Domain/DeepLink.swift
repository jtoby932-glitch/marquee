import Foundation

/// Every `marquee://` link the app understands.
enum DeepLink: Equatable {
    case title(uid: String)
    case season(uid: String, number: Int)
    case search(query: String)
    case timer(uid: String)
    case decide

    init?(url: URL) {
        guard url.scheme?.lowercased() == "marquee", let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "title":
            guard parts.count == 1, TitleUID(parts[0]) != nil else { return nil }
            self = .title(uid: parts[0])
        case "season":
            guard parts.count == 2, TitleUID(parts[0])?.kind == .show, let n = Int(parts[1]), n >= 0 else { return nil }
            self = .season(uid: parts[0], number: n)
        case "search":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "q" })?.value ?? ""
            self = .search(query: query)
        case "timer":
            guard parts.count == 1, TitleUID(parts[0])?.kind == .book else { return nil }
            self = .timer(uid: parts[0])
        case "decide":
            self = .decide
        default:
            return nil
        }
    }

    var url: URL? {
        switch self {
        case .title(let uid): return URL(string: "marquee://title/\(uid)")
        case .season(let uid, let n): return URL(string: "marquee://season/\(uid)/\(n)")
        case .search(let query):
            var c = URLComponents()
            c.scheme = "marquee"
            c.host = "search"
            // URLComponents leaves "&" and "+" raw in query values, so encode them ourselves.
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=?#")
            c.percentEncodedQueryItems = [URLQueryItem(name: "q", value: query.addingPercentEncoding(withAllowedCharacters: allowed))]
            return c.url
        case .timer(let uid): return URL(string: "marquee://timer/\(uid)")
        case .decide: return URL(string: "marquee://decide")
        }
    }
}
