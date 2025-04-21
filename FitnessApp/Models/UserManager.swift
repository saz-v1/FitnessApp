import Foundation
import SwiftUI

/// Manages user data and calculations throughout the app
class UserManager: ObservableObject {
    /// Published user object that will notify views of changes
    @Published var user: User
    
    /// Singleton instance for app-wide access
    static let shared = UserManager()
    
    /// Initialize with saved user data or defaults
    init() {
        // Attempt to load saved user data from UserDefaults
        if let savedUser = UserDefaults.standard.data(forKey: "user"),
           let decodedUser = try? JSONDecoder().decode(User.self, from: savedUser) {
            self.user = decodedUser
        } else {
            // Set default values if no saved data exists
            self.user = User(
                height: 170,
                weight: 70,
                age: 25,           // Add default age
                gender: .other,
                usesMetric: true,
                activityLevel: .moderatelyActive,
                weightHistory: [],
                workoutHistory: [],
                calorieHistory: []
            )
        }
    }
    
    /// Saves user data to UserDefaults
    func saveUser() {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "user")
        }
    }
    
    /// Calculates user's BMI based on current height and weight
    func calculateBMI() -> Double {
        let heightInMeters = user.usesMetric ? user.height / 100 : user.height * 0.0254
        let weightInKg = user.usesMetric ? user.weight : user.weight * 0.453592
        return weightInKg / (heightInMeters * heightInMeters)
    }
    
    /// Calculates daily caloric needs using Harris-Benedict equation
    func calculateDailyCalories() -> Double {
        // Convert measurements to metric for calculation
        let weightInKg = user.usesMetric ? user.weight : user.weight * 0.453592
        let heightInCm = user.usesMetric ? user.height : user.height * 2.54
        
        // Calculate base metabolic rate (BMR)
        let bmr: Double
        switch user.gender {
        case .male:
            bmr = 88.362 + (13.397 * weightInKg) + (4.799 * heightInCm) - (5.677 * 25)
        case .female:
            bmr = 447.593 + (9.247 * weightInKg) + (3.098 * heightInCm) - (4.330 * 25)
        case .other:
            // Use average of male and female calculations
            bmr = (88.362 + 447.593) / 2 + (11.322 * weightInKg) + (3.9485 * heightInCm) - (5.0035 * 25)
        }
        
        // Apply activity level multiplier to get total daily energy expenditure
        return bmr * user.activityLevel.multiplier
    }
    
    /// BMI category with associated health information
    enum BMICategory {
        case underweight
        case normal
        case overweight
        case obese
        
        /// Description of health implications for each BMI category
        var description: String {
            switch self {
            case .underweight:
                return "Underweight: Being underweight can indicate nutritional deficiencies or other health issues. Consider consulting a healthcare provider."
            case .normal:
                return "Normal weight: Your BMI is within the healthy range. Maintain a balanced diet and regular exercise."
            case .overweight:
                return "Overweight: Being overweight may increase health risks. Focus on balanced nutrition and regular physical activity."
            case .obese:
                return "Obese: Obesity can lead to various health complications. Consider consulting a healthcare provider for personalized advice."
            }
        }
    }
    
    /// Get BMI category and description
    func getBMICategory() -> BMICategory {
        let bmi = calculateBMI()
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .normal
        case 25..<30: return .overweight
        default: return .obese
        }
    }
    
    /// Calculate weekly calorie target based on weight goal
    func calculateWeeklyCalorieTarget() -> Double? {
        guard let goalWeight = user.goalWeight else { return nil }
        
        let weightDiff = goalWeight - user.weight
        // 7700 calories roughly equals 1kg of body weight
        let totalCalorieDiff = weightDiff * 7700
        
        // Aim to reach goal in 12 weeks (safe weight loss/gain rate)
        let weeklyCalorieDiff = totalCalorieDiff / 12
        
        // Daily calorie adjustment
        let dailyCalorieAdjustment = weeklyCalorieDiff / 7
        
        return calculateDailyCalories() + dailyCalorieAdjustment
    }
    
    /// Update user's weight and save changes
    func updateWeight(_ weight: Double) {
        user.weight = weight
        saveUser()
    }
    
    /// Update user's height and save changes
    func updateHeight(_ height: Double) {
        user.height = height
        saveUser()
    }
    
    /// Sync workouts from external sources, avoiding duplicates
    func syncWorkouts(_ workouts: [WorkoutRecord]) {
        // Create a set of existing workout identifiers (date + type combination)
        let existingWorkoutIdentifiers = Set(user.workoutHistory.map { 
            "\($0.date.formatted(date: .numeric, time: .omitted))-\($0.type.rawValue)"
        })
        
        // Only add workouts that don't already exist
        let newWorkouts = workouts.filter { workout in
            let identifier = "\(workout.date.formatted(date: .numeric, time: .omitted))-\(workout.type.rawValue)"
            return !existingWorkoutIdentifiers.contains(identifier)
        }
        
        if !newWorkouts.isEmpty {
            user.workoutHistory.append(contentsOf: newWorkouts)
            saveUser()
        }
    }
    
    /// Delete a specific workout from history
    func deleteWorkout(_ workout: WorkoutRecord) {
        user.workoutHistory.removeAll { $0.id == workout.id }
        saveUser()
    }
    
    /// Toggle between metric and imperial units
    func toggleUnits() {
        user.toggleUnits()
        saveUser()
    }
    
    // Helper function to convert weight for display
    func displayWeight(_ weight: Double) -> Double {
        user.usesMetric ? weight : (weight * 2.20462).rounded(to: 1)
    }
    
    // Helper function to convert height for display
    func displayHeight(_ height: Double) -> Double {
        user.usesMetric ? height : (height * 0.393701).rounded(to: 1)
    }
    
    // Helper function to get the weight unit string
    var weightUnit: String {
        user.usesMetric ? "kg" : "lbs"
    }
    
    // Helper function to get the height unit string
    var heightUnit: String {
        user.usesMetric ? "cm" : "in"
    }
}

/// Extension to add unit conversion functionality to User
extension User {
    /// Toggle between metric and imperial units, converting all measurements
    mutating func toggleUnits() {
        if usesMetric {
            // Converting from metric to imperial
            height = (height * 0.393701).rounded(to: 1)  // cm to inches
            weight = (weight * 2.20462).rounded(to: 1)   // kg to lbs
            if let goal = goalWeight {
                goalWeight = (goal * 2.20462).rounded(to: 1)  // kg to lbs
            }
        } else {
            // Converting from imperial to metric
            height = (height * 2.54).rounded(to: 1)      // inches to cm
            weight = (weight * 0.453592).rounded(to: 1)  // lbs to kg
            if let goal = goalWeight {
                goalWeight = (goal * 0.453592).rounded(to: 1)  // lbs to kg
            }
        }
        usesMetric.toggle()
    }
}

// Helper extension for rounding to specific decimal places
extension Double {
    /// Round a double to a specific number of decimal places
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
} 