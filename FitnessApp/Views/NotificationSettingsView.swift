import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("foodReminderEnabled") private var foodReminderEnabled = false
    @AppStorage("workoutReminderEnabled") private var workoutReminderEnabled = false
    @AppStorage("weightReminderEnabled") private var weightReminderEnabled = false
    
    var body: some View {
        Form {
            Section(header: Text("Daily Reminders")) {
                Toggle("Food Log Reminder", isOn: $foodReminderEnabled)
                    .onChange(of: foodReminderEnabled) { oldValue, newValue in
                        if newValue {
                            notificationManager.scheduleFoodLogReminder()
                        } else {
                            notificationManager.removeNotification(identifier: "foodLogReminder")
                        }
                    }
                
                Toggle("Workout Reminder", isOn: $workoutReminderEnabled)
                    .onChange(of: workoutReminderEnabled) { oldValue, newValue in
                        if newValue {
                            notificationManager.scheduleWorkoutReminder()
                        } else {
                            notificationManager.removeNotification(identifier: "workoutReminder")
                        }
                    }
            }
            
            Section(header: Text("Weekly Reminders")) {
                Toggle("Weight Log Reminder", isOn: $weightReminderEnabled)
                    .onChange(of: weightReminderEnabled) { oldValue, newValue in
                        if newValue {
                            notificationManager.scheduleWeightLogReminder()
                        } else {
                            notificationManager.removeNotification(identifier: "weightLogReminder")
                        }
                    }
            }
            
            Section {
                Button("Test Notification") {
                    notificationManager.scheduleTestNotification()
                }
            } header: {
                Text("Testing")
            } footer: {
                Text("Send a test notification to verify the system is working.")
            }
            
            Section(footer: Text("Notifications will help you stay on track with your fitness goals.")) {
                Button("Remove All Notifications") {
                    notificationManager.removeAllNotifications()
                    foodReminderEnabled = false
                    workoutReminderEnabled = false
                    weightReminderEnabled = false
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Notifications")
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
} 