import Foundation

/// Service class to handle workout analytics and insights
@MainActor
class WorkoutAnalyticsService: ObservableObject {
    static let shared = WorkoutAnalyticsService()
    private let claudeService = ClaudeService.shared
    
    private init() {}
    
    /// Get personalized workout insights based on user's history and health metrics
    func getWorkoutInsights(for user: User) async throws -> String {
        // Limit the dataset to the last 3 months for more relevant insights
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let recentWorkouts = user.workoutHistory.filter { $0.date >= threeMonthsAgo }
        
        // Calculate some basic metrics
        let weeklyWorkouts = calculateWeeklyWorkoutFrequency(workouts: recentWorkouts)
        let mostCommonWorkout = findMostCommonWorkoutType(workouts: recentWorkouts)
        let averageDuration = calculateAverageWorkoutDuration(workouts: recentWorkouts)
        
        let prompt = """
        Analyze this user's workout patterns and provide personalized insights:
        
        User Profile:
        - Age: \(user.age)
        - Activity Level: \(user.activityLevel.rawValue)
        - Weekly Workout Frequency: \(weeklyWorkouts) sessions
        - Most Common Workout: \(mostCommonWorkout?.rawValue ?? "No data")
        - Average Workout Duration: \(Int(averageDuration)) minutes
        
        Recent Progress:
        \(getRecentProgressSummary(workouts: recentWorkouts))
        
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
        
        Please provide:
        1. A brief warm-up
        2. 5-7 exercises with sets and reps
        3. A cool-down
        4. Estimated calorie burn
        
        Keep it simple and focused on efficiency.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    /// Get a targeted workout suggestion based on a specific muscle group or focus area
    func getTargetedWorkoutSuggestion(for user: User, focusArea: String) async throws -> String {
        let prompt = """
        Suggest a targeted workout for this user focusing on: \(focusArea)
        
        User Profile:
        - Activity Level: \(user.activityLevel.rawValue)
        - Available Time: 30-45 minutes
        - Equipment: Basic home equipment
        
        Provide:
        1. A focused workout targeting the \(focusArea)
        2. 4-6 specific exercises with clear instructions
        3. Sets, reps, and rest periods
        4. Proper form tips for each exercise
        5. Modifications for different fitness levels
        
        Keep it simple, effective, and focused on the \(focusArea).
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    // MARK: - Analytics Methods
    
    /// Calculate the average number of workouts per week
    private func calculateWeeklyWorkoutFrequency(workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        
        // Group workouts by week
        let calendar = Calendar.current
        let groupedByWeek = Dictionary(grouping: workouts) { workout in
            let components = calendar.dateComponents([.year, .weekOfYear], from: workout.date)
            return calendar.date(from: components)!
        }
        
        // Calculate average workouts per week
        let totalWeeks = Double(groupedByWeek.count)
        let totalWorkouts = Double(workouts.count)
        
        return totalWeeks > 0 ? totalWorkouts / totalWeeks : 0
    }
    
    /// Find the most common workout type
    private func findMostCommonWorkoutType(workouts: [WorkoutRecord]) -> WorkoutRecord.WorkoutType? {
        guard !workouts.isEmpty else { return nil }
        
        // Count occurrences of each workout type
        let typeCounts = workouts.reduce(into: [:]) { counts, workout in
            counts[workout.type, default: 0] += 1
        }
        
        // Find the type with the highest count
        return typeCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Calculate the average duration of workouts in minutes
    private func calculateAverageWorkoutDuration(workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(workouts.count) / 60 // Convert seconds to minutes
    }
    
    /// Get a summary of recent workout progress
    private func getRecentProgressSummary(workouts: [WorkoutRecord]) -> String {
        guard !workouts.isEmpty else { return "No recent workouts recorded." }
        
        // Sort workouts by date
        let sortedWorkouts = workouts.sorted { $0.date < $1.date }
        
        // Get the first and last workout
        let firstWorkout = sortedWorkouts.first!
        let lastWorkout = sortedWorkouts.last!
        
        // Calculate time span
        let daysBetween = Calendar.current.dateComponents([.day], from: firstWorkout.date, to: lastWorkout.date).day ?? 0
        
        // Calculate total workout time
        let totalMinutes = Double(workouts.reduce(0) { $0 + $1.duration }) / 60
        
        return """
        - Started tracking \(firstWorkout.date.formatted(date: .abbreviated, time: .omitted))
        - \(daysBetween) days of activity
        - \(workouts.count) total workouts
        - \(Int(totalMinutes)) total minutes of exercise
        - Most recent: \(lastWorkout.type.rawValue) on \(lastWorkout.date.formatted(date: .abbreviated, time: .omitted))
        """
    }
} 