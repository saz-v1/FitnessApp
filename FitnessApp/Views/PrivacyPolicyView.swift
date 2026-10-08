import SwiftUI

/// Bundled policy remains available when the device is offline.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppSectionTitle(title: "Your data stays with you", subtitle: "FitSwift · Local app privacy policy")
                policySection("What you save", icon: "lock.shield") {
                    Text("FitSwift stores the profile measurements, goals, weight entries, meals, saved meal templates, workouts, exercise details and achievement progress you enter on this device. Active workout drafts include your sets, reps, lap splits and timer timestamps so you can resume. These records support your journal, charts and fitness estimates.")
                    Text("Your saved journal uses iOS file protection and is excluded from device backups. There is no account, server upload, advertising, tracking or third-party analytics in this version.")
                }
                policySection("Apple Health is optional", icon: "heart") {
                    Text("If you connect Apple Health, FitSwift reads only the health information you choose to share to display activity and sleep and import weight or workout entries. FitSwift does not write to Apple Health or send these readings to the developer.")
                    Text("Turn off Apple Health in Profile to stop new reads and imports. Manage or revoke permissions in Apple Health under your profile, Apps, then FitSwift. Turning off access keeps entries you previously imported in your journal.")
                }
                policySection("Reminders", icon: "bell") {
                    Text("Reminders are optional local notifications managed by iOS. Their chosen times, days, sound and enabled settings stay on your device. They do not require a server and do not include your fitness measurements.")
                    Text("Rest timer alerts are also optional local notifications. Food and exercise references are bundled with the app; searches and portion calculations run on this device.")
                }
                policySection("Keeping and deleting data", icon: "trash") {
                    Text("Entries stay in your journal until you delete them or delete the app. You can delete meals, weights and workouts from their history screens. To remove all journal records and your profile, delete FitSwift through iOS Settings, General, iPhone Storage. Offloading the app keeps its data.")
                    Text("Deleting FitSwift entries does not delete the original records in Apple Health. There is no cloud copy or recovery service, so deleting the app or replacing this device may lose your journal.")
                }
                Text("Updated 8 October 2026").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy Policy").navigationBarTitleDisplayMode(.inline).appScreen()
    }

    private func policySection<Content: View>(_ title: String, icon: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(AppTheme.accent)
                content().font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
