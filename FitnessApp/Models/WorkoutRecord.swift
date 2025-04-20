import Foundation

struct WorkoutRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let type: WorkoutType
    let duration: TimeInterval  // in seconds
    let intensity: Intensity
    let exercises: [Exercise]?
    let caloriesBurned: Int?
    let notes: String?
    
    enum WorkoutType: String, Codable, CaseIterable, Identifiable {
        case cardio = "Cardio"
        case strength = "Strength"
        case flexibility = "Flexibility"
        case hiit = "HIIT"
        case yoga = "Yoga"
        case other = "Other"
        
        var id: String { rawValue }
    }
    
    enum Intensity: String, Codable, CaseIterable, Identifiable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        
        var id: String { rawValue }
    }
    
    struct Exercise: Codable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let sets: Int?
        let reps: Int?
        let weight: Double? // in kg
        let duration: TimeInterval? // in seconds
        
        init(id: UUID = UUID(), name: String, sets: Int? = nil, reps: Int? = nil, weight: Double? = nil, duration: TimeInterval? = nil) {
            self.id = id
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.duration = duration
        }
    }
    
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