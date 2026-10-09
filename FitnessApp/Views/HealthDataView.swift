import SwiftUI

struct HealthDataView: View {
    @AppStorage("healthIntegrationEnabled") private var enabled = false
    @StateObject private var health = HealthKitManager.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !enabled {
                    AppEmptyState(title: "Your health, your choice",
                        message: "Bring together activity and sleep from Apple Health. Choose what to share; manual tracking always works.",
                        icon: "heart.fill", actionTitle: "Connect Apple Health") {
                            enabled = true
                            Task { await health.fetchTodaysHealthData() }
                        }
                } else {
                    AppSectionTitle(title: "Today's activity", subtitle: "Readings shared through Apple Health")
                    if health.isRefreshing { ProgressView("Refreshing Apple Health") }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                        count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        HealthDataCard(title: "Steps", value: value(.steps, health.steps.formatted()), subtitle: "Today", icon: "figure.walk", color: AppTheme.accent)
                            .accessibilityIdentifier("health-steps")
                        HealthDataCard(title: "Active energy", value: value(.activeEnergy, "\(Int(health.activeEnergy))"), subtitle: "kcal today", icon: "flame", color: AppTheme.warm)
                        HealthDataCard(title: "Heart rate", value: value(.heartRate, "\(Int(health.heartRate))"), subtitle: heartSubtitle, icon: "heart", color: .pink)
                        HealthDataCard(title: "Sleep", value: value(.sleep, health.sleepHours.formatted(.number.precision(.fractionLength(1)))), subtitle: "hours in the last 24h", icon: "moon.zzz", color: .indigo)
                        HealthDataCard(title: "Stand time", value: value(.standTime, health.standHours.formatted(.number.precision(.fractionLength(0...1)))), subtitle: "hours standing today", icon: "figure.stand", color: AppTheme.accent)
                        HealthDataCard(title: "Exercise", value: value(.exerciseTime, health.exerciseMinutes.formatted(.number.precision(.fractionLength(0...1)))), subtitle: "minutes today", icon: "figure.run", color: AppTheme.accent)
                    }
                    Button { Task { await health.fetchTodaysHealthData() } } label: { Label("Refresh Apple Health", systemImage: "arrow.clockwise") }
                        .buttonStyle(AppSecondaryButtonStyle()).disabled(health.isRefreshing).accessibilityIdentifier("refresh-health")
                    if let date = health.lastRefreshDate {
                        Text("Updated \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("A dash means no reading was shared for this period. Other readings can still load.",
                                systemImage: "info.circle").font(.subheadline)
                            Text("If steps are missing, open Apple Health, find FitSwift in your profile's app permissions and enable Steps. Then return here and refresh. Health does not tell apps whether a reading is missing or its read permission was denied.")
                                .font(.caption)
                            Text("Stand time is time spent standing, rather than the Apple Watch Stand ring's completed hours.").font(.caption)
                        }.foregroundStyle(.secondary)
                    }
                }
                if let error = health.errorMessage {
                    AppCard { Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.secondary) }
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Apple Health").appScreen()
        .task { if enabled { await health.fetchTodaysHealthData() } }
        .refreshable { if enabled { await health.fetchTodaysHealthData() } }
    }
    private func value(_ reading: HealthReading, _ text: String) -> String {
        health.availableReadings.contains(reading) ? text : "—"
    }
    private var heartSubtitle: String {
        health.heartRateTimestamp.map { "bpm · \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "bpm · latest reading"
    }
}

struct HealthDataCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(icon: icon, color: color)
                Text(title).font(.headline)
                Text(value).font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}
