import SwiftUI

private enum FoodLibrarySource: String, CaseIterable, Identifiable {
    case all = "All", uk = "UK", us = "US"
    var id: String { rawValue }
    var source: FoodSource? {
        switch self {
        case .all: nil
        case .uk: .cofid
        case .us: .usda
        }
    }
}

struct FoodLibraryView: View {
    var onSelect: ((MealFood) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = ActivityCatalog.shared
    @State private var query = ""
    @State private var category = "All"
    @State private var sourceFilter: FoodLibrarySource = .all
    @FocusState private var searchFocused: Bool
    private var source: FoodSource? { sourceFilter.source }
    private var results: [FoodCatalogEntry] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && category == "All" {
            let featuredIDs = [1_000_140_318, 1_000_111_107, 173944, 171287, 168878, 171477, 171265]
            return featuredIDs.compactMap { catalog.food(id: $0) }.filter { source == nil || $0.resolvedSource == source }
                + catalog.findFoods("", source: source, limit: 30).filter { !featuredIDs.contains($0.id) }
        }
        return catalog.findFoods(query, category: category, source: source)
    }
    private var foodCount: Int { source.map { catalog.foodCount(source: $0) } ?? catalog.foods.count }
    var body: some View {
        List {
            Section {
                Picker("Food source", selection: $sourceFilter) {
                    ForEach(FoodLibrarySource.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("food-source")
                Picker("Category", selection: $category) {
                    Text("All").tag("All")
                    ForEach(catalog.foodCategories(source: source), id: \.self) { Text($0).tag($0) }
                }
                Text("\(foodCount.formatted()) reference foods · search by food and preparation")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if catalog.loading { ProgressView("Loading offline library") }
            if let error = catalog.errorMessage { Text(error).foregroundStyle(.red) }
            ForEach(results) { food in
                NavigationLink {
                    FoodPortionView(food: food, onSelect: onSelect.map { action in { serving in action(serving); dismiss() } })
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(food.name).font(.headline)
                        Text("\(food.resolvedSource.label) · \(food.kcalPer100g.formatted(.number.precision(.fractionLength(0...1)))) kcal / 100 g")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }.accessibilityIdentifier("food-\(food.id)")
            }
            if !catalog.loading && results.isEmpty { Text("No matching foods. Try fewer words or another category.").foregroundStyle(.secondary) }
            Section {
                Text("UK: McCance and Widdowson's CoFID (2021). Contains public sector information licensed under the Open Government Licence. US: USDA FoodData Central, SR Legacy (2018), public domain / CC0.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Values vary with preparation and brand. Similar foods from each source remain separate. Check raw versus cooked before selecting. Trace or missing nutrient amounts are shown as unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
                if !query.isEmpty { Text("Showing up to 100 matches. Refine your search for more specific results.").font(.caption).foregroundStyle(.secondary) }
            }
        }.appForm().navigationTitle("Food library").appScreen()
            .searchable(text: $query, prompt: "e.g. banana or rice cooked")
            .searchFocused($searchFocused)
            .onSubmit(of: .search) { searchFocused = false }
            .onChange(of: sourceFilter) { _, value in
                if category != "All" && !catalog.foodCategories(source: value.source).contains(category) { category = "All" }
            }
            .task { await catalog.load() }
            .toolbar { if onSelect != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
    }
}

struct FoodPortionView: View {
    let food: FoodCatalogEntry
    var onSelect: ((MealFood) -> Void)?
    private let servingID: UUID
    @Environment(\.locale) private var locale
    @FocusState private var editing: Bool
    @State private var gramsText: String
    @State private var quantityText = "1"
    @State private var portionIndex = 0
    @State private var usePortions = false
    @State private var loggingMeal = false
    init(food: FoodCatalogEntry, grams: Double = 100, servingID: UUID = UUID(), onSelect: ((MealFood) -> Void)? = nil) {
        self.food = food; self.onSelect = onSelect; self.servingID = servingID
        _gramsText = State(initialValue: grams.formatted(.number.locale(Locale.current).grouping(.never).precision(.fractionLength(0...3))))
    }
    private var serving: MealFood? {
        let grams: Double?
        if usePortions, food.portions.indices.contains(portionIndex) {
            grams = LocalizedDecimal.parse(quantityText, locale: locale).map { $0 * food.portions[portionIndex].grams }
        } else { grams = LocalizedDecimal.parse(gramsText, locale: locale) }
        guard let grams else { return nil }
        let result = MealFood(food: food, grams: grams, id: servingID)
        return result.isValid && result.calories <= 10000 ? result : nil
    }
    var body: some View {
        Form {
            Section {
                Text(food.name).font(.title3.weight(.semibold))
                Text(food.category).font(.caption).foregroundStyle(.secondary)
                Text(food.resolvedSource.label).font(.caption).foregroundStyle(AppTheme.accent)
            }
            Section("Your portion") {
                if !food.portions.isEmpty {
                    Picker("Measure", selection: $usePortions) { Text("Grams").tag(false); Text("Portions").tag(true) }.pickerStyle(.segmented)
                }
                if usePortions {
                    Picker("Portion", selection: $portionIndex) {
                        ForEach(food.portions.indices, id: \.self) { index in
                            Text("\(food.portions[index].name) (\(food.portions[index].grams.formatted()) g)").tag(index)
                        }
                    }
                    TextField("Number of portions", text: $quantityText).keyboardType(.decimalPad).focused($editing)
                        .accessibilityIdentifier("food-portion-count")
                } else {
                    HStack {
                        Text("Weight")
                        TextField("Grams", text: $gramsText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($editing)
                            .accessibilityIdentifier("food-grams")
                        Text("g").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Estimated nutrition") {
                if let serving {
                    DetailRow(title: "Energy", value: "\(serving.calories.formatted(.number.precision(.fractionLength(0...1)))) kcal")
                    DetailRow(title: "Portion weight", value: "\(serving.grams.formatted(.number.precision(.fractionLength(0...1)))) g")
                    nutrient("Protein", value: food.protein, grams: serving.grams)
                    nutrient("Carbohydrate", value: food.carbohydrate, grams: serving.grams)
                    nutrient("Fat", value: food.fat, grams: serving.grams)
                } else { Text("Enter a valid portion between 0.1 and 10,000 g.").foregroundStyle(.secondary) }
            }
            Section {
                Button(onSelect == nil ? "Use in a meal" : "Add food") {
                    guard let serving else { return }
                    editing = false
                    if let onSelect { onSelect(serving) } else { loggingMeal = true }
                }.buttonStyle(AppPrimaryButtonStyle()).disabled(serving == nil).accessibilityIdentifier("add-food-portion")
            }.listRowBackground(Color.clear)
            Section {
                Text("Source: \(food.resolvedSource.citation), \(food.resolvedSource == .cofid ? "food code" : "FDC ID") \(food.referenceCode). These are reference estimates; your actual food may differ.")
                    .font(.caption).foregroundStyle(.secondary)
                if let note = food.sourceNote { Text(note).font(.caption).foregroundStyle(.secondary) }
                if food.resolvedSource == .cofid {
                    Text("Contains public sector information licensed under the Open Government Licence.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.appForm().navigationTitle("Food & portion").appScreen()
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
            .sheet(isPresented: $loggingMeal) { if let serving { AddCalorieSheet(seedFoods: [serving]) } }
    }
    private func nutrient(_ title: String, value: Double?, grams: Double) -> some View {
        DetailRow(title: title, value: value.map { "\(($0 * grams / 100).formatted(.number.precision(.fractionLength(0...1)))) g" } ?? "Unavailable")
    }
}

struct ExerciseLibraryView: View {
    var onSelect: ((ExerciseCatalogEntry) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = ActivityCatalog.shared
    @State private var query = ""
    @State private var category = "All"
    @FocusState private var searchFocused: Bool
    var body: some View {
        List {
            Section {
                Picker("Muscle group / activity", selection: $category) {
                    Text("All").tag("All")
                    ForEach(catalog.exerciseCategories, id: \.self) { Text($0).tag($0) }
                }
                Text("\(catalog.exercises.count) movements · search by name, muscle or equipment")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if catalog.loading { ProgressView("Loading offline library") }
            if let error = catalog.errorMessage { Text(error).foregroundStyle(.red) }
            ForEach(catalog.findExercises(query, category: category)) { entry in
                HStack(spacing: 12) {
                    NavigationLink {
                        ExerciseReferenceView(entry: entry, onSelect: onSelect.map { action in { exercise in action(exercise); dismiss() } })
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.name).font(.headline)
                            Text("\(entry.category) · \(entry.equipment)").font(.caption).foregroundStyle(.secondary)
                            Text(entry.muscles.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    if let onSelect {
                        Button { onSelect(entry); dismiss() } label: { Image(systemName: "plus.circle.fill").font(.title2).frame(width: 48, height: 48) }
                            .buttonStyle(.borderless).accessibilityLabel("Select \(entry.name)")
                            .accessibilityIdentifier("exercise-pick-\(entry.id)")
                    }
                }
            }
            if !catalog.loading && catalog.findExercises(query, category: category).isEmpty {
                Text("No matching movements. Try another name or equipment.").foregroundStyle(.secondary)
            }
        }.appForm().navigationTitle("Exercise library").appScreen()
            .searchable(text: $query, prompt: "e.g. squat, chest or dumbbell")
            .searchFocused($searchFocused)
            .onSubmit(of: .search) { searchFocused = false }
            .task { await catalog.load() }
            .toolbar { if onSelect != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
    }
}

struct ExerciseReferenceView: View {
    let entry: ExerciseCatalogEntry
    var onSelect: ((ExerciseCatalogEntry) -> Void)? = nil
    var body: some View {
        Form {
            Section { AppScreenHeader(title: entry.name, subtitle: entry.category, icon: "figure.strengthtraining.traditional") }
            Section("Movement") {
                DetailRow(title: "Muscles", value: entry.muscles.joined(separator: ", "))
                DetailRow(title: "Equipment", value: entry.equipment)
                DetailRow(title: "Track with", value: entry.tracking.rawValue)
            }
            Section("Quick reference") {
                Text(entry.instructions)
                Text("Choose a comfortable load and range. Stop if you feel pain; seek qualified instruction for unfamiliar movements.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let onSelect {
                Section { Button("Use this exercise") { onSelect(entry) }.buttonStyle(AppPrimaryButtonStyle()) }.listRowBackground(Color.clear)
            }
            Section { Text("FitSwift original movement reference").font(.caption).foregroundStyle(.secondary) }
        }.appForm().navigationTitle("Exercise reference").appScreen()
    }
}
