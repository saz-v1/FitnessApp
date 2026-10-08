import Foundation
import Testing
import UserNotifications
@testable import FitnessApp

@MainActor
private final class TestReminderCenter: ReminderNotificationCenter {
    var status: ReminderPermission = .allowed
    var requests: [String: UNNotificationRequest] = [:]
    var promptCount = 0
    var beforeAdd: (() -> Void)?
    var addCount = 0
    var failure = false
    func permission() async -> ReminderPermission { status }
    func requestPermission() async throws -> Bool { promptCount += 1; status = .allowed; return true }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws {
        addCount += 1
        let action = beforeAdd; beforeAdd = nil; action?()
        await Task.yield()
        if failure { throw CocoaError(.fileWriteUnknown) }
        requests[request.identifier] = request
    }
    func removePending(_ identifiers: [String]) { for id in identifiers { requests[id] = nil } }
    func removeDelivered(_ identifiers: [String]) {}
}

@MainActor
struct ReminderTests {
    private func make(_ center: TestReminderCenter) -> NotificationManager {
        NotificationManager(defaults: UserDefaults(suiteName: UUID().uuidString)!, center: center)
    }
    @Test func legacyPreferencesAndCustomTimesPersist() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "foodReminderEnabled")
        let center = TestReminderCenter()
        let manager = NotificationManager(defaults: defaults, center: center)
        #expect(manager.settings(for: .meal).enabled)
        #expect(manager.settings(for: .weight).weekdays == [2])
        var item = manager.settings(for: .meal)
        item.hour = 8; item.minute = 45; item.weekdays = [2, 4, 6]
        manager.update(item)
        let reloaded = NotificationManager(defaults: defaults, center: center)
        #expect(reloaded.settings(for: .meal) == item)
    }
    @Test func customDaysCreateCorrectPrivateCalendarRequests() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .meal)
        item.enabled = true; item.hour = 8; item.minute = 45; item.weekdays = [2, 4, 6]
        manager.update(item); await manager.finishPendingUpdates()
        #expect(center.requests.count == 3)
        for day in item.weekdays {
            let request = center.requests["foodLogReminder.day.\(day)"]!
            let trigger = request.trigger as! UNCalendarNotificationTrigger
            #expect(trigger.dateComponents.hour == 8 && trigger.dateComponents.minute == 45)
            #expect(trigger.dateComponents.weekday == day && trigger.repeats)
            #expect(request.content.body == "Take a moment to update your fitness journal.")
        }
    }
    @Test func launchDoesNotRequestPermissionAndDeniedSchedulesStaySaved() async {
        let center = TestReminderCenter(); center.status = .denied
        let manager = make(center)
        var item = manager.settings(for: .workout); item.enabled = true
        manager.update(item); await manager.finishPendingUpdates(); await manager.reconcileReminders()
        #expect(center.promptCount == 0 && center.requests.isEmpty)
        #expect(manager.settings(for: .workout).enabled)
        #expect(manager.permission == .denied)
        center.status = .notRequested
        await manager.reconcileReminders()
        #expect(center.promptCount == 0)
    }
    @Test func rapidEnableDisableDoesNotRequestPermission() async {
        let center = TestReminderCenter(); center.status = .notRequested
        let manager = make(center)
        var item = manager.settings(for: .meal); item.enabled = true; manager.update(item)
        item.enabled = false; manager.update(item)
        await manager.finishPendingUpdates()
        #expect(center.promptCount == 0 && center.requests.isEmpty)
    }
    @Test func staleCompletionCannotRestoreDisabledReminder() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .workout); item.enabled = true
        center.beforeAdd = {
            var disabled = manager.settings(for: .workout); disabled.enabled = false; manager.update(disabled)
        }
        manager.update(item); await manager.finishPendingUpdates()
        #expect(center.requests.isEmpty)
    }
    @Test func scheduleChangedDuringAddKeepsOnlyLatestTime() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .meal); item.enabled = true
        center.beforeAdd = {
            var latest = manager.settings(for: .meal); latest.hour = 7; latest.minute = 20; manager.update(latest)
        }
        manager.update(item); await manager.finishPendingUpdates()
        #expect(center.requests.count == 1)
        let trigger = center.requests["foodLogReminder"]?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 7 && trigger?.dateComponents.minute == 20)
    }
    @Test func unchangedSchedulesAreNotAddedAgainAndSoundChangesApply() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .weight); item.enabled = true
        manager.update(item); await manager.finishPendingUpdates()
        let adds = center.addCount
        await manager.reconcileReminders()
        #expect(center.addCount == adds)
        manager.setSoundEnabled(false); await manager.finishPendingUpdates()
        #expect(center.requests.values.allSatisfy { $0.content.sound == nil })
    }
    @Test func snoozeAndRouteActionsRespectTurnOffAll() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .weight); item.enabled = true
        manager.update(item); await manager.finishPendingUpdates()
        manager.handleResponse(identifier: "weightLogReminder.day.2", action: "SNOOZE")
        await manager.finishPendingUpdates()
        let trigger = center.requests["weightLogReminder.snooze"]?.trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.timeInterval == 900 && trigger?.repeats == false)
        let snoozed = manager.nextDates[.weight]!
        await manager.reconcileReminders()
        #expect(abs(manager.nextDates[.weight]!.timeIntervalSince(snoozed)) < 60)
        manager.handleResponse(identifier: "weightLogReminder.snooze", action: "LOG_NOW")
        #expect(manager.pendingRoute == .weight)
        manager.consumeRoute()
        manager.removeAllNotifications(); await manager.finishPendingUpdates()
        manager.handleResponse(identifier: "weightLogReminder.day.2", action: "SNOOZE")
        await manager.finishPendingUpdates()
        #expect(center.requests.isEmpty && manager.enabledCount == 0 && manager.pendingRoute == nil)
    }
    @Test func invalidSchedulesAreRejectedAndFailuresAreVisible() async {
        let center = TestReminderCenter(); let manager = make(center)
        var item = manager.settings(for: .meal); item.hour = 25
        manager.update(item)
        #expect(manager.settings(for: .meal).hour == 13)
        item.hour = 13; item.weekdays = []
        manager.update(item)
        #expect(!manager.settings(for: .meal).weekdays.isEmpty)
        item.weekdays = Set(1...7); item.enabled = true; center.failure = true
        manager.update(item); await manager.finishPendingUpdates()
        #expect(manager.errorMessage != nil && !manager.isUpdating)
    }
}
