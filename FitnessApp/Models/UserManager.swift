import Foundation
import SwiftUI

// MARK: - User Manager
/// Central manager for user data, calculations, and persistence throughout the app
@MainActor
class UserManager: ObservableObject {
    // MARK: - Properties
    /// Published user object that will notify views of changes
    @Published private(set) var user: User
    @Published private(set) var persistenceError: String?
    private let storageURL: URL
    private let defaults: UserDefaults
    private var storageReadable = true
    
    /// Singleton instance for app-wide access
    static let shared: UserManager = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let manager = UserManager(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("user.json"),
                defaults: UserDefaults(suiteName: "FitSwift.UITests") ?? .standard)
            if ProcessInfo.processInfo.arguments.contains("--chart-fixtures") { UITestFixtures.populate(manager) }
            return manager
        }
        #endif
        return UserManager()
    }()
    
    // MARK: - Initialization
    /// Initialize with saved user data or defaults
    init(storageURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrivateFitnessData/user.json")
        let fileExists = FileManager.default.fileExists(atPath: self.storageURL.path)
        let savedUser = fileExists ? try? Data(contentsOf: self.storageURL) : defaults.data(forKey: "user")
        if let savedUser, let decodedUser = try? JSONDecoder().decode(User.self, from: savedUser), decodedUser.hasValidMeasurements {
            self.user = decodedUser
        } else {
            if fileExists || savedUser != nil {
                storageReadable = false
                persistenceError = "Saved data could not be read. It has been preserved; changes cannot be saved."
            }
            self.user = User(
                height: 170,
                weight: 70,
                age: 25,
                gender: .other,
                usesMetric: true,
                activityLevel: .moderatelyActive,
                weightHistory: [],
                workoutHistory: [],
                calorieHistory: []
            )
        }
        if !fileExists && storageReadable && savedUser != nil { saveUser() }
    }
    
    // MARK: - Data Persistence
    /// Saves records atomically with complete file protection and migrates legacy defaults.
    @discardableResult
    func saveUser() -> Bool {
        guard storageReadable else { return false }
        return persist(user)
    }

    private func persist(_ candidate: User) -> Bool {
        guard storageReadable else { return false }
        guard candidate.hasValidMeasurements else {
            persistenceError = "Enter valid measurements before saving."
            return false
        }
        do {
            let encoded = try JSONEncoder().encode(candidate)
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedDirectory = directory
            try protectedDirectory.setResourceValues(values)
            try encoded.write(to: storageURL, options: [.atomic, .completeFileProtection])
            var protectedURL = storageURL
            try protectedURL.setResourceValues(values)
            defaults.removeObject(forKey: "user")
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Your changes could not be saved. Please try again after unlocking your device."
            return false
        }
    }

    
    // MARK: - Health Calculations
    /// Calculates user's BMI based on current height and weight
    func calculateBMI() -> Double {
        let heightInMeters = user.usesMetric ? user.height / 100 : user.height * 0.0254
        let weightInKg = user.usesMetric ? user.weight : user.weight * 0.45359237
        guard heightInMeters.isFinite, weightInKg.isFinite, heightInMeters > 0, weightInKg > 0 else { return 0 }
        return weightInKg / (heightInMeters * heightInMeters)
    }
    
    /// Calculates daily caloric needs using Harris-Benedict equation
    func calculateDailyCalories() -> Double {
        let weightInKg = user.usesMetric ? user.weight : user.weight * 0.45359237
        let heightInCm = user.usesMetric ? user.height : user.height * 2.54
        
        let bmr: Double
        switch user.gender {
        case .male:
            bmr = 88.362 + (13.397 * weightInKg) + (4.799 * heightInCm) - (5.677 * Double(user.age))
        case .female:
            bmr = 447.593 + (9.247 * weightInKg) + (3.098 * heightInCm) - (4.330 * Double(user.age))
        case .other:
            bmr = (88.362 + 447.593) / 2 + (11.322 * weightInKg) + (3.9485 * heightInCm) - (5.0035 * Double(user.age))
        }
        
        guard user.age >= 18, user.age <= 100, bmr.isFinite else { return 0 }
        return max(0, min(10000, bmr * user.activityLevel.multiplier))
    }
    
    /// Calculate weekly calorie target based on weight goal
    func calculateWeeklyCalorieTarget() -> Double? {
        guard let goalWeight = user.goalWeight else { return nil }
        
        let weightDiff = (goalWeight - user.weight) * (user.usesMetric ? 1 : 0.45359237)
        let totalCalorieDiff = weightDiff * 7700 // 7700 calories roughly equals 1kg of body weight
        let weeklyCalorieDiff = totalCalorieDiff / 12 // Aim to reach goal in 12 weeks
        let dailyCalorieAdjustment = weeklyCalorieDiff / 7
        
        guard user.age >= 18, user.age <= 100 else { return nil }
        let maintenance = calculateDailyCalories()
        return max(1200, maintenance + max(-500, min(500, dailyCalorieAdjustment)))
    }
    
    // MARK: - BMI Categories
    /// BMI category with associated health information
    enum BMICategory {
        case unavailable
        case underweight
        case normal
        case overweight
        case obese
        
        /// Description of health implications for each BMI category
        var description: String {
            switch self {
            case .unavailable:
                return "Adult BMI categories are unavailable for this age or measurement. Consult a qualified professional for appropriate guidance."
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
        guard user.age >= 18, bmi > 0, bmi.isFinite else { return .unavailable }
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .normal
        case 25..<30: return .overweight
        default: return .obese
        }
    }
    
    // Publish only after disk persistence succeeds. Failed changes remain retryable.
    @discardableResult
    func updateUser(_ change: (inout User) -> Void) -> Bool {
        var candidate = user
        change(&candidate)
        guard persist(candidate) else { return false }
        user = candidate
        return true
    }

    func updateProfile(_ profile: User) -> Bool {
        updateUser {
            $0.height = profile.height; $0.weight = profile.weight; $0.age = profile.age
            $0.gender = profile.gender; $0.usesMetric = profile.usesMetric
            $0.activityLevel = profile.activityLevel; $0.goalWeight = profile.goalWeight
        }
    }

    @discardableResult
    func saveMeal(_ meal: SavedMeal) -> Bool {
        guard meal.isValid else { return false }
        return updateUser {
            var meals = $0.savedMeals ?? []
            if let index = meals.firstIndex(where: { $0.id == meal.id }) { meals[index] = meal }
            else { meals.append(meal) }
            $0.savedMeals = meals
        }
    }

    @discardableResult
    func deleteSavedMeal(_ id: UUID) -> Bool {
        updateUser { $0.savedMeals?.removeAll { $0.id == id } }
    }

    /// A recovered finished session can safely retry after saving the journal succeeded.
    @discardableResult
    func saveCompletedWorkout(_ workout: WorkoutRecord) -> Bool {
        if user.workoutHistory.contains(where: { $0.id == workout.id }) { return true }
        return updateUser { $0.workoutHistory.append(workout) }
    }

    func retryLoadingSavedData() {
        guard !storageReadable,
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(User.self, from: data), decoded.hasValidMeasurements else { return }
        user = decoded
        storageReadable = true
        persistenceError = nil
    }

    func updateWeight(_ weight: Double) { updateUser { $0.weight = weight } }
    func updateHeight(_ height: Double) { updateUser { $0.height = height } }

    @discardableResult
    func addWeight(_ weightInKg: Double, date: Date) -> Bool {
        guard date <= Date(), weightInKg.isFinite, (1...700).contains(weightInKg) else { return false }
        return updateUser {
            let latest = $0.weightHistory.map(\.date).max() ?? .distantPast
            $0.weightHistory.append(WeightRecord(weight: weightInKg, date: date))
            if date >= latest { $0.weight = $0.usesMetric ? weightInKg : weightInKg / 0.45359237 }
        }
    }

    @discardableResult
    func syncWeights(_ records: [WeightRecord]) -> Bool {
        guard storageReadable else { return false }
        let now = Date()
        var ids = Set(user.weightHistory.map(\.id))
        let incoming = records.filter {
            $0.date <= now && $0.weight.isFinite && (1...700).contains($0.weight) && ids.insert($0.id).inserted
        }
        // A repeated import must not rewrite the file or overwrite a manual profile update.
        guard !incoming.isEmpty else { return true }
        let previousLatest = user.weightHistory.map(\.date).max() ?? .distantPast
        return updateUser { user in
            user.weightHistory.append(contentsOf: incoming)
            if let latest = incoming.max(by: { $0.date < $1.date }), latest.date >= previousLatest {
                user.weight = user.usesMetric ? latest.weight : latest.weight / 0.45359237
            }
        }
    }

    @discardableResult
    func syncWorkouts(_ workouts: [WorkoutRecord]) -> Bool {
        guard storageReadable else { return false }
        var ids = Set(user.workoutHistory.map(\.id))
        let incoming = workouts.filter { ids.insert($0.id).inserted }
        guard !incoming.isEmpty else { return true }
        return updateUser { $0.workoutHistory.append(contentsOf: incoming) }
    }

    @discardableResult
    func deleteWorkout(_ workout: WorkoutRecord) -> Bool {
        updateUser { $0.workoutHistory.removeAll { $0.id == workout.id } }
    }
    @discardableResult
    func deleteCalorieRecord(_ record: CalorieRecord) -> Bool {
        updateUser { $0.calorieHistory.removeAll { $0.id == record.id } }
    }
    @discardableResult
    func deleteWeightRecord(_ record: WeightRecord) -> Bool {
        updateUser { $0.weightHistory.removeAll { $0.id == record.id } }
    }
    func toggleUnits() { updateUser { $0.toggleUnits() } }

    /// Convert weight for display based on user's preferred unit system
    func displayWeight(_ weight: Double) -> Double {
        user.usesMetric ? weight : weight / 0.45359237
    }
    
    /// Convert height for display based on user's preferred unit system
    func displayHeight(_ height: Double) -> Double {
        user.usesMetric ? height : height / 2.54
    }
    
    /// Get the weight unit string based on user's preferred unit system
    var weightUnit: String {
        user.usesMetric ? "kg" : "lbs"
    }
    
    /// Get the height unit string based on user's preferred unit system
    var heightUnit: String {
        user.usesMetric ? "cm" : "in"
    }
}

// MARK: - User Unit Conversion
extension User {
    /// Toggle between metric and imperial units, converting all measurements
    mutating func toggleUnits() {
        if usesMetric {
            // Converting from metric to imperial
            height = height / 2.54  // cm to inches
            weight = weight / 0.45359237   // kg to lbs
            if let goal = goalWeight {
                goalWeight = goal / 0.45359237  // kg to lbs
            }
        } else {
            // Converting from imperial to metric
            height = height * 2.54      // inches to cm
            weight = weight * 0.45359237  // lbs to kg
            if let goal = goalWeight {
                goalWeight = goal * 0.45359237  // lbs to kg
            }
        }
        usesMetric.toggle()
    }
}

// MARK: - Double Extension
extension Double {
    /// Round a double to a specific number of decimal places
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
