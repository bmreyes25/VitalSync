import Foundation
import XCTest
@testable import VitalSync

final class OuraClientTests: XCTestCase {
    func testPaginationCollectsAllPages() async throws {
        let first = #"{"data":[{"id":"synthetic-day-1","day":"2030-01-01","score":80}],"next_token":"page-2"}"#.data(using: .utf8)!
        let second = #"{"data":[{"id":"synthetic-day-2","day":"2030-01-02","score":81}],"next_token":null}"#.data(using: .utf8)!
        let transport = QueueTransport(responses: [response(first, status: 200), response(second, status: 200)])
        let client = makeClient(transport: transport)

        let documents = try await client.fetchAll(endpoint: .dailyReadiness, as: OuraDailyDocument.self)

        XCTAssertEqual(documents.map(\.id), ["synthetic-day-1", "synthetic-day-2"])
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[1].url?.query?.contains("next_token=page-2") == true)
    }

    func test429HonorsRetryThenSucceeds() async throws {
        let success = #"{"data":[],"next_token":null}"#.data(using: .utf8)!
        let transport = QueueTransport(responses: [
            response(Data(), status: 429, headers: ["Retry-After": "0"]),
            response(success, status: 200)
        ])
        let sleeper = RecordingSleeper()
        let client = makeClient(transport: transport, sleeper: sleeper)

        let values = try await client.fetchAll(endpoint: .workout, as: OuraWorkout.self)
        let sleepCount = await sleeper.count

        XCTAssertTrue(values.isEmpty)
        XCTAssertEqual(sleepCount, 1)
    }

    func testHeartRateUsesDatetimeBoundsAndDecodesSample() async throws {
        let body = #"{"data":[{"timestamp":"2030-01-02T03:04:05Z","timestamp_unix":1893553445000,"bpm":64,"source":"awake"}],"next_token":null}"#.data(using: .utf8)!
        let transport = QueueTransport(responses: [response(body, status: 200)])
        let client = makeClient(transport: transport)
        let start = ISO8601DateFormatter().date(from: "2030-01-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2030-01-03T00:00:00Z")!

        let samples = try await client.fetchHeartRates(from: start, through: end)
        let requests = await transport.requests
        let query = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].bpm, 64)
        XCTAssertEqual(query.first(where: { $0.name == "start_datetime" })?.value, "2030-01-01T00:00:00Z")
        XCTAssertEqual(query.first(where: { $0.name == "end_datetime" })?.value, "2030-01-03T00:00:00Z")
        XCTAssertFalse(query.contains(where: { $0.name == "start_date" }))
    }

    func testSleepReadinessAndSpO2DecodeFromSyntheticPages() async throws {
        let sleep = #"{"data":[{"id":"synthetic-sleep-a","day":"2030-01-02","bedtime_start":"2030-01-01T23:00:00-08:00","bedtime_end":"2030-01-02T07:00:00-08:00","average_hrv":41}],"next_token":null}"#.data(using: .utf8)!
        let readiness = #"{"data":[{"id":"synthetic-ready-a","day":"2030-01-02","temperature_deviation":-0.3,"timestamp":"2030-01-02T07:15:00-08:00"}],"next_token":null}"#.data(using: .utf8)!
        let spo2 = #"{"data":[{"id":"synthetic-spo2-a","day":"2030-01-02","spo2_percentage":{"average":96.4}}],"next_token":null}"#.data(using: .utf8)!
        let transport = QueueTransport(responses: [
            response(sleep, status: 200), response(readiness, status: 200), response(spo2, status: 200)
        ])
        let client = makeClient(transport: transport)
        let start = ISO8601DateFormatter().date(from: "2030-01-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2030-01-03T00:00:00Z")!

        let sleeps = try await client.fetchSleepPeriods(from: start, through: end)
        let readinessDays = try await client.fetchDailyReadiness(from: start, through: end)
        let oxygenDays = try await client.fetchDailySpO2(from: start, through: end)

        XCTAssertEqual(sleeps.first?.averageHRV, 41)
        XCTAssertEqual(readinessDays.first?.temperatureDeviation, -0.3)
        XCTAssertEqual(oxygenDays.first?.spo2Percentage?.average, 96.4)
        let paths = await transport.requests.compactMap { $0.url?.path }
        XCTAssertEqual(paths, [
            "/v2/usercollection/sleep", "/v2/usercollection/daily_readiness", "/v2/usercollection/daily_spo2"
        ])
    }

    private func makeClient(
        transport: QueueTransport,
        sleeper: RecordingSleeper = RecordingSleeper()
    ) -> OuraClient {
        let tokens = OAuthTokens(accessToken: "synthetic-access", refreshToken: "synthetic-refresh", expiresAt: .distantFuture, scope: nil)
        return OuraClient(
            baseURL: URL(string: "https://synthetic.invalid/v2")!,
            transport: transport,
            tokenManager: TokenManager(store: TestCredentialStore(tokens), broker: NeverBroker()),
            sleeper: sleeper,
            retryPolicy: RetryPolicy(maximumAttempts: 2, baseDelay: .zero)
        )
    }

    private func response(_ data: Data, status: Int, headers: [String: String]? = nil) -> (Data, HTTPURLResponse) {
        (data, HTTPURLResponse(url: URL(string: "https://synthetic.invalid")!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

private actor QueueTransport: HTTPTransport {
    private var responses: [(Data, HTTPURLResponse)]
    private(set) var requests: [URLRequest] = []
    init(responses: [(Data, HTTPURLResponse)]) { self.responses = responses }
    func data(for request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return responses.removeFirst()
    }
}

private actor RecordingSleeper: Sleeper {
    private(set) var count = 0
    func sleep(for duration: Duration) { count += 1 }
}

private actor TestCredentialStore: CredentialStore {
    var tokens: OAuthTokens?
    init(_ tokens: OAuthTokens?) { self.tokens = tokens }
    func load() -> OAuthTokens? { tokens }
    func save(_ tokens: OAuthTokens) { self.tokens = tokens }
    func delete() { tokens = nil }
}

private struct NeverBroker: TokenBroker {
    func exchange(code: String, redirectURI: URL) throws -> OAuthTokens { throw AuthenticationError.brokerRejected }
    func refresh(refreshToken: String) throws -> OAuthTokens { throw AuthenticationError.brokerRejected }
}
