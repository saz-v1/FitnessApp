import SwiftUI
import Charts

struct CalorieDetailView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @State private var isAddingCalories = false
    
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
                CalorieChartView(showAnnotations: true)
                    .frame(height: 300)
                
                // Today's Meals
                if !todaysMeals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Meals")
                            .font(.headline)
                        
                        let totalCalories = todaysMeals.reduce(0) { $0 + $1.calories }
                        Text("Total: \(Int(totalCalories)) kcal")
                            .foregroundColor(.secondary)
                        
                        ForEach(todaysMeals) { meal in
                            MealRow(meal: meal)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Calorie Details")
        .sheet(isPresented: $isAddingCalories) {
            AddCaloriesSheet()
        }
    }
}

struct MealRow: View {
    let meal: CalorieRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(meal.mealType.rawValue.capitalized)
                    .font(.headline)
                if let description = meal.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(meal.calories)) kcal")
                    .bold()
                Text(meal.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct AddCaloriesSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @StateObject private var claudeService = ClaudeService.shared
    
    @State private var calories: Double = 0
    @State private var mealType: CalorieRecord.MealType = .breakfast
    @State private var description: String = ""
    @State private var date = Date()
    @State private var isEstimating: Bool = false
    @State private var errorMessage: String?
    
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
                        if isEstimating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            TextField("Amount", value: $calories, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                            Text("kcal")
                        }
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
                    .disabled(calories <= 0)
                }
            }
        }
    }
    
    private func estimateCalories() async {
        guard !description.isEmpty else { return }
        
        isEstimating = true
        errorMessage = nil
        
        do {
            let estimatedCalories = try await claudeService.estimateCalories(foodDescription: description)
            if estimatedCalories >= 0 {
                calories = Double(estimatedCalories)
            } else {
                errorMessage = "Could not estimate calories. Please enter them manually."
            }
        } catch {
            errorMessage = error.localizedDescription
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