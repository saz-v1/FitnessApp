import Foundation

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    let description: String
    let calories: Int
    let timestamp: Date
    
    init(id: UUID = UUID(), description: String, calories: Int, timestamp: Date = Date()) {
        self.id = id
        self.description = description
        self.calories = calories
        self.timestamp = timestamp
    }
} 