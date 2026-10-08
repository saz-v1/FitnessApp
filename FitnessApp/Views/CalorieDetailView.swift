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
                NavigationLink { SavedMealsView() } label: { Label("Saved meals", systemImage: "bookmark") }
                    .accessibilityIdentifier("browse-saved-meals")
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
    @State private var savingPreset = false
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
                if let foods = meal.foods {
                    ForEach(foods) { food in Text("\(food.name) · \(food.resolvedSource.region) · \(food.grams.formatted(.number.precision(.fractionLength(0...1)))) g").font(.caption).foregroundStyle(.secondary) }
                }
                Button { savingPreset = true } label: { Label("Save meal for next time", systemImage: "bookmark") }.font(.subheadline)
            }
        }
        .sheet(isPresented: $savingPreset) { SaveMealPresetSheet(record: meal) }
        .alert("Delete this meal?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Meal", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationView {
        CalorieDetailView()
            .environmentObject(UserManager())
    }
}
