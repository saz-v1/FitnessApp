import Foundation
import SwiftUI
import UserNotifications

/// Only user actions write the small draft. UI timer refreshes never write journal history.
@MainActor
final class WorkoutSessionStore: ObservableObject {
    @Published private(set) var session: WorkoutSession?
    @Published private(set) var errorMessage: String?
    @Published private(set) var canEdit = true
    @Published private(set) var restAlertsEnabled: Bool
    private let storageURL: URL
    private let defaults: UserDefaults
    private let schedulesAlerts: Bool
    private let alertCenter: any ReminderNotificationCenter
    private var alertTask: Task<Void, Never>?
    private var alertRevision = 0
    private var permissionRevision = 0
    private var lastAlertDeadline: Date?
    private static let alertID = "fitswift.active-workout.rest"

    init(storageURL: URL? = nil, defaults: UserDefaults = .standard, schedulesAlerts: Bool = true,
         alertCenter: (any ReminderNotificationCenter)? = nil) {
        self.defaults = defaults; self.schedulesAlerts = schedulesAlerts
        self.alertCenter = alertCenter ?? SystemReminderCenter()
        restAlertsEnabled = defaults.bool(forKey: "workoutRestAlerts")
        #if DEBUG
        if storageURL == nil && ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            self.storageURL = FileManager.default.temporaryDirectory.appendingPathComponent("FitSwiftWorkoutUITests/active-workout.json")
            if !ProcessInfo.processInfo.arguments.contains("--preserve-test-preferences") {
                try? FileManager.default.removeItem(at: self.storageURL)
            }
        } else {
            self.storageURL = storageURL ?? Self.defaultURL
        }
        #else
        self.storageURL = storageURL ?? Self.defaultURL
        #endif
        load()
        reconcileAlert(force: true)
    }
    private static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrivateFitnessData/active-workout.json")
    }
    func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let draft = try JSONDecoder().decode(WorkoutSession?.self, from: Data(contentsOf: storageURL))
            guard draft?.isValid ?? true else { throw CocoaError(.coderReadCorrupt) }
            session = draft; canEdit = true; errorMessage = nil
        } catch {
            canEdit = false
            errorMessage = "Your unfinished workout could not be read. It has been preserved. Unlock your device and try again."
        }
    }
    func retryLoading() { if !canEdit { load(); reconcileAlert(force: true) } }

    @discardableResult
    private func persist(_ candidate: WorkoutSession?) -> Bool {
        guard canEdit, candidate?.isValid ?? true else { return false }
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var protectedDirectory = directory; try protectedDirectory.setResourceValues(values)
            try JSONEncoder().encode(candidate).write(to: storageURL, options: [.atomic, .completeFileProtection])
            var protectedFile = storageURL; try protectedFile.setResourceValues(values)
            session = candidate; errorMessage = nil
            reconcileAlert()
            return true
        } catch {
            errorMessage = "The workout change could not be saved. Unlock your device and try again."
            return false
        }
    }
    @discardableResult
    private func change(_ action: (inout WorkoutSession) -> Void) -> Bool {
        guard var draft = session, draft.finishedAt == nil else { return false }
        action(&draft)
        return persist(draft)
    }
    @discardableResult
    func start(title: String, type: WorkoutRecord.WorkoutType, intensity: WorkoutRecord.Intensity, restSeconds: Int, at date: Date = Date()) -> Bool {
        guard session == nil else { return false }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return persist(WorkoutSession(title: name.isEmpty ? type.rawValue + " session" : name,
            type: type, intensity: intensity, restSeconds: restSeconds, at: date))
    }
    @discardableResult
    func addExercise(_ entry: ExerciseCatalogEntry, at date: Date = Date()) -> Bool {
        guard entry.isValid else { return false }
        return change { draft in
            for index in draft.exercises.indices { draft.exercises[index].clock.pause(at: date); draft.exercises[index].resumeAfterPause = false }
            if let existing = draft.exercises.first(where: { $0.catalogID == entry.id }) { draft.selectedExerciseID = existing.id }
            else {
                let exercise = TrackedExercise(entry: entry)
                draft.exercises.append(exercise); draft.selectedExerciseID = exercise.id
            }
        }
    }
    @discardableResult
    func addCustomExercise(name: String, tracking: ExerciseTracking, at date: Date = Date()) -> Bool {
        change { draft in
            for index in draft.exercises.indices { draft.exercises[index].clock.pause(at: date); draft.exercises[index].resumeAfterPause = false }
            let exercise = TrackedExercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines), tracking: tracking)
            draft.exercises.append(exercise); draft.selectedExerciseID = exercise.id
        }
    }
    func selectExercise(_ id: UUID, at date: Date = Date()) {
        _ = change { draft in
            for index in draft.exercises.indices { draft.exercises[index].clock.pause(at: date); draft.exercises[index].resumeAfterPause = false }
            draft.selectedExerciseID = id
        }
    }
    func removeExercise(_ id: UUID) {
        _ = change { draft in
            draft.exercises.removeAll { $0.id == id }
            if draft.selectedExerciseID == id { draft.selectedExerciseID = draft.exercises.first?.id }
        }
    }
    func adjustReps(_ amount: Int) {
        guard let draft = session, draft.clock.isRunning, let index = draft.selectedIndex,
              draft.exercises[index].tracking == .repetitions else { return }
        _ = change { $0.exercises[index].repetitions = min(10000, max(0, $0.exercises[index].repetitions + amount)) }
    }
    func setReps(_ reps: Int) {
        guard let index = session?.selectedIndex, (0...10000).contains(reps) else { return }
        _ = change { $0.exercises[index].repetitions = reps }
    }
    func setWeight(_ kg: Double?) {
        guard let index = session?.selectedIndex else { return }
        _ = change { $0.exercises[index].weightKg = kg }
    }
    func toggleExerciseTimer(at date: Date = Date()) {
        guard let draft = session, draft.clock.isRunning, let index = draft.selectedIndex else { return }
        _ = change {
            if $0.exercises[index].clock.isRunning { $0.exercises[index].clock.pause(at: date) }
            else {
                $0.hasRest = false; $0.restClock = WorkoutClock(); $0.resumeRestAfterPause = false
                $0.exercises[index].clock.start(at: date)
            }
        }
    }
    func recordLap(at date: Date = Date()) {
        guard let draft = session, draft.clock.isRunning, let index = draft.selectedIndex,
              draft.exercises[index].tracking == .laps, draft.exercises[index].clock.isRunning,
              draft.exercises[index].lapTimes.count < 1000 else { return }
        let split = draft.exercises[index].clock.elapsed(at: date) - draft.exercises[index].lapTimes.reduce(0, +)
        guard split >= 0.001 else { return }
        _ = change { $0.exercises[index].lapTimes.append(split) }
    }
    func undoLap() {
        guard let index = session?.selectedIndex, session?.exercises[index].lapTimes.isEmpty == false else { return }
        _ = change { $0.exercises[index].lapTimes.removeLast() }
    }
    @discardableResult
    func completeSet(at date: Date = Date()) -> Bool {
        guard let draft = session, let index = draft.selectedIndex,
              draft.exercises[index].pendingSet(at: date) != nil, draft.exercises[index].completedSets.count < 1000,
              draft.finishedAt == nil else { return false }
        return change {
            if $0.exercises[index].completeSet(at: date) {
                $0.restClock = WorkoutClock(); $0.hasRest = $0.restSeconds > 0
                $0.resumeRestAfterPause = !$0.clock.isRunning && $0.hasRest
                if $0.clock.isRunning && $0.hasRest { $0.restClock.start(at: date) }
            }
        }
    }
    func deleteSet(exerciseID: UUID, setID: UUID) {
        guard let index = session?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        _ = change { $0.exercises[index].completedSets.removeAll { $0.id == setID } }
    }
    func setRestSeconds(_ seconds: Int) {
        _ = change { $0.restSeconds = seconds; $0.hasRest = false; $0.restClock = WorkoutClock(); $0.resumeRestAfterPause = false }
    }
    func startRest(at date: Date = Date()) {
        guard session?.clock.isRunning == true, (session?.restSeconds ?? 0) > 0 else { return }
        _ = change { draft in
            for index in draft.exercises.indices { draft.exercises[index].clock.pause(at: date); draft.exercises[index].resumeAfterPause = false }
            draft.restClock = WorkoutClock(); draft.restClock.start(at: date); draft.hasRest = true
        }
    }
    func skipRest() { _ = change { $0.hasRest = false; $0.restClock = WorkoutClock(); $0.resumeRestAfterPause = false } }
    func togglePause(at date: Date = Date()) {
        guard let draft = session else { return }
        _ = change { if draft.clock.isRunning { $0.pause(at: date) } else { $0.resume(at: date) } }
    }
    @discardableResult
    func finish(userManager: UserManager, at date: Date = Date()) -> Bool {
        guard var draft = session else { return false }
        if draft.finishedAt == nil {
            draft.finish(at: date)
            guard persist(draft) else { return false }
        }
        guard let record = draft.record(), userManager.saveCompletedWorkout(record) else {
            errorMessage = userManager.persistenceError ?? "Your workout could not be saved. Your finished session is kept for retry."
            return false
        }
        return persist(nil)
    }
    @discardableResult
    func discard() -> Bool { persist(nil) }

    func setRestAlerts(_ enabled: Bool) async {
        guard schedulesAlerts else { return }
        permissionRevision += 1
        let revision = permissionRevision
        if enabled {
            if await alertCenter.permission() == .notRequested {
                _ = try? await alertCenter.requestPermission()
            }
            let status = await alertCenter.permission()
            guard revision == permissionRevision else { return }
            guard status.canDeliver else {
                errorMessage = "Allow FitSwift notifications in iOS Settings to receive rest alerts. The on-screen timer still works."
                return
            }
        }
        restAlertsEnabled = enabled; defaults.set(enabled, forKey: "workoutRestAlerts"); reconcileAlert(force: true)
    }

    /// Serialize requests so a stale completion cannot replace a new rest deadline.
    func reconcileAlert(force: Bool = false) {
        guard schedulesAlerts else { return }
        var deadline: Date?
        if restAlertsEnabled, let draft = session, draft.finishedAt == nil, draft.hasRest, draft.clock.isRunning,
           let started = draft.restClock.runningSince {
            deadline = started.addingTimeInterval(Double(draft.restSeconds) - draft.restClock.accumulated)
        }
        guard force || deadline != lastAlertDeadline else { return }
        lastAlertDeadline = deadline
        alertRevision += 1
        let revision = alertRevision
        let previous = alertTask
        previous?.cancel()
        alertTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let center = self.alertCenter
            center.removePending([Self.alertID])
            center.removeDelivered([Self.alertID])
            guard !Task.isCancelled, revision == self.alertRevision, self.restAlertsEnabled,
                  let draft = self.session, draft.finishedAt == nil, draft.hasRest,
                  draft.restClock.isRunning, draft.clock.isRunning else { return }
            let status = await center.permission()
            guard !Task.isCancelled, revision == self.alertRevision,
                  status.canDeliver else { return }
            let remaining = draft.restRemaining(at: Date())
            guard remaining > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "FitSwift Timer"; content.body = "Your rest timer has finished."
            if self.defaults.object(forKey: "reminderSoundEnabled") as? Bool ?? true { content.sound = .default }
            do {
                try await center.add(UNNotificationRequest(identifier: Self.alertID, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, remaining), repeats: false)))
            } catch {
                if revision == self.alertRevision { self.errorMessage = "The rest alert could not be scheduled. The on-screen timer still works." }
            }
            if Task.isCancelled || revision != self.alertRevision {
                center.removePending([Self.alertID])
            }
        }
    }
    func waitForAlerts() async { await alertTask?.value }
}
