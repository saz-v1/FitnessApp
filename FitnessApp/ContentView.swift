import SwiftUI

/// Root view of the application that sets up the main tab navigation
struct ContentView: View {
    // StateObject ensures UserManager persists for the app's lifetime
    @StateObject private var userManager = UserManager.shared
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
        .tint(.green)
        .task {
            do {
                try await healthKitManager.requestAuthorization()
                await healthKitManager.fetchTodaysHealthData()
            } catch {
                print("Failed to authorize HealthKit: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
