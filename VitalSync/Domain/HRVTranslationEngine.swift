import Foundation

enum HRVTranslationError: Error, Equatable {
    case insufficientIntervals
    case nonFiniteInterval
    case nonPositiveInterval
}

struct SDNNCalculator: Sendable {
    /// Calculates sample standard deviation from legitimate NN intervals in milliseconds.
    func calculate(nnIntervalsMilliseconds: [Double]) throws -> Double {
        guard nnIntervalsMilliseconds.count >= 2 else {
            throw HRVTranslationError.insufficientIntervals
        }
        guard nnIntervalsMilliseconds.allSatisfy(\.isFinite) else {
            throw HRVTranslationError.nonFiniteInterval
        }
        guard nnIntervalsMilliseconds.allSatisfy({ $0 > 0 }) else {
            throw HRVTranslationError.nonPositiveInterval
        }

        let mean = nnIntervalsMilliseconds.reduce(0, +) / Double(nnIntervalsMilliseconds.count)
        let squaredDeviations = nnIntervalsMilliseconds.reduce(0) { partial, interval in
            partial + pow(interval - mean, 2)
        }
        return sqrt(squaredDeviations / Double(nnIntervalsMilliseconds.count - 1))
    }
}

enum HRVSource: Sendable, Equatable {
    case rmssd(milliseconds: Double)
    case nnIntervals(milliseconds: [Double])
}

struct HRVTranslationEngine: Sendable {
    private let calculator: SDNNCalculator

    init(calculator: SDNNCalculator = SDNNCalculator()) {
        self.calculator = calculator
    }

    /// RMSSD is deliberately retained locally and never translated into SDNN.
    func healthKitSDNN(from source: HRVSource) throws -> Double? {
        switch source {
        case .rmssd:
            return nil
        case .nnIntervals(let intervals):
            return try calculator.calculate(nnIntervalsMilliseconds: intervals)
        }
    }
}
