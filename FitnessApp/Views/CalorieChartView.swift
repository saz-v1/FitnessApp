import SwiftUI
import Charts

struct CalorieChartView: View {
    @EnvironmentObject private var userManager: UserManager
    @State private var period: ChartPeriod = .month
    let showAnnotations: Bool
    init(showAnnotations: Bool = true) { self.showAnnotations = showAnnotations }
    var body: some View {
        let now = Date()
        let summary = FitnessMetrics.calorieSummary(records: userManager.user.calorieHistory, days: period.rawValue, now: now)
        let target = userManager.calculateWeeklyCalorieTarget() ?? userManager.calculateDailyCalories()
        VStack(alignment: .leading, spacing: 18) {
            ChartPeriodPicker(selection: $period)
            if !summary.hasRecords {
                VStack(spacing: 12) {
                    IconBadge(icon: "chart.bar")
                    Text("No meals in this period").font(.headline)
                    Text("Choose another range or log a meal to start your trend.").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 180)
            } else {
                CalorieTrendChart(summary: summary, target: target, period: period,
                    domain: period.domain(now: now), showAnnotations: showAnnotations)
            }
        }
    }
}

/// Finger movement updates this view alone; the full meal history is aggregated by its parent.
private struct CalorieTrendChart: View {
    let summary: FitnessMetrics.CalorieSummary
    let target: Double
    let period: ChartPeriod
    let domain: ClosedRange<Date>
    let showAnnotations: Bool
    @State private var selectedDate: Date?

    var body: some View {
        let days = summary.days
        let selectedDay = selectedDate.flatMap { selected in
            days.first { Calendar.current.isDate($0.date, inSameDayAs: selected) }
        }
        VStack(alignment: .leading, spacing: 18) {
                ChartSummary {
                    ChartReadout(title: selectedDay?.date.formatted(date: .abbreviated, time: .omitted) ?? "Daily average",
                        value: "\(Int(selectedDay?.calories ?? summary.average)) kcal", detail: selectedDay == nil ? "Across \(period.rawValue) calendar days" : "Selected day")
                        .accessibilityIdentifier("calorie-chart-readout")
                    ChartReadout(title: "Days logged", value: "\(summary.loggedDays) / \(period.rawValue)")
                }
                Chart {
                    ForEach(days, id: \.date) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Calories", day.calories))
                            .foregroundStyle(AppTheme.accent.gradient).cornerRadius(4)
                            .opacity(selectedDay == nil || selectedDay?.date == day.date ? 1 : 0.35)
                            .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                            .accessibilityValue("\(Int(day.calories)) calories")
                    }
                    if showAnnotations && target > 0 {
                        RuleMark(y: .value("Estimated target", target))
                            .foregroundStyle(AppTheme.warm).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                    if let day = selectedDay {
                        RuleMark(x: .value("Selected day", day.date, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .frame(height: 220)
                .chartYScale(domain: 0...max(500, target * 1.15, summary.maximum * 1.1))
                .chartXScale(domain: domain)
                .chartXAxis {
                    if period == .week {
                        AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: period.axisStride)) { value in
                            AxisValueLabel { if let date = value.as(Date.self) { ChartDateLabel(date: date) } }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXSelection(value: $selectedDate)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Text("Touch the chart to inspect a day. Missing days have a zero total.")
                    .font(.caption).foregroundStyle(.secondary)
                if showAnnotations && target > 0 {
                    Label("Estimated daily target", systemImage: "minus").font(.caption).foregroundStyle(AppTheme.warm)
                }
        }
        .onChange(of: period) { _, _ in selectedDate = nil }
    }
}
