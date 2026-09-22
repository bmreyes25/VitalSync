import Foundation

struct DateWindow: Equatable, Sendable {
    let start: Date
    let end: Date
}

struct BackfillPlanner: Sendable {
    let calendar: Calendar
    let maximumDaysPerWindow: Int

    init(calendar: Calendar = Calendar(identifier: .iso8601), maximumDaysPerWindow: Int = 30) {
        self.calendar = calendar
        self.maximumDaysPerWindow = maximumDaysPerWindow
    }

    func windows(from start: Date, through end: Date) -> [DateWindow] {
        guard start <= end, maximumDaysPerWindow > 0 else { return [] }
        var result: [DateWindow] = []
        var cursor = start
        while cursor <= end {
            let proposed = calendar.date(byAdding: .day, value: maximumDaysPerWindow - 1, to: cursor) ?? end
            let windowEnd = min(proposed, end)
            result.append(DateWindow(start: cursor, end: windowEnd))
            guard let next = calendar.date(byAdding: .day, value: 1, to: windowEnd), next > cursor else { break }
            cursor = next
        }
        return result
    }
}
