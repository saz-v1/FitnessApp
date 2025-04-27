import Foundation
import UserNotifications

/// Manages all notification-related functionality in the app
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    /// Request permission to send notifications
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UNUserNotificationCenter.current().delegate = self
                }
            }
        }
    }
    
    /// Schedule a test notification that will appear in 5 seconds
    func scheduleTestNotification() {
        scheduleNotification(
            title: "Test Notification",
            body: "This is a test notification to verify the system is working!",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false),
            identifier: "testNotification"
        )
    }
    
    /// Schedule a daily reminder to log food
    func scheduleFoodLogReminder() {
        var dateComponents = DateComponents()
        dateComponents.hour = 13
        dateComponents.minute = 0
        
        scheduleNotification(
            title: "Time to Log Your Food",
            body: "Don't forget to track your meals for today!",
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true),
            identifier: "foodLogReminder"
        )
    }
    
    /// Schedule a daily reminder to log a workout
    func scheduleWorkoutReminder() {
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 0
        
        scheduleNotification(
            title: "Time for Your Workout",
            body: "Stay on track with your fitness goals!",
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true),
            identifier: "workoutReminder"
        )
    }
    
    /// Schedule a reminder to log weight
    func scheduleWeightLogReminder() {
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // Monday
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        scheduleNotification(
            title: "Weekly Weight Check",
            body: "Time to track your progress!",
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true),
            identifier: "weightLogReminder"
        )
    }
    
    /// Helper function to schedule notifications
    private func scheduleNotification(title: String, body: String, trigger: UNNotificationTrigger, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "fitnessApp"
        content.categoryIdentifier = "FITNESS_CATEGORY"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Remove all scheduled notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Remove a specific notification by identifier
    func removeNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Clear the badge count when notification is received
        UIApplication.shared.applicationIconBadgeNumber = 0
        completionHandler()
    }
} 
