import Foundation
import SwiftUI

@MainActor
class FoodEntryViewModel: ObservableObject {
    @Published var foodEntries: [FoodEntry] = []
    @Published var currentDescription: String = ""
    @Published var isEstimating: Bool = false
    @Published var errorMessage: String?
    
    private let claudeService = ClaudeService.shared
    
    func addFoodEntry() async {
        guard !currentDescription.isEmpty else { return }
        
        isEstimating = true
        errorMessage = nil
        
        do {
            let calories = try await claudeService.estimateCalories(foodDescription: currentDescription)
            
            if calories >= 0 {
                let entry = FoodEntry(description: currentDescription, calories: calories)
                foodEntries.append(entry)
                currentDescription = ""
            } else {
                errorMessage = "Could not estimate calories for this food item. Please try a more detailed description."
            }
        } catch let error as ClaudeError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        isEstimating = false
    }
    
    func removeFoodEntry(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
    }
} 