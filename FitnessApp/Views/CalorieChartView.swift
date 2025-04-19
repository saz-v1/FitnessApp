import SwiftUI
import Charts

struct CalorieChartView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var isAddingCalories = false
    let showAnnotations: Bool
    
    var dailyCalories: [Date: Double] {
        Dictionary(grouping: userManager.user.calorieHistory) { record in
            Calendar.current.startOfDay(for: record.date)
        }.mapValues { records in
            records.reduce(0) { $0 + $1.calories }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calorie Intake")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isAddingCalories = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Target")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(Int(userManager.calculateDailyCalories())) kcal")
                    .font(.title2)
                    .bold()
            }
            
            if dailyCalories.isEmpty {
                Text("No calorie records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(dailyCalories.keys.sorted()), id: \.self) { date in
                        BarMark(
                            x: .value("Date", date),
                            y: .value("Calories", dailyCalories[date] ?? 0)
                        )
                        .foregroundStyle(.green)
                    }
                    
                    // Maintenance calories line
                    RuleMark(
                        y: .value("Maintenance", userManager.calculateDailyCalories())
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.orange)
                    .annotation(position: .trailing, alignment: .leading) {
                        if showAnnotations {
                            Text("Maintenance")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Goal-adjusted target line
                    if let goalTarget = userManager.calculateWeeklyCalorieTarget() {
                        RuleMark(
                            y: .value("Goal Target", goalTarget)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.red)
                        .annotation(position: .trailing, alignment: .leading) {
                            if showAnnotations {
                                Text("Goal Target")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { value in
                        AxisValueLabel(format: .dateTime.weekday())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let calories = value.as(Double.self) {
                                Text("\(Int(calories))")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingCalories) {
            AddCaloriesSheet()
        }
    }
}

extension CalorieChartView {
    init(showAnnotations: Bool = false) {
        self.showAnnotations = showAnnotations
    }
}

#Preview {
    CalorieChartView()
        .environmentObject(UserManager())
        .padding()
} 