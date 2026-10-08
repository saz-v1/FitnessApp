import Foundation

/// Standalone macOS checks built from the actual app model sources.
/// iOS tests are still needed for file protection, HealthKit and UI behavior.
@main
struct RegressionChecks {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = UserManager(storageURL: root.appendingPathComponent("user.json"), defaults: defaults)
        let original = manager.user
        precondition(manager.updateUser { $0.age = 65 })
        precondition(manager.calculateDailyCalories() < 2500)
        precondition(manager.updateUser { $0.goalWeight = 68 })
        let metric = manager.calculateWeeklyCalorieTarget()!
        for _ in 0..<100 { manager.toggleUnits() }
        precondition(abs(manager.user.height - original.height) < 0.000001)
        precondition(abs(manager.calculateWeeklyCalorieTarget()! - metric) < 0.001)
        let before = manager.user
        precondition(!manager.updateUser { $0.height = .nan })
        precondition(manager.user == before)
        let first = WorkoutRecord(type: .cardio, duration: 600)
        let second = WorkoutRecord(date: first.date, type: .cardio, duration: 1200)
        precondition(manager.syncWorkouts([first, second, first]))
        precondition(manager.syncWorkouts([first, second]))
        precondition(manager.user.workoutHistory.count == 2)
        let reloaded = UserManager(storageURL: root.appendingPathComponent("user.json"), defaults: defaults)
        precondition(reloaded.user == manager.user)
        defaults.set(try JSONEncoder().encode(reloaded.user), forKey: "user")
        let migrated = UserManager(storageURL: root.appendingPathComponent("migrated.json"), defaults: defaults)
        precondition(migrated.user == reloaded.user && defaults.data(forKey: "user") == nil)
        let bad = root.appendingPathComponent("corrupt.json")
        try Data("broken".utf8).write(to: bad)
        let corrupt = UserManager(storageURL: bad, defaults: defaults)
        precondition(!corrupt.updateUser { $0.weight = 80 })
        let preserved = try Data(contentsOf: bad)
        precondition(preserved == Data("broken".utf8))
        let blocked = UserManager(storageURL: bad.appendingPathComponent("user.json"), defaults: defaults)
        precondition(!blocked.updateUser { $0.weight = 80 })
        precondition(blocked.user.weight == original.weight)
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        precondition(FitnessMetrics.streak(dates: [yesterday, yesterday], now: now) == 1)
        let records = [CalorieRecord(calories: 500, mealType: .breakfast), CalorieRecord(calories: 300, mealType: .lunch)]
        let days = FitnessMetrics.dailyCalories(records: records)
        precondition(days.count == 30 && days.reduce(0) { $0 + $1.calories } == 800)
        for _ in 0..<7 { precondition(manager.addWeight(70, date: Date())) }
        let achievements = AchievementManager(userManager: manager)
        achievements.checkAchievements()
        precondition(!achievements.achievements.first { $0.id == "weight_consistency" }!.isUnlocked)
        print("Model, transaction, storage, unit, chart, streak and achievement checks passed")
    }
}
