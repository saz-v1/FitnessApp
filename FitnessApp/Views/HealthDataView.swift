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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                        count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        HealthDataCard(title: "Steps", value: health.steps.formatted(), subtitle: "Today", icon: "figure.walk", color: AppTheme.accent)
                        HealthDataCard(title: "Active energy", value: "\(Int(health.activeEnergy))", subtitle: "kcal today", icon: "flame", color: AppTheme.warm)
                        HealthDataCard(title: "Heart rate", value: health.heartRate > 0 ? "\(Int(health.heartRate))" : "—", subtitle: "bpm · latest reading", icon: "heart", color: .pink)
                        HealthDataCard(title: "Sleep", value: health.sleepHours.formatted(.number.precision(.fractionLength(1))), subtitle: "hours in the last 24h", icon: "moon.zzz", color: .indigo)
                        HealthDataCard(title: "Stand time", value: "\(Int(health.standHours))", subtitle: "hours today", icon: "figure.stand", color: AppTheme.accent)
                        HealthDataCard(title: "Exercise", value: "\(Int(health.exerciseMinutes))", subtitle: "minutes today", icon: "figure.run", color: AppTheme.accent)
                    }
                    AppCard {
                        Label("Missing or unshared readings may appear as zero. You can manage access in Apple Health.",
                            systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary)
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
