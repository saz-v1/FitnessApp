import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    @Published private(set) var errorMessage: String?
    private let center = UNUserNotificationCenter.current()
    private var revisions: [String: Int] = [:]
    private let preferences = ["foodLogReminder": "foodReminderEnabled", "workoutReminder": "workoutReminderEnabled", "weightLogReminder": "weightReminderEnabled"]

    private override init() {
        super.init()
        center.delegate = self
    }

    func scheduleTestNotification() {
        schedule(title: "FitSwift Reminder", body: "Your reminders are working.",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false), id: "testNotification")
    }
    func scheduleFoodLogReminder() { calendarReminder(hour: 13, id: "foodLogReminder") }
    func scheduleWorkoutReminder() { calendarReminder(hour: 17, id: "workoutReminder") }
    func scheduleWeightLogReminder() { calendarReminder(hour: 10, weekday: 2, id: "weightLogReminder") }

    private func calendarReminder(hour: Int, weekday: Int? = nil, id: String) {
        var date = DateComponents()
        date.hour = hour; date.minute = 0; date.weekday = weekday
        // Keep health details out of lock-screen notifications.
        schedule(title: "FitSwift Reminder", body: "Take a moment to update your fitness journal.",
            trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true), id: id)
    }

    private func schedule(title: String, body: String, trigger: UNNotificationTrigger, id: String) {
        revisions[id, default: 0] += 1
        let revision = revisions[id]
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard revisions[id] == revision else { return }
                guard granted else {
                    errorMessage = "Notifications are disabled. Enable them in Settings to receive reminders."
                    if let key = preferences[id] { UserDefaults.standard.set(false, forKey: key) }
                    return
                }
                if let key = preferences[id], !UserDefaults.standard.bool(forKey: key) { return }
                let content = UNMutableNotificationContent()
                content.title = title; content.body = body; content.sound = .default
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                if revisions[id] != revision, preferences[id].map({ !UserDefaults.standard.bool(forKey: $0) }) ?? true {
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                }
                errorMessage = nil
            } catch { errorMessage = "The reminder could not be scheduled. Please try again." }
        }
    }

    /// Restore opted-in reminders without displaying a permission request on launch.
    func reconcileReminders() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        if UserDefaults.standard.bool(forKey: "foodReminderEnabled") { scheduleFoodLogReminder() }
        if UserDefaults.standard.bool(forKey: "workoutReminderEnabled") { scheduleWorkoutReminder() }
        if UserDefaults.standard.bool(forKey: "weightReminderEnabled") { scheduleWeightLogReminder() }
    }

    func removeAllNotifications() {
        for id in Array(preferences.keys) + ["testNotification"] { revisions[id, default: 0] += 1 }
        for key in preferences.values { UserDefaults.standard.set(false, forKey: key) }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    func removeNotification(identifier: String) {
        revisions[identifier, default: 0] += 1
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) { completionHandler() }
}
