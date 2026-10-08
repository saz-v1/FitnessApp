import Foundation

/// Main user model containing all user-related data and preferences
struct User: Codable, Equatable {
    // Basic user measurements
    var height: Double          // User's height in cm or inches
    var weight: Double          // User's weight in kg or pounds
    var age: Int               // User's age
    var gender: Gender          // User's selected gender
    
    // User preferences
    var usesMetric: Bool        // Whether to use metric or imperial units
    var activityLevel: ActivityLevel  // User's activity level for calorie calculations
    
    // User goals
    var unlockedAchievementIDs: Set<String>?
    var goalWeight: Double?     // Target weight goal in kg or pounds
    
    // History records
    var weightHistory: [WeightRecord] // History of weight measurements
    var workoutHistory: [WorkoutRecord] // History of workouts
    var calorieHistory: [CalorieRecord] // History of calorie intake
    var savedMeals: [SavedMeal]? = nil
    
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
        
        // Multiplier for BMR calculation based on activity level
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
    let weight: Double // kilograms, independent of display preference
    
    // Initialize with current date if not specified
    init(id: UUID = UUID(), weight: Double, date: Date = Date()) {
        self.id = id
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
    let foods: [MealFood]?
    
    // Types of meals for categorization
    enum MealType: String, Codable, CaseIterable, Identifiable, Equatable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
        
        var id: String { rawValue }
    }
    
    // Initialize with current date if not specified
    init(id: UUID = UUID(), calories: Double, mealType: MealType, description: String? = nil, date: Date = Date(), foods: [MealFood]? = nil) {
        self.id = id
        self.calories = calories
        self.mealType = mealType
        self.description = description
        self.date = date
        self.foods = foods
    }
}
// Bound numeric values before calculations or conversion to integer UI labels.
extension User {
    var hasValidProfile: Bool {
        let heightRange: ClosedRange<Double> = usesMetric ? 30...300 : (30 / 2.54)...(300 / 2.54)
        let weightRange: ClosedRange<Double> = usesMetric ? 1...700 : (1 / 0.45359237)...(700 / 0.45359237)
        guard height.isFinite, heightRange.contains(height), weight.isFinite, weightRange.contains(weight),
              (1...120).contains(age) else { return false }
        if let goalWeight, !goalWeight.isFinite || !weightRange.contains(goalWeight) { return false }
        return true
    }
    func hasSameProfile(as other: User) -> Bool {
        height == other.height && weight == other.weight && age == other.age &&
        gender == other.gender && usesMetric == other.usesMetric &&
        activityLevel == other.activityLevel && goalWeight == other.goalWeight
    }
    var hasValidMeasurements: Bool {
        guard hasValidProfile else { return false }
        if let savedMeals, savedMeals.count > 500 || !savedMeals.allSatisfy(\.isValid) || Set(savedMeals.map(\.id)).count != savedMeals.count { return false }
        let dateRange = Date(timeIntervalSince1970: -2208988800)...Date(timeIntervalSince1970: 4133980800)
        guard weightHistory.allSatisfy({ dateRange.contains($0.date) }),
              calorieHistory.allSatisfy({ dateRange.contains($0.date) }),
              workoutHistory.allSatisfy({ dateRange.contains($0.date) }) else { return false }
        guard Set(weightHistory.map(\.id)).count == weightHistory.count,
              Set(workoutHistory.map(\.id)).count == workoutHistory.count,
              Set(calorieHistory.map(\.id)).count == calorieHistory.count else { return false }
        return weightHistory.allSatisfy { $0.weight.isFinite && $0.weight > 0 && $0.weight <= 1543 } &&
            calorieHistory.allSatisfy { $0.calories.isFinite && (0...10000).contains($0.calories) &&
                ($0.foods.map { $0.count <= 100 && $0.allSatisfy(\.isValid) && Set($0.map(\.id)).count == $0.count } ?? true) } &&
            workoutHistory.allSatisfy { workout in
                workout.duration.isFinite && (0...604800).contains(workout.duration) &&
                (workout.caloriesBurned.map { (0...100000).contains($0) } ?? true) &&
                (workout.exercises?.allSatisfy { exercise in
                    (exercise.sets.map { (1...1000).contains($0) } ?? true) &&
                    (exercise.reps.map { (1...10000).contains($0) } ?? true) &&
                    (exercise.weight.map { $0.isFinite && (0...2000).contains($0) } ?? true) &&
                    (exercise.duration.map { $0.isFinite && (0...604800).contains($0) } ?? true)
                    && (exercise.completedSets.map { $0.count <= 1000 && $0.allSatisfy(\.isValid) } ?? true)
                } ?? true)
            }
    }
}
