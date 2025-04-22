import SwiftUI
import Charts

/// A view that displays a calorie history chart with interactive features
struct CalorieChartView: View {
    // MARK: - Properties
    
    /// Reference to the user manager for accessing user data
    @EnvironmentObject var userManager: UserManager
    
    /// Controls the presentation of the add calories sheet
    @State private var isAddingCalories = false
    
    /// Tracks the current scroll position in the chart
    @State private var scrollPosition: Date?
    
    /// Whether to show annotations on the chart
    let showAnnotations: Bool
    
    // MARK: - Initialization
    
    init(showAnnotations: Bool = true) {
        self.showAnnotations = showAnnotations
    }
    
    // MARK: - Computed Properties
    
    /// Fixed Y-axis range for the chart from 0 to maintenance calories + 500
    private var calorieRange: ClosedRange<Double> {
        let maintenance = userManager.calculateDailyCalories()
        return 0...(maintenance + 500)
    }
    
    /// Groups calorie records by day for the bar chart
    private var dailyCalories: [(date: Date, calories: Double)] {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: userManager.user.calorieHistory) { record in
            calendar.startOfDay(for: record.date)
        }
        
        return groupedByDay.map { (date, records) in
            let totalCalories = records.reduce(0) { $0 + $1.calories }
            return (date: date, calories: totalCalories)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calorie History")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isAddingCalories = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if userManager.user.calorieHistory.isEmpty {
                Text("No calorie records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    // Bar chart for daily calories
                    ForEach(dailyCalories, id: \.date) { day in
                        BarMark(
                            x: .value("Date", day.date),
                            y: .value("Calories", day.calories)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.green.opacity(0.7), .orange.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }
                    
                    // Maintenance calories line
                    if showAnnotations {
                        RuleMark(
                            y: .value("Maintenance", userManager.calculateDailyCalories())
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.orange)
                        .annotation(position: .trailing) {
                            Text("Maintenance")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(4)
                                .background(Color(.systemBackground))
                                .cornerRadius(4)
                        }
                        
                        // Goal-adjusted target line if available
                        if let goalTarget = userManager.calculateWeeklyCalorieTarget() {
                            RuleMark(
                                y: .value("Goal Target", goalTarget)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(.red)
                            .annotation(position: .trailing) {
                                Text("Goal Target")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(4)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: calorieRange)
                
                // X-axis configuration
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 12)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.caption)
                    }
                }
                
                // Y-axis configuration
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let calories = value.as(Double.self),
                               !calories.isNaN && calories.isFinite {
                                Text("\(Int(calories))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                // Enable horizontal scrolling
                .chartXSelection(value: $scrollPosition)
                .chartScrollableAxes(.horizontal)
                .chartXScale(domain: getDateRange())
            }
        }
        .sheet(isPresented: $isAddingCalories) {
            AddCaloriesSheet()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the date range for the X-axis with appropriate padding
    private func getDateRange() -> ClosedRange<Date> {
        let sortedRecords = userManager.user.calorieHistory.sorted(by: { $0.date < $1.date })
        
        // If no records, show last month
        guard let firstDate = sortedRecords.first?.date,
              let lastDate = sortedRecords.last?.date else {
            return Calendar.current.date(byAdding: .month, value: -1, to: Date())!...Date()
        }
        
        // Add 7 days padding on the start, but don't go beyond current date
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: firstDate)!
        let endDate = min(Calendar.current.date(byAdding: .day, value: 7, to: lastDate)!, Date())
        
        return startDate...endDate
    }
}

#Preview {
    CalorieChartView()
        .environmentObject(UserManager())
        .frame(height: 300)
        .padding()
} 