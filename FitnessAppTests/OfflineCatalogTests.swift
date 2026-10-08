import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct OfflineCatalogTests {
    @Test func bundledCatalogsLoadAndHaveStableUniqueIDs() async {
        let catalog = ActivityCatalog()
        await catalog.load()
        #expect(catalog.errorMessage == nil)
        #expect(catalog.foods.count == 10625)
        #expect(catalog.foodCount(source: .usda) == 7793)
        #expect(catalog.foodCount(source: .cofid) == 2832)
        #expect(catalog.exercises.count == 106)
        #expect(catalog.foods.allSatisfy { $0.isValid })
        #expect(catalog.exercises.allSatisfy { $0.isValid })
        #expect(catalog.food(id: 173944)?.name == "Bananas, raw")
        #expect(catalog.findExercises("rdl").contains { $0.id == "romanian-deadlift" })
        #expect(catalog.findExercises("dumbbell", category: "Chest").allSatisfy { $0.category == "Chest" })
        #expect(catalog.exercise(id: "running")?.tracking == .laps)
        #expect(catalog.exercise(id: "plank")?.tracking == .timed)
    }
    @Test func portionCalculationsUseMassAndPreserveSourceSnapshot() async throws {
        let catalog = ActivityCatalog(); await catalog.load()
        let banana = try #require(catalog.food(id: 173944))
        let serving = MealFood(food: banana, grams: 150)
        #expect(serving.calories == 133.5)
        #expect(serving.foodID == banana.id)
        #expect(serving.isValid)
        let roundtrip = try JSONDecoder().decode(MealFood.self, from: JSONEncoder().encode(serving))
        #expect(roundtrip == serving)
        var invalid = serving; invalid.grams = .nan
        #expect(!invalid.isValid)
        invalid.grams = -1
        #expect(!invalid.isValid)
    }
    @Test func foodSearchMatchesAllWordsAndHasBoundedResults() async {
        let catalog = ActivityCatalog(); await catalog.load()
        let results = catalog.findFoods("rice cooked")
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.name.lowercased().contains("rice") && $0.name.lowercased().contains("cooked") })
        #expect(catalog.findFoods("", limit: 20).count == 20)
        #expect(catalog.findFoods("no-such-food-abcdef").isEmpty)
        #expect(catalog.findFoods("banana", source: .cofid).allSatisfy { $0.resolvedSource == .cofid })
        #expect(catalog.findFoods("banana", source: .usda).allSatisfy { $0.resolvedSource == .usda })
        #expect(catalog.findFoods("banana uk").contains { $0.id == 1_000_140_318 })
        #expect(catalog.foodCategories(source: .cofid).contains("Cereals and cereal products"))
    }
    @Test func ukAndUSFoodsKeepSeparateNutritionAndSourceSnapshots() async throws {
        let catalog = ActivityCatalog(); await catalog.load()
        let uk = try #require(catalog.food(id: 1_000_140_318))
        let us = try #require(catalog.food(id: 173944))
        #expect(uk.kcalPer100g == 81 && us.kcalPer100g == 89)
        let portion = MealFood(food: uk, grams: 150)
        #expect(portion.calories == 121.5)
        #expect(portion.source == .cofid && portion.sourceCode == "14-318")
        let decoded = try JSONDecoder().decode(MealFood.self, from: JSONEncoder().encode(portion))
        #expect(decoded == portion)
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = UserManager(storageURL: url, defaults: defaults)
        let preset = SavedMeal(name: "UK banana", calories: portion.calories, mealType: .snack, foods: [portion])
        #expect(manager.saveMeal(preset))
        #expect(UserManager(storageURL: url, defaults: defaults).user.savedMeals == [preset])
    }
    @Test func ukAlcoholUsesPublishedDensityAndAmbiguousCodesDoNotOverwriteFoods() async throws {
        let catalog = ActivityCatalog(); await catalog.load()
        let cider = try #require(catalog.food(id: 1_000_170_222))
        let portion = try #require(cider.portions.first)
        #expect(portion.name == "100 ml" && portion.grams == 101)
        #expect(abs(MealFood(food: cider, grams: portion.grams).calories - 36) < 0.0001)
        #expect(cider.sourceNote != nil)
        // Beer with no density and shandy with an implausible 0.50 density are omitted.
        #expect(!catalog.foods.contains { $0.sourceCode == "17-506" || $0.sourceCode == "17-760" })
        let sharedCode = catalog.foods.filter { $0.sourceCode == "13-669" }
        #expect(sharedCode.count == 2 && Set(sharedCode.map(\.id)).count == 2)
        #expect(sharedCode.first { $0.name == "Watercress, raw" }?.kcalPer100g == 10)
        #expect(sharedCode.first { $0.name.hasPrefix("Aubergine") }?.kcalPer100g == 62)
    }
    @Test func savedFoodBeforeSourceFieldsStillDecodesAsUSDA() async throws {
        let catalog = ActivityCatalog(); await catalog.load()
        let banana = try #require(catalog.food(id: 173944))
        let portion = MealFood(food: banana, grams: 150)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(portion)) as? [String: Any])
        for key in ["source", "sourceCode", "sourceNote"] { json.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(MealFood.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.source == nil && legacy.resolvedSource == .usda)
        #expect(legacy.foodID == 173944 && legacy.calories == 133.5)
        #expect(legacy.isValid)
    }
    @Test func legacyJournalDecodesWithoutNewFields() throws {
        let manager = makeManager()
        let original = manager.user
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "savedMeals")
        let decoded = try JSONDecoder().decode(User.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == original)
        #expect(decoded.savedMeals == nil)
        let legacyMeal = Data("{\"id\":\"6F1D2A40-51DD-43D6-A89D-C617F6385BA7\",\"date\":0,\"calories\":500,\"mealType\":\"Lunch\"}".utf8)
        #expect(try JSONDecoder().decode(CalorieRecord.self, from: legacyMeal).foods == nil)
        let legacyExercise = Data("{\"id\":\"6F1D2A40-51DD-43D6-A89D-C617F6385BA7\",\"name\":\"Squat\",\"sets\":3,\"reps\":10}".utf8)
        let exercise = try JSONDecoder().decode(WorkoutRecord.Exercise.self, from: legacyExercise)
        #expect(exercise.completedSets == nil && exercise.catalogID == nil)
    }
    @Test func savedMealsReloadAndDeletingTemplateKeepsJournal() throws {
        let url = tempURL(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = UserManager(storageURL: url, defaults: defaults)
        let preset = SavedMeal(name: "Lunch bowl", calories: 650, mealType: .lunch)
        #expect(manager.saveMeal(preset))
        #expect(manager.updateUser { $0.calorieHistory.append(CalorieRecord(calories: preset.calories, mealType: preset.mealType)) })
        let loaded = UserManager(storageURL: url, defaults: defaults)
        #expect(loaded.user.savedMeals == [preset])
        #expect(loaded.deleteSavedMeal(preset.id))
        #expect(loaded.user.savedMeals?.isEmpty == true)
        #expect(loaded.user.calorieHistory.count == 1)
    }
    @Test func invalidTemplatesAndDuplicateIDsAreRejected() {
        let manager = makeManager()
        #expect(!manager.saveMeal(SavedMeal(name: " ", calories: 500, mealType: .snack)))
        #expect(!manager.saveMeal(SavedMeal(name: "Snack", calories: .infinity, mealType: .snack)))
        let preset = SavedMeal(name: "Snack", calories: 500, mealType: .snack)
        #expect(!manager.updateUser { $0.savedMeals = [preset, preset] })
        #expect(manager.user.savedMeals == nil)
    }
    private func tempURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("user.json") }
    private func makeManager() -> UserManager { UserManager(storageURL: tempURL(), defaults: UserDefaults(suiteName: UUID().uuidString)!) }
}
