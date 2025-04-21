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
    func calculateWeeklyWorkoutFrequency(workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0.0 }
        
        // Sort workouts by date
        let sortedWorkouts = workouts.sorted { $0.date < $1.date }
        
        // Get the date range
        guard let firstWorkout = sortedWorkouts.first,
              let lastWorkout = sortedWorkouts.last else {
            return 0.0
        }
        
        // Calculate the number of weeks between first and last workout
        let calendar = Calendar.current
        let weeks = calendar.dateComponents([.weekOfYear], 
                                         from: firstWorkout.date, 
                                         to: lastWorkout.date).weekOfYear ?? 1
        
        // Calculate average workouts per week
        return Double(workouts.count) / Double(max(1, weeks))
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
    
    func calculateWorkoutIntensity(workout: Workout) -> WorkoutIntensity {
        // Calculate average heart rate percentage of max
        let maxHeartRate = 220 - Double(UserManager.shared.user.age)
        let avgHeartRatePercentage = (workout.averageHeartRate / maxHeartRate) * 100
        
        // Calculate intensity based on heart rate zones
        switch avgHeartRatePercentage {
        case 0..<60:
            return .low
        case 60..<70:
            return .moderate
        case 70..<80:
            return .high
        default:
            return .veryHigh
        }
    }
    
    func calculateCaloriesBurned(workout: Workout) -> Int {
        // Basic calorie calculation based on workout type and duration
        let baseCaloriesPerMinute: Double
        
        switch workout.type {
        case .strength:
            baseCaloriesPerMinute = 4.0
        case .cardio:
            baseCaloriesPerMinute = 8.0
        case .flexibility:
            baseCaloriesPerMinute = 2.0
        case .hiit:
            baseCaloriesPerMinute = 10.0
        }
        
        // Adjust for intensity
        let intensityMultiplier: Double
        switch workout.intensity {
        case .low:
            intensityMultiplier = 0.8
        case .moderate:
            intensityMultiplier = 1.0
        case .high:
            intensityMultiplier = 1.2
        case .veryHigh:
            intensityMultiplier = 1.4
        }
        
        // Calculate total calories
        let durationInMinutes = workout.duration / 60
        let calories = baseCaloriesPerMinute * durationInMinutes * intensityMultiplier
        
        // Adjust for user's weight
        let weightMultiplier = UserManager.shared.user.weight / 70.0 // Normalize to 70kg
        let adjustedCalories = calories * weightMultiplier
        
        return Int(adjustedCalories)
    }
    
    func generateWorkoutInsights(workouts: [Workout]) -> [WorkoutInsight] {
        var insights: [WorkoutInsight] = []
        
        // Calculate weekly frequency
        let weeklyFrequency = calculateWeeklyWorkoutFrequency(workouts: workouts)
        
        // Add frequency insight
        if weeklyFrequency < 3 {
            insights.append(WorkoutInsight(
                title: "Increase Workout Frequency",
                description: "Try to work out at least 3 times per week for optimal results.",
                type: .suggestion
            ))
        } else if weeklyFrequency >= 5 {
            insights.append(WorkoutInsight(
                title: "Great Workout Frequency",
                description: "You're maintaining a consistent workout schedule. Keep it up!",
                type: .achievement
            ))
        }
        
        // Analyze workout types
        let typeCounts = Dictionary(grouping: workouts, by: { $0.type })
            .mapValues { $0.count }
        
        // Check for variety
        if typeCounts.count < 3 {
            insights.append(WorkoutInsight(
                title: "Add Workout Variety",
                description: "Try incorporating different types of workouts for better overall fitness.",
                type: .suggestion
            ))
        }
        
        // Analyze intensity levels
        let highIntensityWorkouts = workouts.filter { $0.intensity == .high || $0.intensity == .veryHigh }
        let highIntensityPercentage = Double(highIntensityWorkouts.count) / Double(workouts.count)
        
        if highIntensityPercentage < 0.2 {
            insights.append(WorkoutInsight(
                title: "Increase Intensity",
                description: "Try to include more high-intensity workouts in your routine.",
                type: .suggestion
            ))
        }
        
        return insights
    }
}

struct WorkoutInsight {
    let title: String
    let description: String
    let type: InsightType
}

enum InsightType {
    case suggestion
    case achievement
    case warning
}

enum WorkoutIntensity: String, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
} 