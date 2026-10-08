import Foundation
import SwiftUI

enum FoodSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case cofid, usda
    var id: String { rawValue }
    var region: String { self == .cofid ? "UK" : "US" }
    var label: String { self == .cofid ? "UK · CoFID" : "US · USDA" }
    var citation: String {
        self == .cofid ? "McCance and Widdowson's CoFID (2021)" : "USDA FoodData Central · SR Legacy (2018)"
    }
}

struct FoodPortion: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let grams: Double
    var id: String { name }
}

struct FoodCatalogEntry: Codable, Identifiable, Equatable, Sendable {
    let id: Int // Original USDA IDs; a separate namespace for UK CoFID entries.
    let name: String
    let category: String
    let kcalPer100g: Double
    let protein: Double?
    let carbohydrate: Double?
    let fat: Double?
    let portions: [FoodPortion]
    let source: FoodSource?
    let sourceCode: String?
    let sourceNote: String?
    // Older bundled entries and saved foods predate source fields and are USDA.
    var resolvedSource: FoodSource { source ?? .usda }
    var referenceCode: String { sourceCode ?? String(id) }

    init(id: Int, name: String, category: String, kcalPer100g: Double, protein: Double?,
         carbohydrate: Double?, fat: Double?, portions: [FoodPortion], source: FoodSource? = nil,
         sourceCode: String? = nil, sourceNote: String? = nil) {
        self.id = id; self.name = name; self.category = category; self.kcalPer100g = kcalPer100g
        self.protein = protein; self.carbohydrate = carbohydrate; self.fat = fat; self.portions = portions
        self.source = source; self.sourceCode = sourceCode; self.sourceNote = sourceNote
    }

    var isValid: Bool {
        id > 0 && !name.isEmpty && name.count <= 500 && kcalPer100g.isFinite && (0...1000).contains(kcalPer100g) &&
        [protein, carbohydrate, fat].allSatisfy { $0.map { $0.isFinite && (0...100).contains($0) } ?? true } &&
        portions.allSatisfy { !$0.name.isEmpty && $0.grams.isFinite && (0.01...10000).contains($0.grams) } &&
        (sourceCode?.count ?? 0) <= 80 && (sourceNote?.count ?? 0) <= 1000 &&
        (source != .cofid || (id >= 1_000_000_000 && sourceCode?.isEmpty == false))
    }
}

enum ExerciseTracking: String, Codable, CaseIterable, Identifiable, Sendable {
    case repetitions = "Reps", timed = "Time", laps = "Laps"
    var id: String { rawValue }
}

struct ExerciseCatalogEntry: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let category: String
    let muscles: [String]
    let equipment: String
    let tracking: ExerciseTracking
    let instructions: String
    let aliases: [String]
    var searchText: String { ([name, category, equipment] + muscles + aliases).joined(separator: " ").catalogSearchKey }
    var isValid: Bool { !id.isEmpty && !name.isEmpty && !instructions.isEmpty && name.count <= 200 }
}

extension String {
    var catalogSearchKey: String { folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_GB")) }
}

/// Public reference data is decoded once off the main thread; searches use cached keys.
@MainActor
final class ActivityCatalog: ObservableObject {
    static let shared = ActivityCatalog()
    @Published private(set) var foods: [FoodCatalogEntry] = []
    @Published private(set) var exercises: [ExerciseCatalogEntry] = []
    @Published private(set) var loading = false
    @Published private(set) var errorMessage: String?
    private var foodKeys: [String] = []
    private var foodIndex: [Int: FoodCatalogEntry] = [:]
    private var exerciseIndex: [String: ExerciseCatalogEntry] = [:]
    private(set) var foodCategories: [String] = []
    private var sourceFoodCategories: [FoodSource: [String]] = [:]
    private var sourceFoodCounts: [FoodSource: Int] = [:]
    private(set) var exerciseCategories: [String] = []

