import SwiftUI

/// Root view of the application that sets up the main tab navigation
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthIntegrationEnabled") private var healthIntegrationEnabled = false
    @StateObject private var notifications = NotificationManager.shared
    // StateObject ensures UserManager persists for the app's lifetime
    @StateObject private var userManager = UserManager.shared
    // StateObject for HealthKit integration
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some View {
        // TabView creates the bottom tab bar navigation
        TabView {
            // Dashboard tab showing overview of fitness metrics
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            
            // Workout logging tab
            WorkoutLogView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
            
            // User profile and settings tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        // Inject UserManager into the environment for child views
        .environmentObject(userManager)
        // Set the app's accent color
        .tint(AppTheme.accent)
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
    }
}

// Preview provider for SwiftUI canvas
#Preview {
    ContentView()
}
