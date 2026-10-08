#if DEBUG
import Foundation

/// Synthetic data for isolated UI-test stores only. Never added to a regular launch.
@MainActor
enum UITestFixtures {
    static func populate(_ manager: UserManager) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        manager.updateUser { user in
            user.weight = 68.4
            user.goalWeight = 66
            for offset in 0..<90 {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                user.calorieHistory.append(CalorieRecord(calories: Double(1750 + (offset % 5) * 120), mealType: .dinner,
                    description: "Sample meal", date: date))
                if offset % 3 == 0 {
                    user.weightHistory.append(WeightRecord(weight: 68.4 + Double(offset) * 0.025, date: date))
                    user.workoutHistory.append(WorkoutRecord(date: date, type: offset % 2 == 0 ? .strength : .cardio,
                        duration: 1800, caloriesBurned: 180))
                }
            }
        }
    }
}
#endif