    func load(bundle: Bundle = .main) async {
        guard !loading, foods.isEmpty || exercises.isEmpty else { return }
        loading = true
        defer { loading = false }
        let foodURL = bundle.url(forResource: "foods", withExtension: "json")
        let ukFoodURL = bundle.url(forResource: "foods-uk", withExtension: "json")
        let exerciseURL = bundle.url(forResource: "exercises", withExtension: "json")
        do {
            guard let foodURL, let ukFoodURL, let exerciseURL else { throw CocoaError(.fileNoSuchFile) }
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.readSnapshot(foodURL: foodURL, ukFoodURL: ukFoodURL, exerciseURL: exerciseURL)
            }.value
            foods = result.0; exercises = result.1; foodKeys = result.2
            foodIndex = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
            exerciseIndex = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
            foodCategories = Array(Set(foods.map(\.category))).sorted()
            let bySource = Dictionary(grouping: foods, by: \.resolvedSource)
            sourceFoodCounts = bySource.mapValues { $0.count }
            sourceFoodCategories = bySource.mapValues { Array(Set($0.map(\.category))).sorted() }
            exerciseCategories = Array(Set(exercises.map(\.category))).sorted()
            errorMessage = nil
        } catch {
            errorMessage = "The bundled reference library could not be loaded. Manual logging is still available."
        }
    }

    private nonisolated static func readSnapshot(foodURL: URL, ukFoodURL: URL, exerciseURL: URL) throws
        -> ([FoodCatalogEntry], [ExerciseCatalogEntry], [String]) {
        let decoder = JSONDecoder()
        let usFoods = try decoder.decode([FoodCatalogEntry].self, from: Data(contentsOf: foodURL))
        let ukFoods = try decoder.decode([FoodCatalogEntry].self, from: Data(contentsOf: ukFoodURL))
        let combined = usFoods + ukFoods
        let exercises = try decoder.decode([ExerciseCatalogEntry].self, from: Data(contentsOf: exerciseURL))
        guard !usFoods.isEmpty, !ukFoods.isEmpty, !exercises.isEmpty,
              combined.allSatisfy(\.isValid), exercises.allSatisfy(\.isValid),
              Set(combined.map(\.id)).count == combined.count,
              Set(exercises.map(\.id)).count == exercises.count else { throw CocoaError(.coderReadCorrupt) }
        let indexed: [(food: FoodCatalogEntry, name: String)] = combined.map { ($0, $0.name.catalogSearchKey) }
        let sorted = indexed.sorted {
            $0.name == $1.name ? $0.food.id < $1.food.id : $0.name < $1.name
        }
        let foods = sorted.map { $0.food }
        let keys = sorted.map { item in
            let terms = [item.name, item.food.category, item.food.resolvedSource.label]
            return terms.joined(separator: " ").catalogSearchKey
        }
        return (foods, exercises, keys)
    }

    func food(id: Int) -> FoodCatalogEntry? { foodIndex[id] }
    func foodCount(source: FoodSource) -> Int { sourceFoodCounts[source] ?? 0 }
    func foodCategories(source: FoodSource?) -> [String] {
        source.map { sourceFoodCategories[$0] ?? [] } ?? foodCategories
    }
    func exercise(id: String) -> ExerciseCatalogEntry? { exerciseIndex[id] }

    func findFoods(_ query: String, category: String = "All", source: FoodSource? = nil, limit: Int = 100) -> [FoodCatalogEntry] {
        let terms = query.catalogSearchKey.split(whereSeparator: \.isWhitespace).map(String.init)
        var result: [FoodCatalogEntry] = []
        for (index, food) in foods.enumerated() {
            if let source, food.resolvedSource != source { continue }
            if category != "All" && food.category != category { continue }
            if terms.allSatisfy({ foodKeys[index].contains($0) }) {
                result.append(food)
                if result.count >= max(1, limit) { break }
            }
        }
        return result
    }

    func findExercises(_ query: String, category: String = "All") -> [ExerciseCatalogEntry] {
        let terms = query.catalogSearchKey.split(whereSeparator: \.isWhitespace).map(String.init)
        return exercises.filter { (category == "All" || $0.category == category) && terms.allSatisfy($0.searchText.contains) }
    }
}
