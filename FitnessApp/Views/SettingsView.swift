import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .system ? nil : (self == .light ? .light : .dark) }
}

struct SettingsView: View {
    @EnvironmentObject private var userManager: UserManager
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("healthIntegrationEnabled") private var healthEnabled = false
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var sync = HealthKitService.shared
    @StateObject private var reminders = NotificationManager.shared
    var body: some View {
        Form {
            Section {
                AppScreenHeader(title: "Your app, your way", subtitle: "Simple preferences. Everything stays local.", icon: "slider.horizontal.3")
            }.listRowBackground(AppTheme.surface)
            Section("Preferences") {
                NavigationLink { NotificationSettingsView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge").foregroundStyle(AppTheme.accent)
                        Text("Reminders")
                        Spacer()
                        Text(reminders.enabledCount == 0 ? "Off" : "\(reminders.enabledCount) enabled").foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("settings-reminders")
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.accessibilityIdentifier("settings-appearance")
            }
            Section {
                Toggle("Connect Apple Health", isOn: $healthEnabled)
                    .onChange(of: healthEnabled) { _, enabled in
                        if enabled { Task { await health.fetchTodaysHealthData() } }
                        else { health.disconnect(); sync.disconnect() }
                    }.accessibilityIdentifier("settings-health")
                if healthEnabled {
                    NavigationLink("View Apple Health activity") { HealthDataView() }
                    Button {
                        Task { await health.fetchTodaysHealthData() }
                    } label: {
                        HStack {
                            Label("Refresh Apple Health", systemImage: "arrow.clockwise")
                            Spacer()
                            if health.isRefreshing { ProgressView() }
                        }
                    }.disabled(health.isRefreshing)
                    Button {
                        Task { await sync.syncWithHealthKit() }
                    } label: {
                        HStack {
                            Label("Import weight history", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if sync.isSyncing { ProgressView() }
                        }
                    }.disabled(sync.isSyncing)
                    if let last = sync.lastSyncDate {
                        Text("Last import: \(last.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = sync.syncError ?? health.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
                    }
                }
            } header: { Text("Apple Health") } footer: {
                Text("Optional, read-only access. Turning this off stops new reads and imports. Previously imported entries stay in your journal.")
            }
            Section("Your journal") {
                DetailRow(title: "Meal entries", value: userManager.user.calorieHistory.count.formatted())
                DetailRow(title: "Weight entries", value: userManager.user.weightHistory.count.formatted())
                DetailRow(title: "Workout entries", value: userManager.user.workoutHistory.count.formatted())
                NavigationLink { SavedMealsView() } label: { DetailRow(title: "Saved meals", value: (userManager.user.savedMeals ?? []).count.formatted()) }
            }
            Section("Offline reference libraries") {
                NavigationLink { FoodLibraryView() } label: { Label("Foods & nutrition", systemImage: "carrot") }
                NavigationLink { ExerciseLibraryView() } label: { Label("Exercise movements", systemImage: "dumbbell") }
                Text("UK: McCance and Widdowson's CoFID (2021), Open Government Licence. US: USDA FoodData Central, SR Legacy (2018), public domain / CC0. FitSwift original exercise descriptions. Libraries are included with the app and searched on this device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { PrivacyPolicyView() } label: { Label("Privacy Policy", systemImage: "lock.shield") }
                Label("No account, ads or cloud uploads", systemImage: "checkmark.shield")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Your journal is stored on this device and excluded from backups. Deleting the app removes it.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Privacy & storage") }
            Section("About FitSwift") {
                DetailRow(title: "Version", value: version)
                Text("Fitness estimates are general guidance. They are not a medical assessment.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .appForm().navigationTitle("Settings").appScreen()
        .task { await reminders.reconcileReminders() }
    }
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
