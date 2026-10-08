import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct AchievementRegressionTests {
    @Test func futureEntriesDoNotUnlockFirstEntryAchievements() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = UserManager(storageURL: directory.appendingPathComponent("user.json"),
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let future = Date().addingTimeInterval(86400)
        #expect(manager.updateUser {
            $0.unlockedAchievementIDs = []
            $0.weightHistory = [WeightRecord(weight: 70, date: future)]
            $0.calorieHistory = [CalorieRecord(calories: 500, mealType: .breakfast, date: future)]
            $0.workoutHistory = [WorkoutRecord(date: future, type: .cardio, duration: 1800)]
        })
        let achievements = AchievementManager(userManager: manager)
        achievements.checkAchievements()
        for id in ["first_weight_entry", "first_meal_logged", "first_workout"] {
            #expect(achievements.achievements.first { $0.id == id }?.isUnlocked == false)
        }
    }

    @Test func goalAchievementToleranceIsIndependentOfDisplayUnits() {
        for metric in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let manager = UserManager(storageURL: directory.appendingPathComponent("user.json"),
                defaults: UserDefaults(suiteName: UUID().uuidString)!)
            #expect(manager.updateUser { $0.weight = 70; $0.goalWeight = 69.6; $0.unlockedAchievementIDs = [] })
            if !metric { manager.toggleUnits() }
            let achievements = AchievementManager(userManager: manager)
            achievements.checkAchievements()
            #expect(achievements.achievements.first { $0.id == "weight_goal_reached" }?.isUnlocked == true)
        }
    }
}
