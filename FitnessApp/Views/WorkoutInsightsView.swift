import SwiftUI
import Charts

struct WorkoutInsightsView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var period: ChartPeriod = .week
    var body: some View {
        let now = Date()
        let summary = FitnessMetrics.workoutSummary(records: userManager.user.workoutHistory, days: period.rawValue, now: now)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if summary.totalSessions == 0 {
                    AppEmptyState(title: "Find your rhythm",
                        message: "Log a few workouts to see your activity patterns here.", icon: "chart.xyaxis.line")
                } else {
                    AppSectionTitle(title: "Your rhythm, at a glance", subtitle: "A summary of the workouts you've logged.")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                        count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        WorkoutStatCard(title: "Last 7 days", value: "\(summary.weekSessions)", icon: "calendar", color: AppTheme.accent)
                        WorkoutStatCard(title: "Average minutes", value: "\(Int(summary.averageMinutes))", icon: "clock", color: AppTheme.accent)
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: 18) {
                            AppSectionTitle(title: "Sessions over time")
                            ChartPeriodPicker(selection: $period)
                            WorkoutSessionsChart(summary: summary, period: period, domain: period.domain(now: now))
                        }
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: 16) {
                            DetailRow(title: "Most logged type", value: summary.commonType)
                            Divider()
                            DetailRow(title: "Current day streak", value: "\(summary.streak)")
                            Divider()
                            DetailRow(title: "Total sessions", value: "\(summary.totalSessions)")
                        }
                    }
                    Label("Calculated on your device.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Workout patterns").navigationBarTitleDisplayMode(.inline).appScreen()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

/// Selection updates only the bounded chart data, without regrouping the user's entire history.
private struct WorkoutSessionsChart: View {
    let summary: FitnessMetrics.WorkoutSummary
    let period: ChartPeriod
    let domain: ClosedRange<Date>
    @State private var selectedDate: Date?

    var body: some View {
        let calendar = Calendar.current
        let data = summary.days
        let selected = selectedDate.flatMap { date in data.first { calendar.isDate($0.date, inSameDayAs: date) } }
        return VStack(alignment: .leading, spacing: 18) {
            ChartReadout(title: selected?.date.formatted(date: .abbreviated, time: .omitted) ?? "Total sessions",
                value: "\(selected?.count ?? summary.periodSessions)", detail: selected == nil ? "Last \(period.rawValue) days" : "Selected day")
            Chart(data) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Sessions", day.count))
                    .foregroundStyle(AppTheme.accent.gradient).cornerRadius(5)
                    .opacity(selected == nil || selected?.date == day.date ? 1 : 0.35)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(day.count) sessions")
                if let selected, selected.date == day.date {
                    RuleMark(x: .value("Selected", selected.date, unit: .day)).foregroundStyle(.secondary.opacity(0.4))
                }
            }.frame(height: 220)
                .chartXScale(domain: domain)
                .chartYScale(domain: 0...max(3, summary.maximumDailySessions + 1))
                .chartXAxis {
                    if period == .week {
                        AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: period.axisStride)) { value in
                            AxisValueLabel { if let date = value.as(Date.self) { ChartDateLabel(date: date) } }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                .chartXSelection(value: $selectedDate)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Text("Touch the chart to inspect a day.").font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: period) { _, _ in selectedDate = nil }
    }
}
