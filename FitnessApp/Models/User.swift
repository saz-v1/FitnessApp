import Foundation

/// Main user model containing all user-related data and preferences
struct User: Codable, Equatable {
    var height: Double          // User's height in cm or inches
    var weight: Double          // User's weight in kg or pounds
    var age: Int               // User's age
    var gender: Gender          // User's selected gender
    var usesMetric: Bool        // Whether to use metric or imperial units
    var activityLevel: ActivityLevel  // User's activity level for calorie calculations
    var goalWeight: Double?     // Target weight goal in kg or pounds
    var weightHistory: [WeightRecord] // History of weight measurements
    var workoutHistory: [WorkoutRecord] // History of workouts
    var calorieHistory: [CalorieRecord] // History of calorie intake
    
    /// Gender options available to the user
    enum Gender: String, Codable, CaseIterable, Identifiable, Equatable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
        
        var id: String { rawValue }
    }
    
    /// Activity levels with corresponding calorie multipliers
    enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Equatable {
        case sedentary = "Sedentary"
        case lightlyActive = "Lightly Active"
        case moderatelyActive = "Moderately Active"
        case veryActive = "Very Active"
        case extraActive = "Extra Active"
        
        var id: String { rawValue }
        
        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .lightlyActive: return 1.375
            case .moderatelyActive: return 1.55
            case .veryActive: return 1.725
            case .extraActive: return 1.9
            }
        }
    }
}

/// Record of a single weight measurement
struct WeightRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    
    init(weight: Double, date: Date = Date()) {
        self.id = UUID()
        self.weight = weight
        self.date = date
    }
}

/// Record of a single calorie intake
struct CalorieRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let calories: Double
    let mealType: MealType
    let description: String?
    
    enum MealType: String, Codable, CaseIterable, Identifiable, Equatable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
        
        var id: String { rawValue }
    }
    
    init(calories: Double, mealType: MealType, description: String? = nil, date: Date = Date()) {
        self.id = UUID()
        self.calories = calories
        self.mealType = mealType
        self.description = description
        self.date = date
    }
} 