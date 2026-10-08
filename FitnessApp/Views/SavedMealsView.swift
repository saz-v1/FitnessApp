import SwiftUI

struct SaveMealPresetSheet: View {
    let record: CalorieRecord
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Saved meal") {
                    TextField("Meal name", text: $name)
                    DetailRow(title: "Energy", value: "\(record.calories.formatted()) kcal")
                }
                if let error = userManager.persistenceError { Text(error).foregroundStyle(.red) }
            }.appForm().navigationTitle("Save a meal").appScreen()
                .onAppear { if name.isEmpty { name = String((record.description ?? record.mealType.rawValue + " meal").prefix(120)) } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        if userManager.saveMeal(SavedMeal(name: name.trimmingCharacters(in: .whitespacesAndNewlines), calories: record.calories,
                            mealType: record.mealType, description: record.description, foods: record.foods)) { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 120 || record.calories <= 0 || (userManager.user.savedMeals ?? []).count >= 500) }
                }
        }
    }
}

struct SavedMealsView: View {
    var onSelect: ((SavedMeal) -> Void)? = nil
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var loggingMeal: SavedMeal?
    @State private var deletingMeal: SavedMeal?
    var body: some View {
        List {
            Section {
                Text("Reusable meals stay on this device. Choose one, adjust its portion or calories, and save a new journal entry.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if (userManager.user.savedMeals ?? []).isEmpty {
                Text("No saved meals yet. Turn on ‘Save for next time’ when adding a meal.").foregroundStyle(.secondary)
            }
            ForEach((userManager.user.savedMeals ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { meal in
                Button {
                    if let onSelect { onSelect(meal); dismiss() } else { loggingMeal = meal }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(meal.name).font(.headline).foregroundStyle(.primary)
                        Text("\(meal.calories.formatted(.number.precision(.fractionLength(0...1)))) kcal · \(meal.mealType.rawValue)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if let foods = meal.foods, !foods.isEmpty { Text("\(foods.count) foods").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 5)
                }.accessibilityIdentifier("saved-meal-\(meal.id)")
                    .swipeActions { Button("Delete", role: .destructive) { deletingMeal = meal } }
            }
            if let error = userManager.persistenceError { Text(error).foregroundStyle(.red) }
        }.appForm().navigationTitle("Saved meals").appScreen()
            .toolbar { if onSelect != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } }
            .sheet(item: $loggingMeal) { AddCalorieSheet(preset: $0) }
            .alert("Delete saved meal?", isPresented: Binding(get: { deletingMeal != nil }, set: { if !$0 { deletingMeal = nil } })) {
                Button("Delete", role: .destructive) { if let meal = deletingMeal { userManager.deleteSavedMeal(meal.id) }; deletingMeal = nil }
                Button("Cancel", role: .cancel) { deletingMeal = nil }
            } message: { Text("Existing journal entries are kept.") }
    }
}

struct AddCalorieSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var userManager: UserManager
    @StateObject private var catalog = ActivityCatalog.shared
    @State private var caloriesText: String
    @State private var mealType: CalorieRecord.MealType
    @State private var description: String
    @State private var foods: [MealFood]
    @State private var useFoods: Bool
    @State private var date = Date()
    @State private var saveForNextTime = false
    @State private var mealName: String
    @State private var pickingFood = false
    @State private var pickingSavedMeal = false
    @State private var editingFood: MealFood?
    @State private var errorMessage: String?
    @FocusState private var field: Field?
    private enum Field { case calories, description, name }
    init(preset: SavedMeal? = nil, seedFoods: [MealFood] = []) {
        let initialFoods = preset?.foods ?? seedFoods
        _foods = State(initialValue: initialFoods); _useFoods = State(initialValue: !initialFoods.isEmpty)
        _caloriesText = State(initialValue: preset.map { $0.calories.formatted(.number.locale(Locale.current).grouping(.never).precision(.fractionLength(0...3))) } ?? "")
        _description = State(initialValue: preset?.description ?? "")
        _mealType = State(initialValue: preset?.mealType ?? .breakfast)
        _mealName = State(initialValue: preset?.name ?? "")
    }
    private var calories: Double? { useFoods ? (foods.isEmpty ? nil : foods.reduce(0) { $0 + $1.calories }) : LocalizedDecimal.parse(caloriesText, locale: locale) }
    private var valid: Bool {
        guard let calories, calories.isFinite, calories > 0, calories <= 10000, description.count <= 2000,
              date <= Date(), !useFoods || foods.allSatisfy(\.isValid) else { return false }
        return !saveForNextTime || (!mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mealName.count <= 120 && (userManager.user.savedMeals ?? []).count < 500)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { field = nil; pickingSavedMeal = true } label: { Label("Choose a saved meal", systemImage: "bookmark") }
                        .accessibilityIdentifier("choose-saved-meal")
                }
                Section("Meal details") {
                    Picker("Meal", selection: $mealType) { ForEach(CalorieRecord.MealType.allCases) { Text($0.rawValue).tag($0) } }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(2...5).focused($field, equals: .description)
                        .accessibilityIdentifier("meal-description")
                    Picker("Entry", selection: $useFoods) { Text("Calories").tag(false); Text("Food portions").tag(true) }.pickerStyle(.segmented)
                }
                if useFoods {
                    Section {
                        ForEach(foods) { food in
                            Button { field = nil; editingFood = food } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name).foregroundStyle(.primary)
                                    Text("\(food.resolvedSource.region) · \(food.grams.formatted(.number.precision(.fractionLength(0...1)))) g · \(food.calories.formatted(.number.precision(.fractionLength(0...1)))) kcal")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.onDelete { foods.remove(atOffsets: $0) }
                        Button { pickingFood = true } label: { Label("Add food from library", systemImage: "plus.circle") }
                            .disabled(foods.count >= 100).accessibilityIdentifier("choose-food")
                        DetailRow(title: "Estimated calories", value: "\((calories ?? 0).formatted(.number.precision(.fractionLength(0...1)))) kcal")
                    } header: { Text("Foods & portions") } footer: { Text("Tap a food to change its portion. Swipe to remove. Values are estimates.") }
                } else {
                    Section("Calories") {
                        HStack {
                            Text("Energy")
                            TextField("Amount", text: $caloriesText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .focused($field, equals: .calories).accessibilityIdentifier("meal-calories")
                            Text("kcal").foregroundStyle(.secondary)
                        }
                        Button { field = nil; useFoods = true; pickingFood = true } label: { Label("Find a food instead", systemImage: "magnifyingglass") }
                            .accessibilityIdentifier("choose-food")
                    }
                }
                Section {
                    Toggle("Save for next time", isOn: $saveForNextTime).accessibilityIdentifier("save-meal-preset")
                        .onChange(of: saveForNextTime) { _, enabled in if enabled && mealName.isEmpty { mealName = description.isEmpty ? mealType.rawValue + " meal" : String(description.prefix(120)) } }
                    if saveForNextTime { TextField("Saved meal name", text: $mealName).focused($field, equals: .name).accessibilityIdentifier("saved-meal-name") }
                } footer: { Text("Creates a reusable meal without changing earlier entries.") }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }.appForm().navigationTitle("Add Meal").appScreen()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!valid).accessibilityIdentifier("save-meal") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { field = nil } }
                }
                .sheet(isPresented: $pickingFood) { NavigationStack { FoodLibraryView { foods.append($0); useFoods = true } } }
                .sheet(isPresented: $pickingSavedMeal) { NavigationStack { SavedMealsView(onSelect: apply) } }
                .sheet(item: $editingFood) { food in
                    NavigationStack {
                        let entry = catalog.food(id: food.foodID)
                        let reference = FoodCatalogEntry(id: food.foodID, name: food.name, category: entry?.category ?? "Saved food",
                            kcalPer100g: food.kcalPer100g, protein: food.proteinPer100g, carbohydrate: food.carbohydratePer100g, fat: food.fatPer100g, portions: entry?.portions ?? [],
                            source: food.resolvedSource, sourceCode: food.sourceCode ?? entry?.referenceCode, sourceNote: food.sourceNote ?? entry?.sourceNote)
                        FoodPortionView(food: reference, grams: food.grams, servingID: food.id) { edited in
                            if let index = foods.firstIndex(where: { $0.id == edited.id }) { foods[index].grams = edited.grams }
                            editingFood = nil
                        }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingFood = nil } } }
                    }
                }
                .task { await catalog.load() }
        }
    }
    private func apply(_ meal: SavedMeal) {
        caloriesText = meal.calories.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...3)))
        mealType = meal.mealType; description = meal.description ?? ""; foods = meal.foods ?? []
        useFoods = !foods.isEmpty; mealName = meal.name; saveForNextTime = false
    }
    private func save() {
        guard valid, let calories else { return }
        field = nil
        let selectedFoods = useFoods ? foods : nil
        let record = CalorieRecord(calories: calories, mealType: mealType, description: description.isEmpty ? nil : description, date: date, foods: selectedFoods)
        let preset = saveForNextTime ? SavedMeal(name: mealName.trimmingCharacters(in: .whitespacesAndNewlines), calories: calories,
            mealType: mealType, description: record.description, foods: selectedFoods) : nil
        guard userManager.updateUser({ user in
            user.calorieHistory.append(record)
            if let preset { if user.savedMeals == nil { user.savedMeals = [] }; user.savedMeals?.append(preset) }
        }) else { errorMessage = userManager.persistenceError ?? "Your meal could not be saved."; return }
        dismiss()
    }
}
