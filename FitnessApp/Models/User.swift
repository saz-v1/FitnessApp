import Foundation

/// Represents a user in the fitness app with their profile information and preferences
struct User: Codable, Identifiable {
    /// Unique identifier for the user
    let id: UUID
    /// User's full name
    let name: String
    /// User's email address
    let email: String
    /// User's date of birth
    let dateOfBirth: Date
    /// User's gender
    let gender: Gender
    /// User's height in centimeters
    let height: Double
    /// User's current weight in kilograms
    let weight: Double
    /// User's target weight in kilograms
    let targetWeight: Double
    /// User's activity level
    let activityLevel: ActivityLevel
    /// User's fitness goals
    let goals: [FitnessGoal]
    /// User's preferred units of measurement
    let preferredUnits: MeasurementUnits
    /// Whether the user has enabled HealthKit integration
    let healthKitEnabled: Bool
    /// Date when the user's profile was last updated
    let lastUpdated: Date
    
    /// Gender options for user profiles
    enum Gender: String, Codable, CaseIterable {
        /// Male gender
        case male = "Male"
        /// Female gender
        case female = "Female"
        /// Other gender
        case other = "Other"
        /// Prefer not to specify
        case notSpecified = "Not Specified"
    }
    
    /// Activity level categories for calculating daily calorie needs
    enum ActivityLevel: String, Codable, CaseIterable {
        /// Sedentary lifestyle with little to no exercise
        case sedentary = "Sedentary"
        /// Light activity with light exercise 1-3 days/week
        case lightlyActive = "Lightly Active"
        /// Moderate activity with moderate exercise 3-5 days/week
        case moderatelyActive = "Moderately Active"
        /// Very active with hard exercise 6-7 days/week
        case veryActive = "Very Active"
        /// Extremely active with very hard exercise daily
        case extremelyActive = "Extremely Active"
    }
    
    /// Fitness goals that users can set
    enum FitnessGoal: String, Codable, CaseIterable {
        /// Goal to lose weight
        case weightLoss = "Weight Loss"
        /// Goal to maintain current weight
        case maintenance = "Maintenance"
        /// Goal to gain weight
        case weightGain = "Weight Gain"
        /// Goal to build muscle
        case muscleGain = "Muscle Gain"
        /// Goal to improve endurance
        case endurance = "Endurance"
        /// Goal to improve flexibility
        case flexibility = "Flexibility"
    }
    
    /// Units of measurement preferences
    struct MeasurementUnits: Codable {
        /// Weight unit preference (metric or imperial)
        let weight: WeightUnit
        /// Height unit preference (metric or imperial)
        let height: HeightUnit
        /// Distance unit preference (metric or imperial)
        let distance: DistanceUnit
        
        /// Weight measurement units
        enum WeightUnit: String, Codable {
            /// Kilograms (metric)
            case kilograms = "kg"
            /// Pounds (imperial)
            case pounds = "lbs"
        }
        
        /// Height measurement units
        enum HeightUnit: String, Codable {
            /// Centimeters (metric)
            case centimeters = "cm"
            /// Inches (imperial)
            case inches = "in"
        }
        
        /// Distance measurement units
        enum DistanceUnit: String, Codable {
            /// Kilometers (metric)
            case kilometers = "km"
            /// Miles (imperial)
            case miles = "mi"
        }
    }
    
    /// Creates a new user with the specified parameters
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - name: User's full name
    ///   - email: User's email address
    ///   - dateOfBirth: User's date of birth
    ///   - gender: User's gender
    ///   - height: User's height in centimeters
    ///   - weight: User's current weight in kilograms
    ///   - targetWeight: User's target weight in kilograms
    ///   - activityLevel: User's activity level
    ///   - goals: User's fitness goals
    ///   - preferredUnits: User's preferred units of measurement
    ///   - healthKitEnabled: Whether HealthKit is enabled
    ///   - lastUpdated: Last update timestamp (defaults to current date)
    init(id: UUID = UUID(), name: String, email: String, dateOfBirth: Date, gender: Gender, height: Double, weight: Double, targetWeight: Double, activityLevel: ActivityLevel, goals: [FitnessGoal], preferredUnits: MeasurementUnits, healthKitEnabled: Bool = false, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.height = height
        self.weight = weight
        self.targetWeight = targetWeight
        self.activityLevel = activityLevel
        self.goals = goals
        self.preferredUnits = preferredUnits
        self.healthKitEnabled = healthKitEnabled
        self.lastUpdated = lastUpdated
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