import Foundation
import UserNotifications
import Combine

enum ReminderPermission: Equatable {
    case notRequested, allowed, quiet, denied
    var canDeliver: Bool { self == .allowed || self == .quiet }
}

@MainActor
protocol ReminderNotificationCenter {
    func permission() async -> ReminderPermission
    func requestPermission() async throws -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor
struct SystemReminderCenter: ReminderNotificationCenter {
    let center = UNUserNotificationCenter.current()
    func permission() async -> ReminderPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .ephemeral: return .allowed
        case .provisional: return .quiet
        case .denied: return .denied
        default: return .notRequested
        }
    }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeDelivered(_ identifiers: [String]) { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
}

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared: NotificationManager = {
        let manager = NotificationManager(defaults: .standard, center: SystemReminderCenter())
        let center = UNUserNotificationCenter.current()
        center.delegate = manager
        let open = UNNotificationAction(identifier: "LOG_NOW", title: "Log now", options: [.foreground, .authenticationRequired])
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Remind me in 15 minutes", options: [])
        center.setNotificationCategories(Set(ReminderKind.allCases.map {
            UNNotificationCategory(identifier: $0.id, actions: [open, snooze], intentIdentifiers: [], options: [])
        }))
        return manager
    }()

    @Published private(set) var reminders: [ReminderSettings]
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var permission: ReminderPermission = .notRequested
    @Published private(set) var nextDates: [ReminderKind: Date] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var sampleMessage: String?
    @Published private(set) var isUpdating = false
    @Published private(set) var isSendingSample = false
    @Published private(set) var pendingRoute: ReminderKind?
    private let defaults: UserDefaults
    private let center: any ReminderNotificationCenter
    private var revisions: [ReminderKind: Int] = [:]
    private var dirty: Set<ReminderKind> = []
    private var snoozes: Set<ReminderKind> = []
    private var shouldRequestPermission = false
    private var worker: Task<Void, Never>?
    private var reconciling = false
    private var sampleRevision = 0

    init(defaults: UserDefaults, center: any ReminderNotificationCenter) {
        self.defaults = defaults; self.center = center
        reminders = ReminderStore.load(defaults: defaults)
        soundEnabled = defaults.object(forKey: "reminderSoundEnabled") as? Bool ?? true
        super.init()
    }
    var enabledCount: Int { reminders.filter(\.enabled).count }
    func settings(for kind: ReminderKind) -> ReminderSettings {
        reminders.first { $0.kind == kind } ?? ReminderSettings(kind: kind)
    }
    func update(_ settings: ReminderSettings) {
        guard settings.isValid, let index = reminders.firstIndex(where: { $0.kind == settings.kind }),
              reminders[index] != settings else { return }
        let newlyEnabled = settings.enabled && !reminders[index].enabled
        reminders[index] = settings
        ReminderStore.save(reminders, defaults: defaults)
        queue(settings.kind, requestPermission: newlyEnabled, clearSnooze: true)
    }
    func setSoundEnabled(_ enabled: Bool) {
        guard enabled != soundEnabled else { return }
        soundEnabled = enabled
        defaults.set(enabled, forKey: "reminderSoundEnabled")
        for item in reminders where item.enabled { queue(item.kind, clearSnooze: true) }
    }
    private func queue(_ kind: ReminderKind, requestPermission: Bool = false, clearSnooze: Bool = false) {
        revisions[kind, default: 0] += 1
        dirty.insert(kind)
        shouldRequestPermission = shouldRequestPermission || requestPermission
        let identifiers = clearSnooze ? kind.managedIdentifiers : kind.managedIdentifiers.filter { $0 != kind.id + ".snooze" }
        center.removePending(identifiers)
        if clearSnooze { snoozes.remove(kind); center.removeDelivered(kind.managedIdentifiers) }
        nextDates[kind] = nil
        sampleMessage = nil
        if worker == nil { worker = Task { await processQueue() } }
    }

    /// Serialized add operations prevent an older completion from overwriting a newer schedule.
    private func processQueue() async {
        isUpdating = true
        defer { isUpdating = false; worker = nil }
        while !dirty.isEmpty || !snoozes.isEmpty {
            let requestPermission = shouldRequestPermission
            shouldRequestPermission = false
            do {
                try await refreshPermission(requestIfNeeded: requestPermission, requiresEnabledReminder: true)
                guard let kind = ReminderKind.allCases.first(where: { dirty.contains($0) || snoozes.contains($0) }) else { continue }
                let regular = dirty.remove(kind) != nil
                if !regular { snoozes.remove(kind) }
                let revision = revisions[kind, default: 0]
                let item = settings(for: kind)
                guard item.enabled, permission.canDeliver else { nextDates[kind] = nil; continue }
                let requests = regular ? makeRequests(item) : [makeSnooze(kind)]
                for request in requests {
                    guard revisions[kind, default: 0] == revision, settings(for: kind).enabled else { break }
                    try await center.add(request)
                    if revisions[kind, default: 0] != revision || !settings(for: kind).enabled {
                        center.removePending([request.identifier])
                        break
                    }
                }
                if revisions[kind, default: 0] == revision {
                    errorMessage = nil
                    if regular {
                        nextDates[kind] = requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
                    } else {
                        let snoozed = Date().addingTimeInterval(900)
                        nextDates[kind] = min(nextDates[kind] ?? snoozed, snoozed)
                    }
                }
            } catch {
                dirty.removeAll(); snoozes.removeAll()
                errorMessage = "The reminder could not be scheduled. Please try again."
            }
        }
    }
    private func refreshPermission(requestIfNeeded: Bool, requiresEnabledReminder: Bool = false) async throws {
        var status = await center.permission()
        if status == .notRequested && requestIfNeeded && (!requiresEnabledReminder || enabledCount > 0) {
            _ = try await center.requestPermission()
            status = await center.permission()
        }
        permission = status
    }
    func requestNotifications() async {
        do {
            try await refreshPermission(requestIfNeeded: true)
            await reconcileReminders()
        } catch { errorMessage = "Notification permission could not be checked. Please try again." }
    }
    func makeRequests(_ item: ReminderSettings) -> [UNNotificationRequest] {
        zip(item.requestIdentifiers, item.triggerComponents).map { identifier, date in
            UNNotificationRequest(identifier: identifier, content: content(for: item.kind),
                trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
        }
    }
    private func content(for kind: ReminderKind?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "FitSwift Reminder"
        content.body = "Take a moment to update your fitness journal."
        content.sound = soundEnabled ? .default : nil
        content.categoryIdentifier = kind?.id ?? ""
        // No profile, measurement, meal or workout details appear on the lock screen.
        return content
    }
    private func makeSnooze(_ kind: ReminderKind) -> UNNotificationRequest {
        UNNotificationRequest(identifier: kind.id + ".snooze", content: content(for: kind),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false))
    }
    /// Repairs missing schedules and updates system permission without prompting on launch.
    func reconcileReminders() async {
        guard !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        do { try await refreshPermission(requestIfNeeded: false) } catch { return }
        let pending = await center.pending()
        for item in reminders {
            let current = pending.filter { item.kind.managedIdentifiers.contains($0.identifier) && $0.identifier != item.kind.id + ".snooze" }
            if !item.enabled || !permission.canDeliver {
                center.removePending(item.kind.managedIdentifiers)
                nextDates[item.kind] = nil
            } else if !matches(current, settings: item) {
                queue(item.kind)
            } else {
                let all = pending.filter { item.kind.managedIdentifiers.contains($0.identifier) }
                nextDates[item.kind] = all.compactMap { request in
                    if let calendar = request.trigger as? UNCalendarNotificationTrigger { return calendar.nextTriggerDate() }
                    if let interval = request.trigger as? UNTimeIntervalNotificationTrigger { return interval.nextTriggerDate() }
                    return nil
                }.min()
            }
        }
        await finishPendingUpdates()
    }
    private func matches(_ requests: [UNNotificationRequest], settings: ReminderSettings) -> Bool {
        guard Set(requests.map(\.identifier)) == Set(settings.requestIdentifiers) else { return false }
        return makeRequests(settings).allSatisfy { expected in
            guard let actual = requests.first(where: { $0.identifier == expected.identifier }),
                  let trigger = actual.trigger as? UNCalendarNotificationTrigger,
                  let desired = expected.trigger as? UNCalendarNotificationTrigger else { return false }
            return trigger.repeats && trigger.dateComponents == desired.dateComponents &&
                (actual.content.sound != nil) == soundEnabled && actual.content.categoryIdentifier == settings.kind.id
        }
    }
    func scheduleTestNotification() async {
        guard !isSendingSample else { return }
        isSendingSample = true
        defer { isSendingSample = false }
        sampleRevision += 1
        let revision = sampleRevision
        sampleMessage = nil
        do {
            try await refreshPermission(requestIfNeeded: true)
            guard sampleRevision == revision, permission.canDeliver else { return }
            let content = content(for: nil)
            content.body = "Your reminders are working."
            try await center.add(UNNotificationRequest(identifier: "testNotification", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            guard sampleRevision == revision else { center.removePending(["testNotification"]); return }
            errorMessage = nil
            sampleMessage = "Sample scheduled. It should arrive in five seconds."
        } catch { errorMessage = "The sample reminder could not be scheduled. Please try again." }
    }
    func removeAllNotifications() {
        sampleRevision += 1
        shouldRequestPermission = false
        snoozes.removeAll()
        for index in reminders.indices { reminders[index].enabled = false }
        ReminderStore.save(reminders, defaults: defaults)
        for kind in ReminderKind.allCases { queue(kind, clearSnooze: true) }
        center.removePending(["testNotification"])
        center.removeDelivered(["testNotification"])
        errorMessage = nil; sampleMessage = nil
    }
    func handleResponse(identifier: String, action: String) {
        guard let kind = ReminderKind.fromNotification(identifier) else { return }
        if action == "SNOOZE" {
            guard settings(for: kind).enabled else { return }
            snoozes.insert(kind)
            if worker == nil { worker = Task { await processQueue() } }
        } else if action == UNNotificationDefaultActionIdentifier || action == "LOG_NOW" {
            pendingRoute = kind
        }
    }
    func consumeRoute() { pendingRoute = nil }
    func finishPendingUpdates() async { await worker?.value }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            handleResponse(identifier: response.notification.request.identifier, action: response.actionIdentifier)
            await finishPendingUpdates()
            completionHandler()
        }
    }
}
