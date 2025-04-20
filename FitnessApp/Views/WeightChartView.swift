import SwiftUI
import Charts

/// A view that displays a weight history chart with interactive features
struct WeightChartView: View {
    // MARK: - Properties
    
    /// Reference to the user manager for accessing user data
    @EnvironmentObject var userManager: UserManager
    
    /// Controls the presentation of the add weight sheet
    @State private var isAddingWeight = false
    
    /// Tracks the current scroll position in the chart
    @State private var scrollPosition: Date?
    
    // MARK: - Computed Properties
    
    /// Calculates the Y-axis range for the chart based on weight data
    /// This ensures the chart displays an appropriate range of weights
    private var weightRange: ClosedRange<Double> {
        // Get all valid weights from history
        let weights = userManager.user.weightHistory.map { $0.weight }
            .filter { !$0.isNaN && $0.isFinite }
        
        // Include goal weight in the range calculation if available
        let goalWeight = userManager.user.goalWeight
        let allWeights = goalWeight.map { weights + [$0] } ?? weights
        
        // If no weights are available, use current weight as reference
        if allWeights.isEmpty {
            let currentWeight = userManager.user.weight
            guard !currentWeight.isNaN && currentWeight.isFinite else {
                return 0...100 // Fallback range if current weight is invalid
            }
            return (currentWeight - 5)...(currentWeight + 5) // Range centered on current weight
        }
        
        // Calculate min and max weights with padding
        let minWeight = (allWeights.min() ?? 0) - 2
        let maxWeight = (allWeights.max() ?? 100) + 2
        
        // Validate the range
        if minWeight.isNaN || maxWeight.isNaN || minWeight >= maxWeight {
            return 0...100 // Fallback range if calculation fails
        }
        
        return minWeight...maxWeight
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and add button
            HStack {
                Text("Weight History")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isAddingWeight = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Show placeholder if no data is available
            if userManager.user.weightHistory.isEmpty {
                Text("No weight records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Main chart view
                Chart {
                    // Area fill under the line for visual appeal
                    ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                        if !record.weight.isNaN && record.weight.isFinite {
                            AreaMark(
                                x: .value("Date", record.date),
                                y: .value("Weight", record.weight)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.green.opacity(0.3), .green.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    
                    // Main weight line
                    ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                        if !record.weight.isNaN && record.weight.isFinite {
                            LineMark(
                                x: .value("Date", record.date),
                                y: .value("Weight", record.weight)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom) // Smooth line interpolation
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    
                    // Data points (simplified for clarity)
                    ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                        if !record.weight.isNaN && record.weight.isFinite {
                            PointMark(
                                x: .value("Date", record.date),
                                y: .value("Weight", record.weight)
                            )
                            .foregroundStyle(.green)
                            .symbolSize(8) // Small points for less visual clutter
                        }
                    }
                    
                    // Goal weight line if set
                    if let goalWeight = userManager.user.goalWeight,
                       !goalWeight.isNaN && goalWeight.isFinite {
                        RuleMark(
                            y: .value("Goal", goalWeight)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.red)
                        .annotation(position: .trailing) {
                            Text("Goal")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: weightRange)
                
                // X-axis configuration
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
                            if let weight = value.as(Double.self),
                               !weight.isNaN && weight.isFinite {
                                Text(String(format: "%.1f", weight))
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
        .sheet(isPresented: $isAddingWeight) {
            AddWeightSheet()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculates the date range for the X-axis with appropriate padding
    private func getDateRange() -> ClosedRange<Date> {
        let sortedRecords = userManager.user.weightHistory.sorted(by: { $0.date < $1.date })
        
        // If no records, show last month
        guard let firstDate = sortedRecords.first?.date,
              let lastDate = sortedRecords.last?.date else {
            return Calendar.current.date(byAdding: .month, value: -1, to: Date())!...Date()
        }
        
        // Add 7 days padding on each end for better visualization
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: firstDate)!
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: lastDate)!
        
        return startDate...endDate
    }
}

// MARK: - Preview

#Preview {
    WeightChartView()
        .environmentObject(UserManager())
        .frame(height: 300)
        .padding()
} 