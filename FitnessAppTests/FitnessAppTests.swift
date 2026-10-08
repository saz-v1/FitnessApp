import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct FitnessAppTests {
    private func manager() -> UserManager {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("user.json")
        return UserManager(storageURL: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func calorieEstimateUsesAge() {
        let manager = manager()
        manager.updateUser { $0.age = 25 }
        let younger = manager.calculateDailyCalories()
        manager.updateUser { $0.age = 65 }
        #expect(manager.calculateDailyCalories() < younger)
    }

    @Test func invalidMeasurementsNeverReplaceSavedProfile() {
        let manager = manager()
        let original = manager.user
        #expect(!manager.updateUser { $0.height = 0 })
        #expect(!manager.updateUser { $0.height = .nan })
        #expect(manager.user == original)
    }

    @Test func goalAdjustmentUsesKilogramsInBothUnitSystems() {
        let manager = manager()
        manager.updateUser { $0.goalWeight = 68 }
        let metric = manager.calculateWeeklyCalorieTarget()!
        manager.toggleUnits()
        let imperial = manager.calculateWeeklyCalorieTarget()!
        #expect(abs(metric - imperial) < 0.001)
    }

    @Test func syncPreservesDistinctSameDayWorkoutsAndIsIdempotent() {
        let manager = manager()
        let date = Date()
        let first = WorkoutRecord(date: date, type: .cardio, duration: 600)
        let second = WorkoutRecord(date: date, type: .cardio, duration: 1200)
        manager.syncWorkouts([first, second, first])
        manager.syncWorkouts([first, second])
        #expect(manager.user.workoutHistory.count == 2)
    }

    @Test func storageMigratesOnlyAfterSuccessfulSave() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let original = manager().user
        defaults.set(try JSONEncoder().encode(original), forKey: "user")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("user.json")
        let migrated = UserManager(storageURL: url, defaults: defaults)
        #expect(migrated.user == original)
        #expect(defaults.data(forKey: "user") == nil)
        let reloaded = UserManager(storageURL: url, defaults: defaults)
        #expect(reloaded.user == original)
    }

    @Test func corruptedStorageIsNeverOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("user.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        let manager = UserManager(storageURL: url)
        manager.saveUser()
        #expect(manager.persistenceError != nil)
        #expect(try Data(contentsOf: url) == corrupt)
    }

    @Test func failedWritesDoNotPublishChanges() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("not a directory".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let manager = UserManager(storageURL: file.appendingPathComponent("user.json"))
        let original = manager.user
        #expect(!manager.updateUser { $0.weight = 80 })
        #expect(manager.user == original)
        #expect(manager.persistenceError != nil)
    }

    @Test func profileSavePreservesNewHistory() {
        let manager = manager()
        var draft = manager.user
        draft.age = 40
        #expect(manager.addWeight(75, date: Date()))
        #expect(manager.updateProfile(draft))
        #expect(manager.user.weightHistory.count == 1)
    }

    @Test func repeatedUnitTogglesDoNotLosePrecision() {
        var user = manager().user
        let original = user
        for _ in 0..<100 { user.toggleUnits() }
        #expect(abs(user.height - original.height) < 0.000001)
        #expect(abs(user.weight - original.weight) < 0.000001)
    }

    @Test func streakIncludesYesterdayAndCountsDaysOnce() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1800000000)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let previous = calendar.date(byAdding: .day, value: -2, to: today)!
        #expect(FitnessMetrics.streak(dates: [yesterday, yesterday, previous], now: now, calendar: calendar) == 2)
        #expect(FitnessMetrics.streak(dates: [today.addingTimeInterval(86400)], now: now, calendar: calendar) == 0)
    }

    @Test func chartIncludesEntireFirstDayAndDoesNotCountFutureMeals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1800000000)
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -29, to: today)!
        let records = [CalorieRecord(calories: 500, mealType: .breakfast, date: first),
            CalorieRecord(calories: 300, mealType: .lunch, date: first.addingTimeInterval(3600)),
            CalorieRecord(calories: 100, mealType: .snack, date: now.addingTimeInterval(86400))]
        let days = FitnessMetrics.dailyCalories(records: records, now: now, calendar: calendar)
        #expect(days.count == 30)
        #expect(days.first?.calories == 800)
        #expect(days.reduce(0) { $0 + $1.calories } == 800)
    }

    @Test func weightAchievementRequiresSeparateDays() {
        let manager = manager()
        for _ in 0..<7 { _ = manager.addWeight(70, date: Date()) }
        let achievements = AchievementManager(userManager: manager)
        achievements.checkAchievements()
        #expect(achievements.achievements.first { $0.id == "weight_consistency" }?.isUnlocked == false)
    }

    @Test func manualJournalRecordsReloadWithoutHealthConnection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("user.json")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(false, forKey: "healthIntegrationEnabled")
        let manager = UserManager(storageURL: url, defaults: defaults)
        let meal = CalorieRecord(calories: 650, mealType: .lunch, description: "Home-cooked meal", date: Date())
        let workout = WorkoutRecord(date: Date(), type: .cardio, duration: 1800)
        #expect(manager.updateUser { $0.calorieHistory.append(meal); $0.workoutHistory.append(workout) })
        #expect(manager.addWeight(72, date: Date()))
        let reloaded = UserManager(storageURL: url, defaults: defaults)
        #expect(reloaded.user.calorieHistory == [meal])
        #expect(reloaded.user.workoutHistory == [workout])
        #expect(reloaded.user.weightHistory.count == 1)
        #expect(reloaded.user.weightHistory.first?.weight == 72)
        #expect(!defaults.bool(forKey: "healthIntegrationEnabled"))
    }
}
