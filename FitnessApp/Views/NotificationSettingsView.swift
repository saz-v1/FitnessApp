import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var manager = NotificationManager.shared
    @AppStorage("foodReminderEnabled") private var foodEnabled = false
    @AppStorage("workoutReminderEnabled") private var workoutEnabled = false
    @AppStorage("weightReminderEnabled") private var weightEnabled = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    IconBadge(icon: "bell.badge")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A gentle nudge").font(.headline)
                        Text("Keep the habits that work for you.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 10)
            }
            Section {
                Toggle(isOn: $foodEnabled) { reminderLabel("Log a meal", detail: "Daily at \(time(hour: 13))", icon: "fork.knife") }
                    .onChange(of: foodEnabled) { _, enabled in
                        if enabled { manager.scheduleFoodLogReminder() }
                        else { manager.removeNotification(identifier: "foodLogReminder") }
                    }
                Toggle(isOn: $workoutEnabled) { reminderLabel("Log a workout", detail: "Daily at \(time(hour: 17))", icon: "figure.run") }
                    .onChange(of: workoutEnabled) { _, enabled in
                        if enabled { manager.scheduleWorkoutReminder() }
                        else { manager.removeNotification(identifier: "workoutReminder") }
                    }
                Toggle(isOn: $weightEnabled) { reminderLabel("Log your weight", detail: "Mondays at \(time(hour: 10))", icon: "scalemass") }
                    .onChange(of: weightEnabled) { _, enabled in
                        if enabled { manager.scheduleWeightLogReminder() }
                        else { manager.removeNotification(identifier: "weightLogReminder") }
                    }
            } header: { Text("Your reminders") } footer: {
                Text("Times follow your device's local time. Reminder messages keep your health details private.")
            }
            if let error = manager.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
            Section {
                Button { manager.scheduleTestNotification() } label: { Label("Send a sample reminder", systemImage: "paperplane") }
            } footer: { Text("A sample arrives in five seconds, if notifications are allowed.") }
            Section {
                Button("Turn off all reminders", role: .destructive) { manager.removeAllNotifications() }
            }
        }
        .appForm().navigationTitle("Reminders").appScreen()
    }
    private func reminderLabel(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AppTheme.accent).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
        }
    }
    private func time(hour: Int) -> String {
        (Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date())
            .formatted(date: .omitted, time: .shortened)
    }
}
