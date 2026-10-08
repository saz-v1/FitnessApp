import SwiftUI

struct CalorieDetailView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingCalories = false
    private var todaysMeals: [CalorieRecord] {
        userManager.user.calorieHistory.filter { Calendar.current.isDateInToday($0.date) && $0.date <= Date() }
            .sorted { $0.date > $1.date }
    }
    private var target: Double { userManager.calculateWeeklyCalorieTarget() ?? userManager.calculateDailyCalories() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Today's nourishment", systemImage: "leaf").font(.headline).foregroundStyle(AppTheme.accent)
                        Text("\(Int(todaysMeals.reduce(0) { $0 + $1.calories })) kcal")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(target > 0 ? "Estimated daily target: \(Int(target)) kcal" : "Daily estimates are available for adults.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Button { isAddingCalories = true } label: { Label("Add Meal", systemImage: "plus") }
                    .buttonStyle(AppPrimaryButtonStyle()).accessibilityIdentifier("add-meal")
                AppCard {
                    VStack(alignment: .leading, spacing: 18) {
                        AppSectionTitle(title: "Calorie trend", subtitle: "Your daily calorie totals")
                        CalorieChartView()
                    }
                }
                AppSectionTitle(title: "Today's meals", subtitle: "\(todaysMeals.count) entries")
                if todaysMeals.isEmpty {
                    AppEmptyState(title: "A fresh start",
                        message: "Log your meals as you go. Add a calorie amount and an optional description.",
                        icon: "fork.knife")
                } else {
                    ForEach(todaysMeals) { meal in
                        MealRow(meal: meal, onDelete: { userManager.deleteCalorieRecord(meal) })
                    }
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Meals & calories").navigationBarTitleDisplayMode(.inline).appScreen()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $isAddingCalories) { AddCalorieSheet() }
    }
}

struct MealRow: View {
    let meal: CalorieRecord
    var onDelete: (() -> Void)? = nil
    @State private var showingDeleteConfirmation = false
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(icon: "fork.knife")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealType.rawValue).font(.headline)
                        Text(meal.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if onDelete != nil {
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Delete \(meal.mealType.rawValue) entry")
                    }
                }
                if let description = meal.description, !description.isEmpty {
                    Text(description).font(.subheadline).foregroundStyle(.secondary)
                }
                Text("\(Int(meal.calories)) kcal").font(.title3.weight(.semibold)).monospacedDigit()
            }
        }
        .alert("Delete this meal?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Meal", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct AddCalorieSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    
    @State private var calories: Double = 0
    @State private var mealType: CalorieRecord.MealType = .breakfast
    @State private var description: String = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @FocusState private var field: Field?
    private enum Field { case description, calories }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal details") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(CalorieRecord.MealType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Description (e.g., '2 slices of pepperoni pizza')", text: $description, axis: .vertical)
                        .lineLimit(3...5).focused($field, equals: .description)
                    
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Amount", value: $calories, format: .number)
                            .accessibilityIdentifier("meal-calories")
                            .focused($field, equals: .calories)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                        Text("kcal")
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .appForm()
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let record = CalorieRecord(
                            calories: calories,
                            mealType: mealType,
                            description: description.isEmpty ? nil : description,
                            date: date
                        )
                        guard userManager.updateUser({ $0.calorieHistory.append(record) }) else {
                            errorMessage = userManager.persistenceError ?? "Your meal could not be saved."
                            return
                        }
                        dismiss()
                    }
                    .disabled(!calories.isFinite || calories <= 0 || calories > 10000 || description.count > 2000)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { field = nil } }
            }
        }
    }
    
}

#Preview {
    NavigationView {
        CalorieDetailView()
            .environmentObject(UserManager())
    }
}
