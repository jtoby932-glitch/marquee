import Foundation

/// The single seam between the app and the network, so tests and screenshots
/// can swap in canned responses.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    static let shared: URLSessionTransport = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSessionTransport(session: URLSession(configuration: config))
    }()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.server(status: -1) }
        return (data, http)
    }
}

/// Sends requests with a 15 s timeout, retries twice with backoff on timeouts
/// and 5xx responses, and honours `Retry-After` on 429.
struct HTTPClient: Sendable {
    let transport: HTTPTransport
    var maxRetries = 2
    var baseDelay: Double = 0.6
    /// Injected so tests don't actually wait.
    var sleep: @Sendable (Double) async throws -> Void = { seconds in
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    func data(for request: URLRequest) async throws -> Data {
        var request = request
        request.timeoutInterval = 15
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                let (data, response) = try await transport.send(request)
                switch response.statusCode {
                case 200..<300:
                    return data
                case 401:
                    throw AppError.invalidTMDBKey
                case 404:
                    throw AppError.notFound
                case 429:
                    guard attempt < maxRetries else { throw AppError.rateLimited }
                    let wait = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? backoff(attempt)
                    attempt += 1
                    AppLog.info(.network, "429, retrying in \(String(format: "%.1f", min(wait, 10))) s")
                    try await sleep(min(wait, 10))
                case 500..<600:
                    guard attempt < maxRetries else { throw AppError.server(status: response.statusCode) }
                    attempt += 1
                    AppLog.info(.network, "HTTP \(response.statusCode), retry \(attempt)")
                    try await sleep(backoff(attempt - 1))
                default:
                    throw AppError.server(status: response.statusCode)
                }
            } catch let error as URLError where error.code == .timedOut {
                guard attempt < maxRetries else { throw AppError.timedOut }
                attempt += 1
                AppLog.info(.network, "Timed out, retry \(attempt)")
                try await sleep(backoff(attempt - 1))
            } catch let error as AppError {
                throw error
            } catch {
                throw UserFacingError.map(error)
            }
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from request: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let data = try await self.data(for: request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLog.error(.network, "Couldn't decode \(T.self)")
            throw AppError.decoding
        }
    }

    private func backoff(_ attempt: Int) -> Double { baseDelay * pow(2, Double(attempt)) }
}
