import SwiftUI

enum ChartPeriod: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90, year = 365
    var id: Int { rawValue }
    var label: String { self == .year ? "1 year" : "\(rawValue) days" }
    var axisStride: Int { self == .week ? 1 : (self == .month ? 7 : (self == .quarter ? 21 : 60)) }
    func start(now: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1 - rawValue, to: calendar.startOfDay(for: now)) ?? now
    }
    func domain(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
        start(now: now, calendar: calendar)...(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
    }
}

struct ChartPeriodPicker: View {
    @Binding var selection: ChartPeriod
    var periods: [ChartPeriod] = [.week, .month, .quarter]
    var body: some View {
        Picker("Time range", selection: $selection) {
            ForEach(periods) { Text($0.label).tag($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier("chart-period")
    }
}

struct ChartReadout: View {
    let title: String
    let value: String
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChartSummary<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) :
            AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout { content }
    }
}

struct ChartDateLabel: View {
    let date: Date
    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()))
            Text(date.formatted(.dateTime.month(.abbreviated)))
        }.font(.caption2).fixedSize().dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
