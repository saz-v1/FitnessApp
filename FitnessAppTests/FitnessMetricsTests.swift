import Foundation
import Testing
@testable import FitnessApp

struct FitnessMetricsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    @Test func calorieSummaryIncludesCalendarDaysAcrossDaylightSaving() throws {
        let calendar = calendar
        let now = try #require(calendar.date(from: DateComponents(year: 2024, month: 10, day: 28, hour: 12)))
        let first = try #require(calendar.date(from: DateComponents(year: 2024, month: 10, day: 22)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2024, month: 10, day: 27)))
        let records = [CalorieRecord(calories: 300, mealType: .breakfast, date: first),
            CalorieRecord(calories: 200, mealType: .lunch, date: first.addingTimeInterval(3600)),
            CalorieRecord(calories: 0, mealType: .snack, date: yesterday),
            CalorieRecord(calories: 100, mealType: .snack, date: now.addingTimeInterval(60)),
            CalorieRecord(calories: .nan, mealType: .snack, date: now),
            CalorieRecord(calories: -1, mealType: .snack, date: now)]
        let summary = FitnessMetrics.calorieSummary(records: records, days: 7, now: now, calendar: calendar)
        #expect(summary.days.count == 7)
        #expect(summary.days.first?.date == first)
        #expect(summary.days.first?.calories == 500)
        #expect(summary.days.last?.calories == 0)
        #expect(summary.loggedDays == 2)
        #expect(summary.total == 500)
        #expect(summary.maximum == 500)
        #expect(abs(summary.average - 500.0 / 7) < 0.001)
        #expect(summary.hasRecords)
        #expect(summary.days.last!.date.timeIntervalSince(yesterday) == 25 * 3600)
    }

    @Test func workoutSummaryExcludesFutureAndInvalidSessionsFromEveryReadout() throws {
        let calendar = calendar
        let now = try #require(calendar.date(from: DateComponents(year: 2024, month: 10, day: 28, hour: 12)))
        let first = try #require(calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
        let old = try #require(calendar.date(byAdding: .day, value: -40, to: now))
        let records = [WorkoutRecord(date: first, type: .cardio, duration: 600),
            WorkoutRecord(date: yesterday, type: .strength, duration: 1200),
            WorkoutRecord(date: yesterday.addingTimeInterval(3600), type: .cardio, duration: 1800),
            WorkoutRecord(date: old, type: .strength, duration: 2400),
            WorkoutRecord(date: now.addingTimeInterval(1), type: .yoga, duration: 3600),
            WorkoutRecord(date: now, type: .yoga, duration: .infinity)]
        let summary = FitnessMetrics.workoutSummary(records: records, days: 7, now: now, calendar: calendar)
        #expect(summary.totalSessions == 4)
        #expect(summary.weekSessions == 3)
        #expect(summary.periodSessions == 3)
        #expect(summary.days.first?.count == 1)
        #expect(summary.days.last?.count == 0)
        #expect(summary.maximumDailySessions == 2)
        #expect(summary.averageMinutes == 25)
        #expect(summary.commonType == "Cardio")
        #expect(summary.streak == 1)
        let reversed = FitnessMetrics.workoutSummary(records: Array(records.reversed()), days: 7, now: now, calendar: calendar)
        #expect(reversed.commonType == summary.commonType)
        #expect(reversed.days.map(\.count) == summary.days.map(\.count))
    }

    @Test func emptyHistoryAndInvalidRangesProduceBoundedZeroSummaries() {
        let calories = FitnessMetrics.calorieSummary(records: [], days: 0)
        #expect(calories.days.count == 1)
        #expect(!calories.hasRecords)
        #expect(calories.average == 0)
        let workouts = FitnessMetrics.workoutSummary(records: [], days: Int.max)
        #expect(workouts.days.count == 366)
        #expect(workouts.totalSessions == 0)
        #expect(workouts.periodSessions == 0)
        #expect(workouts.averageMinutes == 0)
        #expect(workouts.commonType == "—")
        #expect(workouts.streak == 0)
    }
}
