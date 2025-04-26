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
                title: "Calorie Master",
                description: "Meet your calorie goal for 3 days in a row",
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
        checkWeightAchievements()
        checkConsistencyAchievements()
        checkCalorieAchievements()
        checkWorkoutAchievements()
        updateStreaks()
        saveAchievements()
    }
    
    /// Checks achievements related to weight tracking
    private func checkWeightAchievements() {
        if !userManager.user.weightHistory.isEmpty {
            unlockAchievement(id: "first_weight_entry")
        }
        
        if let goalWeight = userManager.user.goalWeight,
           abs(userManager.user.weight - goalWeight) < 0.5 {
            unlockAchievement(id: "weight_goal_reached")
        }
        
        let calendar = Calendar.current
        let today = Date()
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        
        let weightEntriesLastWeek = userManager.user.weightHistory
            .filter { $0.date >= lastWeek }
            .count
        
        if weightEntriesLastWeek >= 7 {
            unlockAchievement(id: "weight_consistency")
        }
    }
    
    /// Checks achievements related to consistency
    private func checkConsistencyAchievements() {
        let calendar = Calendar.current
        let today = Date()
        
        let activityDays = Set(
            userManager.user.weightHistory.map { calendar.startOfDay(for: $0.date) } +
            userManager.user.calorieHistory.map { calendar.startOfDay(for: $0.date) }
        )
        
        var streak = 0
        var currentDate = today
        
        while activityDays.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        currentStreak = streak
        
        if streak >= 7 {
            unlockAchievement(id: "one_week_streak")
        }
        if streak >= 30 {
            unlockAchievement(id: "one_month_streak")
        }
    }
    
    /// Checks achievements related to calorie tracking
    private func checkCalorieAchievements() {
        if !userManager.user.calorieHistory.isEmpty {
            unlockAchievement(id: "first_meal_logged")
        }
    }
    
    /// Checks achievements related to workouts
    private func checkWorkoutAchievements() {
        if !userManager.user.workoutHistory.isEmpty {
            unlockAchievement(id: "first_workout")
            
            let calendar = Calendar.current
            let today = Date()
            let workoutDates = Set(userManager.user.workoutHistory.map { 
                calendar.startOfDay(for: $0.date)
            })
            
            var workoutStreak = 0
            var currentDate = today
            
            while workoutDates.contains(currentDate) {
                workoutStreak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            }
            
            if workoutStreak >= 3 {
                unlockAchievement(id: "workout_streak_3")
            }
            if workoutStreak >= 7 {
                unlockAchievement(id: "workout_streak_7")
            }
            if workoutStreak >= 30 {
                unlockAchievement(id: "workout_streak_30")
            }
            
            let weekStart = calendar.date(byAdding: .day, value: -7, to: today)!
            let workoutsThisWeek = userManager.user.workoutHistory
                .filter { $0.date >= weekStart }
                .count
            
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let activityDays = Set(
            userManager.user.weightHistory.map { calendar.startOfDay(for: $0.date) } +
            userManager.user.calorieHistory.map { calendar.startOfDay(for: $0.date) }
        )
        
        var streak = 0
        var currentDate = today
        
        while activityDays.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        currentStreak = streak
    }
    
    // MARK: - Data Persistence
    /// Saves achievements and related data to UserDefaults
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: "achievements")
        }
        UserDefaults.standard.set(totalPoints, forKey: "totalPoints")
        UserDefaults.standard.set(currentStreak, forKey: "currentStreak")
        UserDefaults.standard.set(currentLevel, forKey: "currentLevel")
    }
} 