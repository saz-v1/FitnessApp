import Foundation

/// Represents a single workout session with all associated data
struct WorkoutRecord: Identifiable, Codable, Equatable {
    /// Unique identifier for the workout record
    let id: UUID
    /// Date and time when the workout was performed
    let date: Date
    /// Type of workout (e.g., cardio, strength, etc.)
    let type: WorkoutType
    /// Duration of the workout in seconds
    let duration: TimeInterval  // in seconds
    /// Intensity level of the workout
    let intensity: Intensity
    /// Optional list of exercises performed during the workout
    let exercises: [Exercise]?
    /// Optional estimate of calories burned during the workout
    let caloriesBurned: Int?
    /// Optional notes or comments about the workout
    let notes: String?
    
    /// Types of workouts available in the app
    enum WorkoutType: String, Codable, CaseIterable, Identifiable {
        /// Cardiovascular exercise (e.g., running, cycling)
        case cardio = "Cardio"
        /// Strength training exercises
        case strength = "Strength"
        /// Flexibility and stretching exercises
        case flexibility = "Flexibility"
        /// High-intensity interval training
        case hiit = "HIIT"
        /// Yoga and similar practices
        case yoga = "Yoga"
        /// Other types of workouts
        case other = "Other"
        
        /// Unique identifier for the workout type
        var id: String { rawValue }
    }
    
    /// Intensity levels for workouts
    enum Intensity: String, Codable, CaseIterable, Identifiable {
        /// Low-intensity workout (e.g., walking, gentle yoga)
        case low = "Low"
        /// Moderate-intensity workout (e.g., jogging, moderate weight training)
        case moderate = "Moderate"
        /// High-intensity workout (e.g., running, heavy weight training)
        case high = "High"
        /// Very high-intensity workout (e.g., sprinting, HIIT)
        case veryHigh = "Very High"
        
        /// Unique identifier for the intensity level
        var id: String { rawValue }
    }
    
    /// Represents a single exercise within a workout
    struct Exercise: Codable, Equatable, Identifiable {
        /// Unique identifier for the exercise
        let id: UUID
        /// Name of the exercise
        let name: String
        /// Number of sets performed (optional)
        let sets: Int?
        /// Number of repetitions per set (optional)
        let reps: Int?
        /// Weight used in kilograms (optional)
        let weight: Double? // in kg
        /// Duration of the exercise in seconds (optional)
        let duration: TimeInterval? // in seconds
        
        /// Creates a new exercise with the specified parameters
        /// - Parameters:
        ///   - id: Unique identifier (defaults to a new UUID)
        ///   - name: Name of the exercise
        ///   - sets: Number of sets (optional)
        ///   - reps: Number of repetitions per set (optional)
        ///   - weight: Weight used in kilograms (optional)
        ///   - duration: Duration in seconds (optional)
        init(id: UUID = UUID(), name: String, sets: Int? = nil, reps: Int? = nil, weight: Double? = nil, duration: TimeInterval? = nil) {
            self.id = id
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.duration = duration
        }
    }
    
    /// Creates a new workout record with the specified parameters
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - date: Date and time of the workout (defaults to current date)
    ///   - type: Type of workout
    ///   - duration: Duration in seconds
    ///   - intensity: Intensity level (defaults to moderate)
    ///   - exercises: List of exercises (optional)
    ///   - caloriesBurned: Estimated calories burned (optional)
    ///   - notes: Additional notes (optional)
    init(id: UUID = UUID(), date: Date = Date(), type: WorkoutType, duration: TimeInterval, intensity: Intensity = .moderate, exercises: [Exercise]? = nil, caloriesBurned: Int? = nil, notes: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.intensity = intensity
        self.exercises = exercises
        self.caloriesBurned = caloriesBurned
        self.notes = notes
    }
} 