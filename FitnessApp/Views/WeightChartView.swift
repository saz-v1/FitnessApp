import SwiftUI
import Charts

struct WeightChartView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var isAddingWeight = false
    
    // Compute the Y-axis range based on weight data
    private var weightRange: ClosedRange<Double> {
        let weights = userManager.user.weightHistory.map { $0.weight }
            .filter { !$0.isNaN && $0.isFinite } // Filter out invalid values
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight History")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isAddingWeight = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if userManager.user.weightHistory.isEmpty {
                Text("No weight records yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
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
                .frame(height: 200) // Fixed height to prevent dimension warnings
                .chartYScale(domain: weightRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let weight = value.as(Double.self),
                               !weight.isNaN && weight.isFinite {
                                Text(String(format: "%.1f", weight))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingWeight) {
            AddWeightSheet()
        }
    }
}

struct AddWeightSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @State private var weight: Double = 0
    @State private var date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                        Text(userManager.user.usesMetric ? "kg" : "lbs")
                    }
                    
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date])
                }
            }
            .navigationTitle("Add Weight Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let record = WeightRecord(weight: weight, date: date)
                        userManager.user.weightHistory.append(record)
                        userManager.saveUser()
                        dismiss()
                    }
                    .disabled(weight <= 0)
                }
            }
            .onAppear {
                weight = userManager.user.weight
            }
        }
    }
}

#Preview {
    WeightChartView()
        .environmentObject(UserManager())
        .frame(height: 300)
        .padding()
} 