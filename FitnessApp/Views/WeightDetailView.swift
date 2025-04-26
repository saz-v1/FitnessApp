import SwiftUI
import Charts
import HealthKit

/// A view that displays detailed weight history with an interactive chart
struct WeightDetailView: View {
    // MARK: - Properties
    
    /// Reference to the user manager for accessing user data
    @EnvironmentObject var userManager: UserManager
    
    /// Controls the presentation of the add weight sheet
    @State private var isAddingWeight = false
    
    /// Tracks the current scroll position in the chart
    @State private var scrollPosition: Date?
    
    // MARK: - Computed Properties
    
    /// Calculates the Y-axis range for the chart based on weight data
    private var weightRange: ClosedRange<Double> {
        let weights = userManager.user.weightHistory.map { $0.weight }
            .filter { !$0.isNaN && $0.isFinite }
        let goalWeight = userManager.user.goalWeight
        let allWeights = goalWeight.map { weights + [$0] } ?? weights
        
        if allWeights.isEmpty {
            let currentWeight = userManager.user.weight
            guard !currentWeight.isNaN && currentWeight.isFinite else {
                return 0...100
            }
            return (currentWeight - 5)...(currentWeight + 5)
        }
        
        let minWeight = (allWeights.min() ?? 0) - 2
        let maxWeight = (allWeights.max() ?? 100) + 2
        
        if minWeight.isNaN || maxWeight.isNaN || minWeight >= maxWeight {
            return 0...100
        }
        
        return minWeight...maxWeight
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Current Weight Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Weight")
                        .font(.headline)
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(String(format: "%.1f", userManager.user.weight))
                            .font(.title)
                            .bold()
                        Text(userManager.user.usesMetric ? "kg" : "lbs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 44)
                    
                    if let goalWeight = userManager.user.goalWeight {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal Weight: \(String(format: "%.1f", goalWeight)) \(userManager.user.usesMetric ? "kg" : "lbs")")
                            
                            let difference = goalWeight - userManager.user.weight
                            Text(difference > 0 ? "Need to gain" : "Need to lose")
                                .foregroundColor(.secondary)
                            + Text(" \(String(format: "%.1f", abs(difference))) \(userManager.user.usesMetric ? "kg" : "lbs")")
                                .bold()
                        }
                        .font(.subheadline)
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Add New Entry Button
                Button(action: { isAddingWeight = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add Weight Entry")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.vertical, 8)
                
                // Weight Trend Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weight Trend")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    if userManager.user.weightHistory.isEmpty {
                        Text("No weight records yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 200)
                    } else {
                        Chart {
                            // Area fill under the line
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
                            
                            // Main line
                            ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                                if !record.weight.isNaN && record.weight.isFinite {
                                    LineMark(
                                        x: .value("Date", record.date),
                                        y: .value("Weight", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                            }
                            
                            // Data points (simplified)
                            ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                                if !record.weight.isNaN && record.weight.isFinite {
                                    PointMark(
                                        x: .value("Date", record.date),
                                        y: .value("Weight", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                    .symbolSize(8)
                                }
                            }
                            
                            // Goal line
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
                        .frame(height: 300)
                        .chartYScale(domain: weightRange)
                        
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
                        
                        // Legend
                        HStack(spacing: 20) {
                            // Area fill legend
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(.linearGradient(colors: [.green.opacity(0.3), .green.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                                Text("Weight Trend")
                                    .font(.caption)
                            }
                            
                            // Line and points legend
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("Data Points")
                                    .font(.caption)
                            }
                            
                            // Goal line legend
                            if let goalWeight = userManager.user.goalWeight,
                               !goalWeight.isNaN && goalWeight.isFinite {
                                HStack(spacing: 8) {
                                    Rectangle()
                                        .fill(.red)
                                        .frame(width: 20, height: 2)
                                        .cornerRadius(1)
                                    Text("Goal")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Weight History
                VStack(alignment: .leading, spacing: 16) {
                    Text("History")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    ForEach(userManager.user.weightHistory.sorted(by: { $0.date > $1.date })) { record in
                        WeightHistoryRow(record: record, usesMetric: userManager.user.usesMetric)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Weight History")
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
        
        // Add 7 days padding on the start, but don't go beyond current date
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: firstDate)!
        let endDate = min(Calendar.current.date(byAdding: .day, value: 7, to: lastDate)!, Date())
        
        return startDate...endDate
    }
}

/// A row displaying a single weight record
struct WeightHistoryRow: View {
    let record: WeightRecord
    let usesMetric: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", record.weight))
                    .font(.title3)
                    .bold()
                + Text(" \(usesMetric ? "kg" : "lbs")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(height: 60)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        WeightDetailView()
            .environmentObject(UserManager())
    }
} 