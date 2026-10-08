import Foundation

// MARK: - Achievement Model
/// Represents an achievement that users can earn through various activities in the app
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let points: Int
    let category: Category
    var progress: Double // 0.0 to 1.0
    var isUnlocked: Bool
    var unlockDate: Date?
    
    /// Categories of achievements available in the app
    enum Category: String, Codable {
        case weight = "Weight"
        case calories = "Calories"
        case consistency = "Consistency"
        case milestones = "Milestones"
    }
}

// MARK: - Achievement Manager
/// Manages user achievements, progress tracking, and achievement unlocking
@MainActor
class AchievementManager: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var totalPoints: Int = 0
    @Published var currentStreak: Int = 0
    @Published var currentLevel: Int = 1
    @Published var pointsToNextLevel: Int = 0
    @Published var pointsInCurrentLevel: Int = 0
    
    private let userManager: UserManager
    
    // Points required for each level (increasing gradually)
    private let pointsPerLevel: [Int] = [
        0,      // Level 1
        50,     // Level 2
        150,    // Level 3
        300,    // Level 4
        500,    // Level 5
        750,    // Level 6
        1000    // Level 7
    ]
    
    init(userManager: UserManager) {
        self.userManager = userManager
        loadAchievements()
        var unlocked = userManager.user.unlockedAchievementIDs ?? []
        if userManager.user.unlockedAchievementIDs == nil,
           let data = UserDefaults.standard.data(forKey: "achievements"),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            unlocked.formUnion(saved.filter(\.isUnlocked).map(\.id))
            if userManager.updateUser({ $0.unlockedAchievementIDs = unlocked }) {
                for key in ["achievements", "totalPoints", "currentStreak", "currentLevel"] { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        for index in achievements.indices where unlocked.contains(achievements[index].id) {
            achievements[index].isUnlocked = true
            achievements[index].progress = 1
        }
        totalPoints = achievements.filter(\.isUnlocked).reduce(0) { $0 + $1.points }
        calculateLevel()
    }
    
    // MARK: - Level Calculation
    /// Calculates the user's current level based on total points
    private func calculateLevel() {
        // Find the highest level the user has reached
        for (index, points) in pointsPerLevel.enumerated() {
            if totalPoints >= points {
                currentLevel = index + 1
            } else {
                break
            }
        }
        
        // Calculate points needed for next level
        if currentLevel < pointsPerLevel.count {
            pointsToNextLevel = pointsPerLevel[currentLevel] - totalPoints
        } else {
            pointsToNextLevel = 0 // Max level reached
        }
        
        // Calculate points in current level
        pointsInCurrentLevel = totalPoints - pointsPerLevel[currentLevel - 1]
    }
    
    /// Get the level title based on the current level
    func levelTitle() -> String {
        switch currentLevel {
        case 1: return "Beginner"
        case 2: return "Novice"
        case 3: return "Intermediate"
        case 4: return "Advanced"
        case 5: return "Expert"
        case 6: return "Master"
        case 7: return "Fitness Pro"
        default: return "Unknown"
        }
    }
    
    // MARK: - Achievement Loading
    /// Initializes the default set of achievements available in the app
    private func loadAchievements() {
        achievements = [
            // Weight-related achievements
            Achievement(
                id: "first_weight_entry",
                title: "First Step",
                description: "Log your first weight entry",
                icon: "scalemass.fill",
                points: 10,
                category: .weight,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "weight_goal_reached",
                title: "Goal Achiever",
                description: "Reach your weight goal",
                icon: "trophy.fill",
                points: 50,
                category: .weight,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "weight_consistency",
                title: "Consistent Tracker",
                description: "Log weight for 7 days in a row",
                icon: "calendar.badge.clock",
                points: 30,
                category: .consistency,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            
            // Calorie-related achievements
            Achievement(
                id: "first_meal_logged",
                title: "Food Logger",
                description: "Log your first meal",
                icon: "fork.knife",
                points: 10,
                category: .calories,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "calorie_goal_met",
                title: "Meal Tracking",
                description: "Log meals for 3 consecutive days",
                icon: "target",
                points: 40,
                category: .calories,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            
            // Milestone achievements
            Achievement(
                id: "one_week_streak",
                title: "One Week Strong",
                description: "Use the app for 7 consecutive days",
                icon: "flame.fill",
                points: 25,
                category: .milestones,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "one_month_streak",
                title: "Monthly Master",
                description: "Use the app for 30 consecutive days",
                icon: "calendar",
                points: 100,
                category: .milestones,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            
            // Workout-related achievements
            Achievement(
                id: "first_workout",
                title: "First Workout",
                description: "Complete your first workout",
                icon: "figure.run",
                points: 15,
                category: .milestones,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "workout_streak_3",
                title: "3-Day Workout Streak",
                description: "Workout for 3 consecutive days",
                icon: "flame.fill",
                points: 30,
                category: .consistency,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "workout_streak_7",
                title: "7-Day Workout Streak",
                description: "Workout for 7 consecutive days",
                icon: "flame.fill",
                points: 50,
                category: .consistency,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "workout_streak_30",
                title: "30-Day Workout Streak",
                description: "Workout for 30 consecutive days",
                icon: "flame.fill",
                points: 150,
                category: .consistency,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            ),
            Achievement(
                id: "weekly_workout_goal",
                title: "Weekly Warrior",
                description: "Complete 3 workouts in a week",
                icon: "figure.strengthtraining.traditional",
                points: 40,
                category: .consistency,
                progress: 0.0,
                isUnlocked: false,
                unlockDate: nil
            )
        ]
    }
    
    // MARK: - Achievement Checking
    /// Checks and updates all achievements based on current user data
    func checkAchievements() {
        let unlocked = userManager.user.unlockedAchievementIDs ?? []
        for index in achievements.indices where unlocked.contains(achievements[index].id) {
            achievements[index].isUnlocked = true
            achievements[index].progress = 1
        }
        totalPoints = achievements.filter(\.isUnlocked).reduce(0) { $0 + $1.points }
        calculateLevel()
        checkWeightAchievements()
        checkConsistencyAchievements()
        checkCalorieAchievements()
        checkWorkoutAchievements()
        saveAchievements()
    }
    
    /// Checks achievements related to weight tracking
    private func checkWeightAchievements() {
        if userManager.user.weightHistory.contains(where: { $0.date <= Date() }) {
            unlockAchievement(id: "first_weight_entry")
        }
        
        if let goalWeight = userManager.user.goalWeight,
           abs(userManager.user.weight - goalWeight) * (userManager.user.usesMetric ? 1 : 0.45359237) < 0.5 {
            unlockAchievement(id: "weight_goal_reached")
        }
        
        let streak = FitnessMetrics.streak(dates: userManager.user.weightHistory.map(\.date))
        setProgress(id: "weight_consistency", value: Double(streak) / 7)
        if streak >= 7 { unlockAchievement(id: "weight_consistency") }
    }
    
    /// Checks achievements related to consistency
    private func checkConsistencyAchievements() {
        updateStreaks()
        setProgress(id: "one_week_streak", value: Double(currentStreak) / 7)
        setProgress(id: "one_month_streak", value: Double(currentStreak) / 30)
        if currentStreak >= 7 { unlockAchievement(id: "one_week_streak") }
        if currentStreak >= 30 { unlockAchievement(id: "one_month_streak") }
    }
    
    /// Checks achievements related to calorie tracking
    private func checkCalorieAchievements() {
        if userManager.user.calorieHistory.contains(where: { $0.date <= Date() }) { unlockAchievement(id: "first_meal_logged") }
        let streak = FitnessMetrics.streak(dates: userManager.user.calorieHistory.map(\.date))
        setProgress(id: "calorie_goal_met", value: Double(streak) / 3)
        if streak >= 3 { unlockAchievement(id: "calorie_goal_met") }
    }

    /// Checks achievements related to workouts
    private func checkWorkoutAchievements() {
        if userManager.user.workoutHistory.contains(where: { $0.date <= Date() }) {
            unlockAchievement(id: "first_workout")
            
            let calendar = Calendar.current
            let today = Date()
            let workoutStreak = FitnessMetrics.streak(dates: userManager.user.workoutHistory.map(\.date))
            setProgress(id: "workout_streak_3", value: Double(workoutStreak) / 3)
            setProgress(id: "workout_streak_7", value: Double(workoutStreak) / 7)
            setProgress(id: "workout_streak_30", value: Double(workoutStreak) / 30)
            if workoutStreak >= 3 {
                unlockAchievement(id: "workout_streak_3")
            }
            if workoutStreak >= 7 {
                unlockAchievement(id: "workout_streak_7")
            }
            if workoutStreak >= 30 {
                unlockAchievement(id: "workout_streak_30")
            }
            
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? calendar.startOfDay(for: today)
            let workoutsThisWeek = userManager.user.workoutHistory
                .filter { $0.date >= weekStart && $0.date <= today }
                .count
            
            setProgress(id: "weekly_workout_goal", value: Double(workoutsThisWeek) / 3)
            if workoutsThisWeek >= 3 {
                unlockAchievement(id: "weekly_workout_goal")
            }
        }
    }
    
    // MARK: - Achievement Management
    /// Unlocks a specific achievement by ID
    private func unlockAchievement(id: String) {
        if let index = achievements.firstIndex(where: { $0.id == id && !$0.isUnlocked }) {
            var achievement = achievements[index]
            achievement.isUnlocked = true
            achievement.unlockDate = Date()
            achievement.progress = 1.0
            achievements[index] = achievement
            totalPoints += achievement.points
            calculateLevel() // Recalculate level when points change
        }
    }
    
    /// Updates user streaks based on activity
    private func updateStreaks() {
        currentStreak = FitnessMetrics.streak(dates: userManager.user.weightHistory.map(\.date) +
            userManager.user.calorieHistory.map(\.date) + userManager.user.workoutHistory.map(\.date))
    }

    private func setProgress(id: String, value: Double) {
        guard let index = achievements.firstIndex(where: { $0.id == id }), !achievements[index].isUnlocked else { return }
        achievements[index].progress = max(0, min(1, value))
    }

    private func saveAchievements() {
        let ids = Set(achievements.filter(\.isUnlocked).map(\.id))
        if ids != (userManager.user.unlockedAchievementIDs ?? []) {
            userManager.updateUser { $0.unlockedAchievementIDs = ids }
        }
    }
}
