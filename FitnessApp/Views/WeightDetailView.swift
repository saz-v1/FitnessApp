import SwiftUI
import Charts

struct WeightDetailView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingWeight = false
    @State private var period: ChartPeriod = .month
    var body: some View {
        let now = Date()
        let records = userManager.user.weightHistory.filter { $0.date <= now && $0.weight.isFinite && $0.weight > 0 }
            .sorted { $0.date < $1.date }
        let plottedRecords = records.filter { $0.date >= period.start(now: now) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        IconBadge(icon: "scalemass")
                        Text("Current weight").font(.headline)
                        Text("\(userManager.user.weight.formatted(.number.precision(.fractionLength(1)))) \(userManager.weightUnit)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        if let goal = userManager.user.goalWeight {
                            Text("Goal: \(goal.formatted(.number.precision(.fractionLength(1)))) \(userManager.weightUnit)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            WeightGoalView(currentWeight: userManager.user.weight, goalWeight: goal, usesMetric: userManager.user.usesMetric)
                        }
                    }
                }
                Button { isAddingWeight = true } label: { Label("Add Weight Entry", systemImage: "plus") }
                    .buttonStyle(AppPrimaryButtonStyle()).accessibilityIdentifier("add-weight")
                AppCard {
                    VStack(alignment: .leading, spacing: 18) {
                        AppSectionTitle(title: "Your weight trend")
                        ChartPeriodPicker(selection: $period)
                        if plottedRecords.isEmpty {
                            Text("No measurements in this period. Try another range or log a weight.")
                                .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 32)
                        } else {
                            WeightTrendChart(records: plottedRecords, usesMetric: userManager.user.usesMetric,
                                goal: userManager.user.goalWeight, period: period, domain: period.domain(now: now))
                        }
                    }
                }
                if !records.isEmpty {
                    AppSectionTitle(title: "Measurements", subtitle: "\(records.count) entries")
                    ForEach(records.reversed()) { record in
                        WeightHistoryRow(record: record, usesMetric: userManager.user.usesMetric)
                    }
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Weight").navigationBarTitleDisplayMode(.inline).appScreen()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(isPresented: $isAddingWeight) { AddWeightSheet() }
    }
}

/// A chart selection never sorts or filters the full measurement history.
private struct WeightTrendChart: View {
    let records: [WeightRecord]
    let usesMetric: Bool
    let goal: Double?
    let period: ChartPeriod
    let domain: ClosedRange<Date>
    @State private var selectedDate: Date?
    private var unit: String { usesMetric ? "kg" : "lbs" }
    private func displayWeight(_ kilograms: Double) -> Double { usesMetric ? kilograms : kilograms / 0.45359237 }

    var body: some View {
        let selected = selectedDate.flatMap { date in
            records.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        let measurements = records.map { displayWeight($0.weight) } + (goal.map { [$0] } ?? [])
        let range = max(0, (measurements.min() ?? 0) - 2)...((measurements.max() ?? 100) + 2)
        VStack(alignment: .leading, spacing: 18) {
            ChartSummary {
                ChartReadout(title: selected?.date.formatted(date: .abbreviated, time: .omitted) ?? "Latest in this period",
                    value: "\(displayWeight(selected?.weight ?? records.last?.weight ?? 0).formatted(.number.precision(.fractionLength(1)))) \(unit)")
                ChartReadout(title: "Change", value: changeText, detail: "First to last entry")
            }
            chart(selected: selected, range: range)
            Text("Touch the chart to explore a measurement.").font(.caption).foregroundStyle(.secondary)
            if goal != nil {
                Label("Your goal", systemImage: "minus").font(.caption).foregroundStyle(AppTheme.warm)
            }
        }
        .onChange(of: period) { _, _ in selectedDate = nil }
    }

    private func chart(selected: WeightRecord?, range: ClosedRange<Double>) -> some View {
        Chart {
            ForEach(records) { record in
                LineMark(x: .value("Date", record.date), y: .value("Weight", displayWeight(record.weight)))
                    .foregroundStyle(AppTheme.accent).lineStyle(StrokeStyle(lineWidth: 3))
                PointMark(x: .value("Date", record.date), y: .value("Weight", displayWeight(record.weight)))
                    .foregroundStyle(AppTheme.accent).symbolSize(24)
                    .accessibilityLabel(record.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(displayWeight(record.weight)) \(unit)")
            }
            if let goal {
                RuleMark(y: .value("Goal", goal)).foregroundStyle(AppTheme.warm)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date)).foregroundStyle(.secondary.opacity(0.4))
                PointMark(x: .value("Selected date", selected.date), y: .value("Selected weight", displayWeight(selected.weight)))
                    .foregroundStyle(AppTheme.accent).symbolSize(80)
            }
        }
        .frame(height: 230).chartYScale(domain: range).chartXScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
            AxisValueLabel { if let date = value.as(Date.self) { ChartDateLabel(date: date) } }
        } }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXSelection(value: $selectedDate)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    private var changeText: String {
        guard records.count > 1, let first = records.first, let last = records.last else { return "—" }
        let difference = displayWeight(last.weight - first.weight)
        return "\(difference > 0 ? "+" : "")\(difference.formatted(.number.precision(.fractionLength(1)))) \(unit)"
    }
}

struct WeightHistoryRow: View {
    let record: WeightRecord
    let usesMetric: Bool
    @EnvironmentObject private var userManager: UserManager
    @State private var confirmingDelete = false
    var body: some View {
        AppCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(userManager.displayWeight(record.weight).formatted(.number.precision(.fractionLength(1)))) \(usesMetric ? "kg" : "lbs")")
                        .font(.title3.weight(.semibold))
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Delete weight entry")
            }
        }
        .alert("Delete this measurement?", isPresented: $confirmingDelete) {
            Button("Delete Weight Entry", role: .destructive) { userManager.deleteWeightRecord(record) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the entry from FitSwift. Apple Health records are kept.") }
    }
}
