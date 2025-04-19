import SwiftUI
import Charts

struct WeightDetailView: View {
    @EnvironmentObject var userManager: UserManager
    @Environment(\.dismiss) var dismiss
    @State private var isAddingWeight = false
    
    // Compute the Y-axis range based on weight data
    private var weightRange: ClosedRange<Double> {
        let weights = userManager.user.weightHistory.map { $0.weight }
            .filter { !$0.isNaN && $0.isFinite }
        let goalWeight = userManager.user.goalWeight
        let allWeights = goalWeight.map { weights + [$0] } ?? weights
        
        if allWeights.isEmpty {
            let currentWeight = userManager.user.weight
            guard !currentWeight.isNaN && currentWeight.isFinite else {
                return 0...100 // Fallback range if current weight is invalid
            }
            return (currentWeight - 5)...(currentWeight + 5)
        }
        
        let minWeight = (allWeights.min() ?? 0) - 2
        let maxWeight = (allWeights.max() ?? 100) + 2
        
        // Ensure we have valid bounds
        if minWeight.isNaN || maxWeight.isNaN || minWeight >= maxWeight {
            return 0...100 // Fallback range if calculations result in invalid values
        }
        
        return minWeight...maxWeight
    }
    
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
                            ForEach(userManager.user.weightHistory.sorted(by: { $0.date < $1.date })) { record in
                                if !record.weight.isNaN && record.weight.isFinite {
                                    LineMark(
                                        x: .value("Date", record.date),
                                        y: .value("Weight", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                    
                                    PointMark(
                                        x: .value("Date", record.date),
                                        y: .value("Weight", record.weight)
                                    )
                                    .foregroundStyle(.green)
                                }
                            }
                            
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
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                                AxisValueLabel(format: .dateTime.month().day())
                                    .font(.subheadline)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let weight = value.as(Double.self),
                                       !weight.isNaN && weight.isFinite {
                                        Text(String(format: "%.1f", weight))
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
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
}

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