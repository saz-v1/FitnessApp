import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct WorkoutSessionTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private func url() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("active.json") }
    private func store(_ url: URL) -> WorkoutSessionStore {
        WorkoutSessionStore(storageURL: url, defaults: UserDefaults(suiteName: UUID().uuidString)!, schedulesAlerts: false)
    }
    private func userManager() -> UserManager {
        UserManager(storageURL: url(), defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }
    @Test func clockUsesTimestampsAndExcludesPausedTime() throws {
        var clock = WorkoutClock(); clock.start(at: date)
        clock.start(at: date.addingTimeInterval(10))
        #expect(clock.elapsed(at: date.addingTimeInterval(30)) == 30)
        clock.pause(at: date.addingTimeInterval(30))
        #expect(clock.elapsed(at: date.addingTimeInterval(100)) == 30)
        let restored = try JSONDecoder().decode(WorkoutClock.self, from: JSONEncoder().encode(clock))
        #expect(restored == clock)
        clock.start(at: date.addingTimeInterval(100))
        #expect(clock.elapsed(at: date.addingTimeInterval(120)) == 50)
        #expect(clock.elapsed(at: date.addingTimeInterval(90)) == 30)
    }
    @Test func repSetsKeepIndividualCountsAndCanonicalWeights() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        #expect(store.start(title: "Leg day", type: .strength, intensity: .moderate, restSeconds: 60, at: date))
        #expect(store.addCustomExercise(name: "Squat", tracking: .repetitions, at: date))
        #expect(!store.completeSet(at: date))
        store.setReps(10); store.setWeight(50)
        #expect(store.completeSet(at: date.addingTimeInterval(10)))
        store.setReps(8); store.setWeight(55)
        #expect(store.completeSet(at: date.addingTimeInterval(20)))
        let sets = try #require(store.session?.exercises.first?.completedSets)
        #expect(sets.map(\.repetitions) == [10, 8])
        #expect(sets.map(\.weightKg) == [50, 55])
        let manager = userManager(); manager.toggleUnits()
        #expect(store.finish(userManager: manager, at: date.addingTimeInterval(30)))
        let exercise = try #require(manager.user.workoutHistory.first?.exercises?.first)
        #expect(exercise.reps == nil) // A varying set must not be shown as 2 × 10.
        #expect(exercise.completedSets == sets)
        #expect(store.session == nil)
    }
    @Test func pauseFreezesRestAndResumeKeepsRemainingDuration() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Session", type: .strength, intensity: .moderate, restSeconds: 60, at: date)
        _ = store.addCustomExercise(name: "Squat", tracking: .repetitions, at: date)
        store.setReps(5); _ = store.completeSet(at: date.addingTimeInterval(3))
        store.togglePause(at: date.addingTimeInterval(13))
        #expect(store.session?.restRemaining(at: date.addingTimeInterval(43)) == 50)
        store.adjustReps(1)
        #expect(store.session?.exercises.first?.repetitions == 0)
        store.togglePause(at: date.addingTimeInterval(43))
        #expect(store.session?.restRemaining(at: date.addingTimeInterval(63)) == 30)
        #expect(store.session?.clock.elapsed(at: date.addingTimeInterval(63)) == 33)
    }
    @Test func lapSplitsUndoAndFinishRetainExactTimes() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Run", type: .cardio, intensity: .moderate, restSeconds: 0, at: date)
        _ = store.addCustomExercise(name: "Running", tracking: .laps, at: date)
        store.toggleExerciseTimer(at: date.addingTimeInterval(10))
        store.recordLap(at: date.addingTimeInterval(20))
        store.recordLap(at: date.addingTimeInterval(30)); store.undoLap()
        store.recordLap(at: date.addingTimeInterval(35))
        let manager = userManager()
        #expect(store.finish(userManager: manager, at: date.addingTimeInterval(40)))
        let set = try #require(manager.user.workoutHistory.first?.exercises?.first?.completedSets?.first)
        #expect(set.lapTimes == [10, 15])
        #expect(set.duration == 30)
    }
    @Test func sessionReloadPreservesActiveTimerAndDraftCounts() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Workout", type: .strength, intensity: .moderate, restSeconds: 90, at: date)
        _ = store.addCustomExercise(name: "Press", tracking: .repetitions, at: date)
        store.setReps(12)
        let restored = self.store(url)
        #expect(restored.session == store.session)
        #expect(restored.session?.clock.elapsed(at: date.addingTimeInterval(60)) == 60)
        #expect(restored.session?.exercises.first?.repetitions == 12)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
    @Test func failedJournalSaveKeepsFinishedDraftForRetry() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Workout", type: .cardio, intensity: .moderate, restSeconds: 0, at: date)
        let blocker = self.url(); try FileManager.default.createDirectory(at: blocker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("block".utf8).write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker.deletingLastPathComponent()) }
        let blocked = UserManager(storageURL: blocker.appendingPathComponent("user.json"))
        #expect(!store.finish(userManager: blocked, at: date.addingTimeInterval(10)))
        #expect(store.session?.finishedAt == date.addingTimeInterval(10))
        #expect(store.session?.clock.isRunning == false)
        let manager = userManager()
        #expect(store.finish(userManager: manager, at: date.addingTimeInterval(30)))
        #expect(manager.user.workoutHistory.first?.duration == 10)
    }
    @Test func recoveredAlreadySavedSessionDoesNotDuplicateWorkout() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Run", type: .cardio, intensity: .moderate, restSeconds: 0, at: date)
        var draft = try #require(store.session); draft.finish(at: date.addingTimeInterval(10))
        let manager = userManager()
        #expect(manager.saveCompletedWorkout(try #require(draft.record())))
        try JSONEncoder().encode(draft).write(to: url)
        let restored = self.store(url)
        #expect(restored.finish(userManager: manager, at: date.addingTimeInterval(50)))
        #expect(manager.user.workoutHistory.count == 1)
        #expect(manager.user.workoutHistory.first?.duration == 10)
    }
    @Test func corruptDraftIsPreservedAndBlocksReplacement() throws {
        let url = url(); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let data = Data("broken".utf8); try data.write(to: url)
        let store = store(url)
        #expect(!store.canEdit)
        #expect(!store.start(title: "New", type: .cardio, intensity: .moderate, restSeconds: 60))
        #expect(!store.discard())
        #expect(try Data(contentsOf: url) == data)
    }
    @Test func failedDraftWriteDoesNotPublishSession() throws {
        let blocker = url(); try FileManager.default.createDirectory(at: blocker.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: blocker.deletingLastPathComponent()) }
        try Data("block".utf8).write(to: blocker)
        let store = store(blocker.appendingPathComponent("draft.json"))
        #expect(!store.start(title: "Workout", type: .cardio, intensity: .moderate, restSeconds: 0))
        #expect(store.session == nil)
        #expect(store.errorMessage != nil)
    }
    @Test func switchingExercisesKeepsPendingCountsAndStopsInterval() throws {
        let url = url(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = store(url)
        _ = store.start(title: "Mixed", type: .other, intensity: .moderate, restSeconds: 60, at: date)
        _ = store.addCustomExercise(name: "Plank", tracking: .timed, at: date)
        let first = try #require(store.session?.selectedExerciseID)
        store.toggleExerciseTimer(at: date)
        _ = store.addCustomExercise(name: "Squat", tracking: .repetitions, at: date.addingTimeInterval(30))
        store.setReps(10)
        store.selectExercise(first, at: date.addingTimeInterval(40))
        #expect(store.session?.exercises.first?.clock.accumulated == 30)
        #expect(store.session?.exercises.first?.clock.isRunning == false)
        #expect(store.session?.exercises.last?.repetitions == 10)
    }
}
