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
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: now)! // Show last 30 days
        
        // Create a dictionary of all days in the range
        var allDays: [Date: Double] = [:]
        var currentDate = startDate
        
        // Initialize all days with zero calories
        while currentDate <= now {
            allDays[calendar.startOfDay(for: currentDate)] = 0
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Add actual calorie records
        for record in userManager.user.calorieHistory {
            let day = calendar.startOfDay(for: record.date)
            if day >= startDate && day <= now {
                allDays[day, default: 0] += record.calories
            }
        }
        
        // Convert to array and sort by date
        return allDays.map { (date: $0.key, calories: $0.value) }
            .sorted { $0.date < $1.date }
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
                    AxisMarks(values: .stride(by: .day, count: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.caption)
                    }
                }
                .chartXAxisLabel(position: .bottomTrailing) {
                    Text("")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                
                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(.linearGradient(colors: [.green.opacity(0.7), .orange.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                        Text("Daily Calories")
                            .font(.caption)
                    }
                    
                    if showAnnotations {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(.orange)
                                .frame(width: 20, height: 2)
                                .cornerRadius(1)
                            Text("Maintenance")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if userManager.calculateWeeklyCalorieTarget() != nil {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(.red)
                                    .frame(width: 20, height: 2)
                                    .cornerRadius(1)
                                Text("Goal Target")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $isAddingCalories) {
            AddCaloriesSheet()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the date range for the X-axis with appropriate padding
    private func getDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        return startDate...now
    }
}

#Preview {
    CalorieChartView()
        .environmentObject(UserManager())
        .frame(height: 300)
        .padding()
} 