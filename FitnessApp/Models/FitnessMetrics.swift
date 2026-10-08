import Foundation

/// Calendar-based calculations shared by charts, summaries, and achievements.
enum FitnessMetrics {
    struct CalorieSummary {
        let days: [(date: Date, calories: Double)]
        let loggedDays: Int
        let total: Double
        let maximum: Double
        var average: Double { total / Double(days.count) }
        var hasRecords: Bool { loggedDays > 0 }
    }

    struct WorkoutDay: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    struct WorkoutSummary {
        let days: [WorkoutDay]
        let totalSessions: Int
        let weekSessions: Int
        let periodSessions: Int
        let maximumDailySessions: Int
        let averageMinutes: Double
        let commonType: String
        let streak: Int
    }

    static func streak(dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(dates.filter { $0 <= now }.map { calendar.startOfDay(for: $0) })
        return streak(days: days, now: now, calendar: calendar)
    }

    private static func streak(days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: now)
        // Yesterday's streak remains current until today has elapsed.
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), previous < day else { break }
            day = previous
        }
        return count
    }

    static func dailyCalories(records: [CalorieRecord], days: Int = 30, now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, calories: Double)] {
        calorieSummary(records: records, days: days, now: now, calendar: calendar).days
    }

    /// One history pass supplies both the chart and its readouts, including valid zero-calorie legacy entries.
    static func calorieSummary(records: [CalorieRecord], days: Int = 30, now: Date = Date(), calendar: Calendar = .current) -> CalorieSummary {
        let dates = calendarDays(count: days, now: now, calendar: calendar)
        let start = dates.first ?? calendar.startOfDay(for: now)
        var totals = Dictionary(uniqueKeysWithValues: dates.map { ($0, 0.0) })
        var loggedDays: Set<Date> = []
        for record in records where record.date >= start && record.date <= now && record.calories.isFinite && record.calories >= 0 {
            let date = calendar.startOfDay(for: record.date)
            totals[date, default: 0] += record.calories
            loggedDays.insert(date)
        }
        let values = dates.map { (date: $0, calories: totals[$0] ?? 0) }
        return CalorieSummary(days: values, loggedDays: loggedDays.count,
            total: values.reduce(0) { $0 + $1.calories }, maximum: values.map(\.calories).max() ?? 0)
    }

    /// Groups sessions by calendar day in O(records + days), rather than scanning the history once per bar.
    static func workoutSummary(records: [WorkoutRecord], days: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> WorkoutSummary {
        let dates = calendarDays(count: days, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        var counts: [Date: Int] = [:]
        var types: [WorkoutRecord.WorkoutType: Int] = [:]
        var totalSessions = 0
        var weekSessions = 0
        var totalDuration = 0.0
        for record in records where record.date <= now && record.duration.isFinite && record.duration >= 0 {
            let date = calendar.startOfDay(for: record.date)
            counts[date, default: 0] += 1
            types[record.type, default: 0] += 1
            totalSessions += 1
            totalDuration += record.duration
            if date >= weekStart { weekSessions += 1 }
        }
        let values = dates.map { WorkoutDay(date: $0, count: counts[$0] ?? 0) }
        let common = types.keys.sorted { left, right in
            let lhs = types[left] ?? 0, rhs = types[right] ?? 0
            return lhs == rhs ? left.rawValue < right.rawValue : lhs > rhs
        }.first?.rawValue ?? "—"
        return WorkoutSummary(days: values, totalSessions: totalSessions, weekSessions: weekSessions,
            periodSessions: values.reduce(0) { $0 + $1.count }, maximumDailySessions: values.map(\.count).max() ?? 0,
            averageMinutes: totalSessions == 0 ? 0 : totalDuration / Double(totalSessions) / 60,
            commonType: common, streak: streak(days: Set(counts.keys), now: now, calendar: calendar))
    }

    private static func calendarDays(count: Int, now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let dayCount = max(1, min(366, count))
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0 + 1 - dayCount, to: today) }
    }
}
