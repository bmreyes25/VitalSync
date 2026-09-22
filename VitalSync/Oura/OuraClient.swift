import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OuraAPIError.invalidResponse }
        return (data, http)
    }
}

protocol Sleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

struct ContinuousSleeper: Sleeper {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

struct RetryPolicy: Sendable {
    let maximumAttempts: Int
    let baseDelay: Duration

    static let production = RetryPolicy(maximumAttempts: 4, baseDelay: .seconds(1))

    func delay(attempt: Int, response: HTTPURLResponse?) -> Duration {
        if let value = response?.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(value), seconds >= 0 {
            return .milliseconds(Int64(seconds * 1_000))
        }
        let multiplier = 1 << max(0, attempt - 1)
        return baseDelay * multiplier
    }
}

enum OuraAPIError: Error, Equatable {
    case invalidResponse
    case invalidURL
    case unauthorized
    case rateLimited
    case server(Int)
    case status(Int)
    case paginationCycle
}

struct OuraClient: Sendable {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let tokenManager: TokenManager
    private let sleeper: any Sleeper
    private let retryPolicy: RetryPolicy

    init(
        baseURL: URL = URL(string: "https://api.ouraring.com/v2")!,
        transport: any HTTPTransport = URLSessionTransport(),
        tokenManager: TokenManager,
        sleeper: any Sleeper = ContinuousSleeper(),
        retryPolicy: RetryPolicy = .production
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenManager = tokenManager
        self.sleeper = sleeper
        self.retryPolicy = retryPolicy
    }

    func fetchAll<Element: Decodable & Sendable>(
        endpoint: OuraEndpoint,
        startDate: Date? = nil,
        endDate: Date? = nil,
        as type: Element.Type
    ) async throws -> [Element] {
        var token: String?
        var seenTokens = Set<String>()
        var collected: [Element] = []
        repeat {
            if let token, !seenTokens.insert(token).inserted { throw OuraAPIError.paginationCycle }
            let page: OuraPage<Element> = try await fetchPage(
                endpoint: endpoint,
                startDate: startDate,
                endDate: endDate,
                nextToken: token
            )
            collected.append(contentsOf: page.data)
            token = page.nextToken
        } while token != nil
        return collected
    }

    private func fetchPage<Element: Decodable & Sendable>(
        endpoint: OuraEndpoint,
        startDate: Date?,
        endDate: Date?,
        nextToken: String?
    ) async throws -> OuraPage<Element> {
        var refreshed = false
        var attempt = 1
        while true {
            let accessToken = try await tokenManager.validAccessToken(forceRefresh: refreshed)
            let request = try makeRequest(
                endpoint: endpoint,
                startDate: startDate,
                endDate: endDate,
                nextToken: nextToken,
                accessToken: accessToken
            )
            let (data, response) = try await transport.data(for: request)
            switch response.statusCode {
            case 200..<300:
                return try OuraCoding.decoder.decode(OuraPage<Element>.self, from: data)
            case 401 where !refreshed:
                refreshed = true
                continue
            case 401:
                throw OuraAPIError.unauthorized
            case 429 where attempt < retryPolicy.maximumAttempts:
                try await sleeper.sleep(for: retryPolicy.delay(attempt: attempt, response: response))
                attempt += 1
            case 500...599 where attempt < retryPolicy.maximumAttempts:
                try await sleeper.sleep(for: retryPolicy.delay(attempt: attempt, response: response))
                attempt += 1
            case 429:
                throw OuraAPIError.rateLimited
            case 500...599:
                throw OuraAPIError.server(response.statusCode)
            default:
                throw OuraAPIError.status(response.statusCode)
            }
        }
    }

    private func makeRequest(
        endpoint: OuraEndpoint,
        startDate: Date?,
        endDate: Date?,
        nextToken: String?,
        accessToken: String
    ) throws -> URLRequest {
        let endpointURL = baseURL.appending(path: endpoint.rawValue)
        guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) else {
            throw OuraAPIError.invalidURL
        }
        var items: [URLQueryItem] = []
        if endpoint.supportsDateRange {
            if let startDate { items.append(URLQueryItem(name: "start_date", value: Self.ouraDay(startDate))) }
            if let endDate { items.append(URLQueryItem(name: "end_date", value: Self.ouraDay(endDate))) }
        }
        if let nextToken { items.append(URLQueryItem(name: "next_token", value: nextToken)) }
        components.queryItems = items.isEmpty ? nil : items
        guard let url = components.url else { throw OuraAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        return request
    }

    private static func ouraDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
