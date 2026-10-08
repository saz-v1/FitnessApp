import Foundation
import UserNotifications
import Testing
@testable import FitnessApp

@MainActor
private final class WorkoutAlertCenter: ReminderNotificationCenter {
    var status: ReminderPermission = .allowed
    var requests: [String: UNNotificationRequest] = [:]
    var permissionRequests = 0
    var holdNextAdd = false
    var addCount = 0
    var addStarted: CheckedContinuation<Void, Never>?
    var heldAdd: CheckedContinuation<Void, Never>?
    func permission() async -> ReminderPermission { status }
    func requestPermission() async throws -> Bool { permissionRequests += 1; status = .denied; return false }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws {
        addCount += 1
        if holdNextAdd {
            holdNextAdd = false
            await withCheckedContinuation { heldAdd = $0; addStarted?.resume(); addStarted = nil }
        }
        requests[request.identifier] = request
    }
    func removePending(_ identifiers: [String]) { identifiers.forEach { requests.removeValue(forKey: $0) } }
    func removeDelivered(_ identifiers: [String]) {}
    func waitForHeldAdd() async { if heldAdd == nil { await withCheckedContinuation { addStarted = $0 } } }
    func releaseAdd() { heldAdd?.resume(); heldAdd = nil }
}

@MainActor
struct WorkoutRestAlertTests {
    private func makeStore(center: WorkoutAlertCenter, enabled: Bool = true, sound: Bool = true) -> (WorkoutSessionStore, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("draft.json")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(enabled, forKey: "workoutRestAlerts"); defaults.set(sound, forKey: "reminderSoundEnabled")
        return (WorkoutSessionStore(storageURL: url, defaults: defaults, alertCenter: center), url)
    }
    @Test func restAlertsFollowPauseResumeAndSoundPreference() async throws {
        let center = WorkoutAlertCenter(); let (store, url) = makeStore(center: center, sound: false)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = store.start(title: "Workout", type: .strength, intensity: .moderate, restSeconds: 60)
        store.startRest(); await store.waitForAlerts()
        let request = try #require(center.requests.values.first)
        #expect(request.content.sound == nil)
        #expect(request.content.body == "Your rest timer has finished.")
        #expect((request.trigger as? UNTimeIntervalNotificationTrigger)?.repeats == false)
        store.togglePause(); await store.waitForAlerts()
        #expect(center.requests.isEmpty)
        store.togglePause(); await store.waitForAlerts()
        #expect(center.requests.count == 1)
        #expect(store.discard()); await store.waitForAlerts()
        #expect(center.requests.isEmpty)
    }
    @Test func delayedAddCannotRestoreSkippedRestAlert() async {
        let center = WorkoutAlertCenter(); let (store, url) = makeStore(center: center)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await store.waitForAlerts()
        _ = store.start(title: "Workout", type: .strength, intensity: .moderate, restSeconds: 60)
        center.holdNextAdd = true
        store.startRest(); await center.waitForHeldAdd()
        store.skipRest(); center.releaseAdd(); await store.waitForAlerts()
        #expect(center.requests.isEmpty)
        store.startRest(); await store.waitForAlerts()
        #expect(center.requests.count == 1)
    }
    @Test func launchAndSessionNeverPromptUntilAlertsAreExplicitlyEnabled() async {
        let center = WorkoutAlertCenter(); center.status = .notRequested
        let (store, url) = makeStore(center: center, enabled: false)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = store.start(title: "Workout", type: .strength, intensity: .moderate, restSeconds: 60)
        store.startRest(); await store.waitForAlerts()
        #expect(center.permissionRequests == 0)
        await store.setRestAlerts(true); await store.waitForAlerts()
        #expect(center.permissionRequests == 1)
        #expect(!store.restAlertsEnabled)
        #expect(center.requests.isEmpty)
        #expect(store.errorMessage != nil)
    }
    @Test func repTapsDoNotRescheduleUnchangedRestDeadline() async {
        let center = WorkoutAlertCenter(); let (store, url) = makeStore(center: center)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = store.start(title: "Workout", type: .strength, intensity: .moderate, restSeconds: 60)
        _ = store.addCustomExercise(name: "Squat", tracking: .repetitions)
        store.startRest(); await store.waitForAlerts()
        let count = center.addCount
        store.adjustReps(1); store.adjustReps(1); await store.waitForAlerts()
        #expect(center.addCount == count)
    }
}
