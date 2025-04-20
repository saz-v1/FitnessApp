import Foundation

/// Service class to handle workout analytics and insights
class WorkoutAnalyticsService: ObservableObject {
    static let shared = WorkoutAnalyticsService()
    private let claudeService = ClaudeService.shared
    
    private init() {}
    
    /// Get personalized workout insights based on user's history and health metrics
    func getWorkoutInsights(for user: User) async throws -> String {
        // Calculate some basic metrics
        let weeklyWorkouts = calculateWeeklyWorkoutFrequency(workouts: user.workoutHistory)
        let mostCommonWorkout = findMostCommonWorkoutType(workouts: user.workoutHistory)
        let averageDuration = calculateAverageWorkoutDuration(workouts: user.workoutHistory)
        
        let prompt = """
        Analyze this user's workout patterns and provide personalized insights:
        
        User Profile:
        - Age: \(user.age)
        - Activity Level: \(user.activityLevel.rawValue)
        - Weekly Workout Frequency: \(weeklyWorkouts) sessions
        - Most Common Workout: \(mostCommonWorkout?.rawValue ?? "No data")
        - Average Workout Duration: \(Int(averageDuration)) minutes
        
        Recent Progress:
        \(getRecentProgressSummary(workouts: user.workoutHistory))
        
        Please provide:
        1. Analysis of current workout patterns
        2. Areas for improvement
        3. Specific recommendations based on their goals
        4. Suggested adjustments to their routine
        5. Progress tracking tips
        
        Keep the response concise and actionable.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    /// Get a simplified workout suggestion based on user's current state
    func getQuickWorkoutSuggestion(for user: User) async throws -> String {
        let prompt = """
        Suggest a quick, effective workout for this user:
        - Activity Level: \(user.activityLevel.rawValue)
        - Available Time: 30-45 minutes
        - Equipment: Basic home equipment
        
        Provide:
        1. A simple 3-part workout (warmup, main workout, cooldown)
        2. 4-6 exercises with clear instructions
        3. Rest periods and timing
        4. Modifications for different fitness levels
        
        Keep it simple and easy to follow.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    // MARK: - Helper Methods
    
    private func calculateWeeklyWorkoutFrequency(workouts: [WorkoutRecord]) -> Int {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        return workouts.filter { workout in
            workout.date >= oneWeekAgo
        }.count
    }
    
    private func findMostCommonWorkoutType(workouts: [WorkoutRecord]) -> WorkoutRecord.WorkoutType? {
        let types = workouts.map { $0.type }
        return types.reduce(into: [:]) { counts, type in
            counts[type, default: 0] += 1
        }.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateAverageWorkoutDuration(workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(workouts.count)
    }
    
    private func getRecentProgressSummary(workouts: [WorkoutRecord]) -> String {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date())!
        
        let recentWorkouts = workouts.filter { $0.date >= twoWeeksAgo }
        // Removed unused weeklyCounts variable
        
        return """
        Last 2 weeks:
        - Total workouts: \(recentWorkouts.count)
        - Weekly average: \(Double(recentWorkouts.count) / 2.0) workouts
        - Most active day: \(findMostActiveDay(workouts: recentWorkouts))
        """
    }
    
    private func findMostActiveDay(workouts: [WorkoutRecord]) -> String {
        let calendar = Calendar.current
        let dayCounts = workouts.reduce(into: [Int: Int]()) { counts, workout in
            let weekday = calendar.component(.weekday, from: workout.date)
            counts[weekday, default: 0] += 1
        }
        
        guard let mostActiveDay = dayCounts.max(by: { $0.value < $1.value })?.key else {
            return "No data"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        let date = calendar.date(from: DateComponents(weekday: mostActiveDay))!
        return dateFormatter.string(from: date)
    }
} 