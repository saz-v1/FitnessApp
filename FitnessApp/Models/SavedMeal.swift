import Foundation

/// A snapshot keeps logged portions stable even after reference data is updated.
struct MealFood: Codable, Equatable, Identifiable {
    let id: UUID
    let foodID: Int
    let name: String
    var grams: Double
    let kcalPer100g: Double
    let proteinPer100g: Double?
    let carbohydratePer100g: Double?
    let fatPer100g: Double?
    let source: FoodSource?
    let sourceCode: String?
    let sourceNote: String?
    var resolvedSource: FoodSource { source ?? .usda }
    var calories: Double { kcalPer100g * grams / 100 }
    var isValid: Bool {
        foodID > 0 && !name.isEmpty && name.count <= 500 && grams.isFinite && (0.1...10000).contains(grams) &&
        kcalPer100g.isFinite && (0...1000).contains(kcalPer100g) &&
        [proteinPer100g, carbohydratePer100g, fatPer100g].allSatisfy { $0.map { $0.isFinite && (0...100).contains($0) } ?? true } &&
        (sourceCode?.count ?? 0) <= 80 && (sourceNote?.count ?? 0) <= 1000
    }
    init(food: FoodCatalogEntry, grams: Double, id: UUID = UUID()) {
        self.id = id; foodID = food.id; name = food.name; self.grams = grams
        kcalPer100g = food.kcalPer100g; proteinPer100g = food.protein
        carbohydratePer100g = food.carbohydrate; fatPer100g = food.fat
        source = food.resolvedSource; sourceCode = food.referenceCode; sourceNote = food.sourceNote
    }
}

struct SavedMeal: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    let calories: Double
    let mealType: CalorieRecord.MealType
    let description: String?
    let foods: [MealFood]?
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120 &&
        calories.isFinite && (0.01...10000).contains(calories) && (description?.count ?? 0) <= 2000 &&
        (foods.map { $0.count <= 100 && $0.allSatisfy(\.isValid) && Set($0.map(\.id)).count == $0.count } ?? true)
    }
    init(id: UUID = UUID(), name: String, calories: Double, mealType: CalorieRecord.MealType,
         description: String? = nil, foods: [MealFood]? = nil) {
        self.id = id; self.name = name; self.calories = calories; self.mealType = mealType
        self.description = description; self.foods = foods
    }
}
