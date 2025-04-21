import Foundation

/// Service class to handle workout suggestions and planning
class WorkoutSuggestionService: ObservableObject {
    // Singleton instance for app-wide access
    static let shared = WorkoutSuggestionService()
    
    // Reference to ClaudeService for API calls
    private let claudeService = ClaudeService.shared
    
    // Private initializer to enforce singleton pattern
    private init() {}
    
    /// Get workout suggestions based on user's profile and goals
    func getWorkoutSuggestions(for user: User) async throws -> String {
        let prompt = """
        Based on the following user profile, suggest a personalized workout routine:
        - Age: \(user.age)
        - Gender: \(user.gender.rawValue)
        - Height: \(user.height) \(user.usesMetric ? "cm" : "inches")
        - Weight: \(user.weight) \(user.usesMetric ? "kg" : "lbs")
        - Activity Level: \(user.activityLevel.rawValue)
        - Goal Weight: \(user.goalWeight ?? user.weight) \(user.usesMetric ? "kg" : "lbs")
        
        Please provide:
        1. A weekly workout schedule
        2. Specific exercises for each day
        3. Sets, reps, and rest periods
        4. Any necessary equipment
        5. Tips for proper form and progression
        
        Format the response in a clear, easy-to-read structure.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    /// Get exercise suggestions for a specific workout type
    func getExerciseSuggestions(for workoutType: WorkoutRecord.WorkoutType, user: User) async throws -> String {
        let prompt = """
        Suggest exercises for a \(workoutType.rawValue) workout, considering:
        - User's fitness level: \(user.activityLevel.rawValue)
        - Age: \(user.age)
        - Weight: \(user.weight) \(user.usesMetric ? "kg" : "lbs")
        
        For each exercise, provide:
        1. Name and description
        2. Sets and reps
        3. Rest periods
        4. Equipment needed
        5. Form tips
        6. Modifications for different fitness levels
        
        Format the response in a clear, easy-to-read structure.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
    
    /// Get a complete workout plan based on user's goals
    func getWorkoutPlan(for user: User) async throws -> String {
        let prompt = """
        Create a comprehensive 12-week workout plan for the following user:
        - Age: \(user.age)
        - Gender: \(user.gender.rawValue)
        - Height: \(user.height) \(user.usesMetric ? "cm" : "inches")
        - Weight: \(user.weight) \(user.usesMetric ? "kg" : "lbs")
        - Activity Level: \(user.activityLevel.rawValue)
        - Goal Weight: \(user.goalWeight ?? user.weight) \(user.usesMetric ? "kg" : "lbs")
        
        Include:
        1. Weekly progression
        2. Exercise selection and progression
        3. Rest days and recovery
        4. Nutrition recommendations
        5. Progress tracking methods
        6. Modifications for different fitness levels
        
        Format the response in a clear, easy-to-read structure with weekly breakdowns.
        """
        
        return try await claudeService.makeRequest(prompt: prompt)
    }
} 