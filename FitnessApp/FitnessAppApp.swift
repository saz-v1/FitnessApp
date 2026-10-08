import SwiftUI

// Main entry point for the FitnessApp
@main
struct FitnessAppApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           !ProcessInfo.processInfo.arguments.contains("--preserve-test-preferences"),
           let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
            UserDefaults(suiteName: "FitSwift.UITests")?.removePersistentDomain(forName: "FitSwift.UITests")
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            // ContentView is the root view of the application
            ContentView()
        }
    }
}
