import SwiftUI
import Charts

struct CalorieDetailView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @State private var isAddingCalories = false
    @StateObject private var claudeService = ClaudeService.shared
    
    var todaysMeals: [CalorieRecord] {
        userManager.user.calorieHistory
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Daily Targets Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Targets")
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Maintenance calories
                        VStack(alignment: .leading) {
                            Text("Maintenance")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Text("\(Int(userManager.calculateDailyCalories()))")
                                .font(.title2)
                                .bold()
                            Text("kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Goal-adjusted calories if available
                        if let goalTarget = userManager.calculateWeeklyCalorieTarget() {
                            VStack(alignment: .leading) {
                                Text("Goal Target")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Text("\(Int(goalTarget))")
                                    .font(.title2)
                                    .bold()
                                Text("kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Add New Entry Button
                Button(action: { isAddingCalories = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Meal")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Expanded Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Calorie Trend")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    CalorieChartView(showAnnotations: true)
                        .frame(height: 300)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                // Today's Meals
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Meals")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    if todaysMeals.isEmpty {
                        Text("No meals logged today")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(todaysMeals) { meal in
                            MealRow(
                                meal: meal,
                                onDelete: {
                                    userManager.deleteCalorieRecord(meal)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Calories")
        .sheet(isPresented: $isAddingCalories) {
            AddCalorieSheet()
        }
    }
}

struct MealRow: View {
    let meal: CalorieRecord
    var onDelete: (() -> Void)? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.mealType.rawValue)
                    .font(.headline)
                Spacer()
                Text(meal.date.formatted(date: .omitted, time: .shortened))
                    .foregroundColor(.secondary)
                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Delete Meal",
                        isPresented: $showingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to delete this meal? This action cannot be undone.")
                    }
                }
            }
            
            if let description = meal.description {
                Text(description)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(Int(meal.calories)) kcal")
                    .font(.title3)
                    .bold()
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct AddCalorieSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @StateObject private var claudeService = ClaudeService.shared
    
    @State private var calories: Double = 0
    @State private var mealType: CalorieRecord.MealType = .breakfast
    @State private var description: String = ""
    @State private var date = Date()
    @State private var isEstimating: Bool = false
    @State private var errorMessage: String?
    @State private var estimatedCalories: Double?
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(CalorieRecord.MealType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Description (e.g., '2 slices of pepperoni pizza')", text: $description, axis: .vertical)
                        .lineLimit(3)
                    
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Amount", value: $calories, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                        Text("kcal")
                    }
                    
                    if !description.isEmpty {
                        Button(action: {
                            Task {
                                await estimateCalories()
                            }
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Estimate Calories")
                            }
                        }
                        .disabled(isEstimating)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
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
                        userManager.user.calorieHistory.append(record)
                        userManager.saveUser()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func estimateCalories() async {
        isEstimating = true
        errorMessage = nil
        
        do {
            let estimate = try await claudeService.estimateFoodCalories(foodDescription: description)
            // The response should now be just a number
            if let calorieNumber = Double(estimate.trimmingCharacters(in: .whitespacesAndNewlines)) {
                estimatedCalories = calorieNumber
                calories = calorieNumber
            } else {
                errorMessage = "Could not parse calorie estimate"
            }
        } catch {
            errorMessage = "Failed to get calorie estimate: \(error.localizedDescription)"
        }
        
        isEstimating = false
    }
}

#Preview {
    NavigationView {
        CalorieDetailView()
            .environmentObject(UserManager())
    }
} 