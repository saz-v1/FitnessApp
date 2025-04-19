import Foundation

struct WorkoutRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let type: WorkoutType
    let duration: TimeInterval  // in seconds
    let notes: String?
    
    enum WorkoutType: String, Codable, CaseIterable, Identifiable {
        case cardio = "Cardio"
        case strength = "Strength"
        case flexibility = "Flexibility"
        case other = "Other"
        
        var id: String { rawValue }
    }
    
    init(id: UUID = UUID(), date: Date = Date(), type: WorkoutType, duration: TimeInterval, notes: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.notes = notes
    }
} 