import Foundation
import SwiftUI

/// Manages user data and calculations throughout the app
@MainActor
class UserManager: ObservableObject {
    /// Published user object that will notify views of changes
    @Published var user: User
    
    static let shared = UserManager()
    
    // Maximum number of history records to keep in memory
    private let maxHistoryRecords = 1000
    
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
        
        // Trim history arrays if they exceed the maximum
        trimHistoryArrays()
    }
    
    /// Saves user data to UserDefaults
    func saveUser() {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "user")
        }
    }
    
    /// Trims history arrays to prevent excessive memory usage
    private func trimHistoryArrays() {
        // Sort arrays by date (newest first)
        let sortedWeightHistory = user.weightHistory.sorted(by: { $0.date > $1.date })
        let sortedWorkoutHistory = user.workoutHistory.sorted(by: { $0.date > $1.date })
        let sortedCalorieHistory = user.calorieHistory.sorted(by: { $0.date > $1.date })
        
        // Trim to maximum size
        if sortedWeightHistory.count > maxHistoryRecords {
            user.weightHistory = Array(sortedWeightHistory.prefix(maxHistoryRecords))
        }
        
        if sortedWorkoutHistory.count > maxHistoryRecords {
            user.workoutHistory = Array(sortedWorkoutHistory.prefix(maxHistoryRecords))
        }
        
        if sortedCalorieHistory.count > maxHistoryRecords {
            user.calorieHistory = Array(sortedCalorieHistory.prefix(maxHistoryRecords))
        }
    }
    
    /// Adds a new weight record and trims history if needed
    func addWeightRecord(_ record: WeightRecord) {
        user.weightHistory.append(record)
        trimHistoryArrays()
        saveUser()
    }
    
    /// Adds a new workout record and trims history if needed
    func addWorkoutRecord(_ record: WorkoutRecord) {
        user.workoutHistory.append(record)
        trimHistoryArrays()
        saveUser()
    }
    
    /// Adds a new calorie record and trims history if needed
    func addCalorieRecord(_ record: CalorieRecord) {
        user.calorieHistory.append(record)
        trimHistoryArrays()
        saveUser()
    }
    
    /// Updates the user's current weight
    func updateWeight(_ weight: Double) {
        user.weight = weight
        addWeightRecord(WeightRecord(weight: weight))
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
        
        // Calculate BMR using Harris-Benedict equation
        var bmr: Double
        if user.gender == .male {
            bmr = 88.362 + (13.397 * weightInKg) + (4.799 * heightInCm) - (5.677 * Double(user.age))
        } else {
            bmr = 447.593 + (9.247 * weightInKg) + (3.098 * heightInCm) - (4.330 * Double(user.age))
        }
        
        // Apply activity multiplier
        return bmr * user.activityLevel.multiplier
    }
    
    /// Calculates weekly calorie target based on goal weight
    func calculateWeeklyCalorieTarget() -> Double? {
        guard let goalWeight = user.goalWeight else { return nil }
        
        // Calculate daily maintenance calories
        let maintenanceCalories = calculateDailyCalories()
        
        // Calculate daily deficit/surplus based on goal
        let weightDifference = goalWeight - user.weight
        let weeklyWeightChange = 0.5 // Target 0.5 kg/lbs per week
        
        // Calculate daily calorie adjustment
        // 1 kg of fat = 7700 calories
        let dailyAdjustment = (weeklyWeightChange * 7700) / 7
        
        // Apply adjustment based on whether goal is to lose or gain
        if weightDifference < 0 {
            // Goal is to lose weight
            return maintenanceCalories - dailyAdjustment
        } else if weightDifference > 0 {
            // Goal is to gain weight
            return maintenanceCalories + dailyAdjustment
        } else {
            // No change needed
            return maintenanceCalories
        }
    }
    
    /// Gets the most recent weight record
    func getMostRecentWeight() -> WeightRecord? {
        return user.weightHistory.sorted(by: { $0.date > $1.date }).first
    }
    
    /// Gets the most recent workout record
    func getMostRecentWorkout() -> WorkoutRecord? {
        return user.workoutHistory.sorted(by: { $0.date > $1.date }).first
    }
    
    /// Gets the most recent calorie record
    func getMostRecentCalorie() -> CalorieRecord? {
        return user.calorieHistory.sorted(by: { $0.date > $1.date }).first
    }
    
    /// BMI category with associated health information
    enum BMICategory {
        case underweight
        case normal
        case overweight
        case obese
        
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
    
    func updateHeight(_ height: Double) {
        user.height = height
        saveUser()
    }
    
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
    
    func deleteWorkout(_ workout: WorkoutRecord) {
        user.workoutHistory.removeAll { $0.id == workout.id }
        saveUser()
    }
    
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

extension User {
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
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
} 