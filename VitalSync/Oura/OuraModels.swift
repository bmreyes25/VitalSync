import Foundation

enum OuraEndpoint: String, Codable, CaseIterable, Sendable {
    case personalInfo = "usercollection/personal_info"
    case dailyActivity = "usercollection/daily_activity"
    case dailyReadiness = "usercollection/daily_readiness"
    case dailySleep = "usercollection/daily_sleep"
    case dailyCardiovascularAge = "usercollection/daily_cardiovascular_age"
    case dailyResilience = "usercollection/daily_resilience"
    case dailyStress = "usercollection/daily_stress"
    case dailySpO2 = "usercollection/daily_spo2"
    case sleep = "usercollection/sleep"
    case sleepTime = "usercollection/sleep_time"
    case heartrate = "usercollection/heartrate"
    case tag = "usercollection/tag"
    case enhancedTag = "usercollection/enhanced_tag"
    case workout = "usercollection/workout"
    case session = "usercollection/session"
    case ringConfiguration = "usercollection/ring_configuration"
    case vo2Max = "usercollection/vo2_max"

    var supportsDateRange: Bool { self != .personalInfo }
}

struct OuraPage<Element: Decodable & Sendable>: Decodable, Sendable {
    let data: [Element]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraScoreContributors: Codable, Hashable, Sendable {
    let values: [String: Double]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = (try? container.decode([String: Double].self)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

struct OuraPersonalInfo: Codable, Hashable, Sendable {
    let id: String
    let age: Int?
    let weight: Double?
    let height: Double?
    let biologicalSex: String?

    enum CodingKeys: String, CodingKey {
        case id, age, weight, height
        case biologicalSex = "biological_sex"
    }
}

struct OuraDailyDocument: Codable, Hashable, Sendable {
    let id: String
    let day: String
    let score: Int?
    let timestamp: Date?
    let contributors: OuraScoreContributors?
}

struct OuraIntervalDocument: Codable, Hashable, Sendable {
    let id: String
    let startDatetime: Date?
    let endDatetime: Date?
    let day: String?
    let type: String?
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case id, day, type, score
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
    }
}

struct OuraHeartRate: Codable, Hashable, Sendable {
    let bpm: Int
    let source: String?
    let timestamp: Date
}

struct OuraSpO2: Codable, Hashable, Sendable {
    struct Percentage: Codable, Hashable, Sendable {
        let average: Double?
    }
    let id: String
    let day: String
    let spo2Percentage: Percentage?

    enum CodingKeys: String, CodingKey {
        case id, day
        case spo2Percentage = "spo2_percentage"
    }
}

struct OuraWorkout: Codable, Hashable, Sendable {
    let id: String
    let activity: String
    let calories: Double?
    let distance: Double?
    let intensity: String?
    let startDatetime: Date
    let endDatetime: Date

    enum CodingKeys: String, CodingKey {
        case id, activity, calories, distance, intensity
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
    }
}

struct OuraTag: Codable, Hashable, Sendable {
    let id: String
    let text: String?
    let tagTypeCode: String?
    let startDatetime: Date?
    let endDatetime: Date?

    enum CodingKeys: String, CodingKey {
        case id, text
        case tagTypeCode = "tag_type_code"
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
    }
}

struct OuraRingConfiguration: Codable, Hashable, Sendable {
    let id: String
    let color: String?
    let design: String?
    let firmwareVersion: String?
    let hardwareType: String?
    let setUpAt: Date?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case id, color, design, size
        case firmwareVersion = "firmware_version"
        case hardwareType = "hardware_type"
        case setUpAt = "set_up_at"
    }
}

struct OuraVO2Max: Codable, Hashable, Sendable {
    let id: String
    let day: String
    let vo2Max: Double?

    enum CodingKeys: String, CodingKey {
        case id, day
        case vo2Max = "vo2_max"
    }
}

enum OuraCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            if let date = fractional.date(from: value) ?? standard.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }()
}
