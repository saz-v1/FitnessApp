import SwiftUI

/// Root view of the application that sets up the main tab navigation
struct ContentView: View {
    private enum AppTab { case dashboard, workouts, profile }
    @State private var selectedTab: AppTab = .dashboard
    @State private var reminderSheet: ReminderKind?
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthIntegrationEnabled") private var healthIntegrationEnabled = false
    @AppStorage("reminderSoundEnabled") private var reminderSoundEnabled = true
    @StateObject private var notifications = NotificationManager.shared
    // StateObject ensures UserManager persists for the app's lifetime
    @StateObject private var userManager = UserManager.shared
    @StateObject private var workoutSession = WorkoutSessionStore()
    // StateObject for HealthKit integration
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some View {
        // TabView creates the bottom tab bar navigation
        TabView(selection: $selectedTab) {
            // Dashboard tab showing overview of fitness metrics
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.dashboard)
            
            // Workout logging tab
            WorkoutLogView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(AppTab.workouts)
            
            // User profile and settings tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppTab.profile)
        }
        // Inject UserManager into the environment for child views
        .environmentObject(userManager)
        .environmentObject(workoutSession)
        // Set the app's accent color
        .tint(AppTheme.accent)
        .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .system).colorScheme)
        .toolbarBackground(AppTheme.surface, for: .tabBar)
        .safeAreaInset(edge: .top) {
            if let error = userManager.persistenceError {
                Text(error).font(.caption).foregroundColor(.red).padding().background(.regularMaterial)
            }
        }
        .overlay {
            if scenePhase != .active {
                Color(.systemBackground).ignoresSafeArea().overlay {
                    Label("FitSwift", systemImage: "lock.shield").font(.title)
                }
            }
        }
        .task {
            await notifications.reconcileReminders()
            if healthIntegrationEnabled { await healthKitManager.fetchTodaysHealthData() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                userManager.retryLoadingSavedData()
                workoutSession.retryLoading()
                workoutSession.reconcileAlert(force: true)
                Task {
                    await notifications.reconcileReminders()
                    if healthIntegrationEnabled { await healthKitManager.fetchTodaysHealthData() }
                }
            }
        }
        .onChange(of: healthIntegrationEnabled) { _, enabled in
            if !enabled {
                healthKitManager.disconnect()
                HealthKitService.shared.disconnect()
            }
        }
        .onChange(of: notifications.pendingRoute) { _, route in openReminder(route) }
        .onChange(of: reminderSoundEnabled) { _, _ in workoutSession.reconcileAlert(force: true) }
        .sheet(item: $reminderSheet) { kind in
            Group {
                switch kind {
                case .meal: AddCalorieSheet()
                case .workout: AddWorkoutSheet()
                case .weight: AddWeightSheet()
                }
            }.environmentObject(userManager)
        }
        .onAppear { openReminder(notifications.pendingRoute) }
    }
    private func openReminder(_ kind: ReminderKind?) {
        guard let kind else { return }
        selectedTab = kind == .workout ? .workouts : .dashboard
        reminderSheet = kind
        notifications.consumeRoute()
    }
}

// Preview provider for SwiftUI canvas
#Preview {
    ContentView()
}
