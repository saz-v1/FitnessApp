import Foundation

struct CompletedWorkoutSet: Codable, Equatable, Identifiable {
    let id: UUID
    let repetitions: Int?
    let weightKg: Double?
    let duration: TimeInterval?
    let lapTimes: [TimeInterval]?
    var isValid: Bool {
        (repetitions.map { (1...10000).contains($0) } ?? true) &&
        (weightKg.map { $0.isFinite && (0...2000).contains($0) } ?? true) &&
        (duration.map { $0.isFinite && (0.001...604800).contains($0) } ?? true) &&
        (lapTimes.map { $0.count <= 1000 && $0.allSatisfy { $0.isFinite && (0.001...604800).contains($0) } } ?? true) &&
        (repetitions != nil || duration != nil) &&
        (lapTimes.map { times in duration.map { times.reduce(0, +) <= $0 + 0.001 } ?? false } ?? true)
    }
    init(id: UUID = UUID(), repetitions: Int? = nil, weightKg: Double? = nil,
         duration: TimeInterval? = nil, lapTimes: [TimeInterval]? = nil) {
        self.id = id; self.repetitions = repetitions; self.weightKg = weightKg
        self.duration = duration; self.lapTimes = lapTimes
    }
}

/// No ticking counter: timestamps survive suspension and relaunch, and pause excludes elapsed time.
struct WorkoutClock: Codable, Equatable {
    private(set) var accumulated: TimeInterval = 0
    private(set) var runningSince: Date?
    var isRunning: Bool { runningSince != nil }
    func elapsed(at date: Date) -> TimeInterval {
        min(604800, max(0, accumulated + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)))
    }
    mutating func start(at date: Date) { if runningSince == nil { runningSince = date } }
    mutating func pause(at date: Date) { accumulated = elapsed(at: date); runningSince = nil }
    var isValid: Bool { accumulated.isFinite && (0...604800).contains(accumulated) && (runningSince.map { $0.timeIntervalSince1970.isFinite } ?? true) }
}

struct TrackedExercise: Codable, Equatable, Identifiable {
    let id: UUID
    let catalogID: String?
    let name: String
    let tracking: ExerciseTracking
    var completedSets: [CompletedWorkoutSet] = []
    var repetitions = 0
    var weightKg: Double?
    var clock = WorkoutClock()
    var lapTimes: [TimeInterval] = []
    var resumeAfterPause = false

    init(id: UUID = UUID(), entry: ExerciseCatalogEntry) {
        self.id = id; catalogID = entry.id; name = entry.name; tracking = entry.tracking
    }
    init(id: UUID = UUID(), name: String, tracking: ExerciseTracking) {
        self.id = id; catalogID = nil; self.name = name; self.tracking = tracking
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 &&
        (0...10000).contains(repetitions) && (weightKg.map { $0.isFinite && (0...2000).contains($0) } ?? true) &&
        clock.isValid && completedSets.count <= 1000 && completedSets.allSatisfy(\.isValid) &&
        Set(completedSets.map(\.id)).count == completedSets.count && lapTimes.count <= 1000 &&
        lapTimes.allSatisfy { $0.isFinite && (0.001...604800).contains($0) }
    }
    func pendingSet(at date: Date) -> CompletedWorkoutSet? {
        let seconds = clock.elapsed(at: date)
        if tracking == .repetitions && repetitions == 0 { return nil }
        if tracking != .repetitions && seconds < 0.001 { return nil }
        return CompletedWorkoutSet(repetitions: tracking == .repetitions ? repetitions : nil, weightKg: weightKg,
            duration: seconds > 0 ? seconds : nil, lapTimes: lapTimes.isEmpty ? nil : lapTimes)
    }
    mutating func completeSet(at date: Date) -> Bool {
        guard completedSets.count < 1000, let set = pendingSet(at: date), set.isValid else { return false }
        completedSets.append(set); repetitions = 0; clock = WorkoutClock(); lapTimes = []; resumeAfterPause = false
        return true
    }
    func record() -> WorkoutRecord.Exercise? {
        guard !completedSets.isEmpty else { return nil }
        let reps = completedSets.compactMap(\.repetitions)
        return WorkoutRecord.Exercise(id: id, name: name, sets: completedSets.count,
            reps: reps.count == completedSets.count && Set(reps).count == 1 ? reps.first : nil,
            duration: completedSets.compactMap(\.duration).isEmpty ? nil : completedSets.compactMap(\.duration).reduce(0, +),
            catalogID: catalogID, completedSets: completedSets)
    }
}

struct WorkoutSession: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    var title: String
    let type: WorkoutRecord.WorkoutType
    let intensity: WorkoutRecord.Intensity
    var clock = WorkoutClock()
    var exercises: [TrackedExercise] = []
    var selectedExerciseID: UUID?
    var restSeconds = 60
    var restClock = WorkoutClock()
    var hasRest = false
    var resumeRestAfterPause = false
    var finishedAt: Date?
    var selectedIndex: Int? { exercises.firstIndex { $0.id == selectedExerciseID } }
    var isValid: Bool {
        !title.isEmpty && title.count <= 120 && startedAt.timeIntervalSince1970.isFinite && clock.isValid && restClock.isValid &&
        (0...3600).contains(restSeconds) && exercises.count <= 100 && exercises.allSatisfy(\.isValid) &&
        Set(exercises.map(\.id)).count == exercises.count && (selectedExerciseID == nil || selectedIndex != nil) &&
        (finishedAt.map { $0 >= startedAt && !$0.timeIntervalSince1970.isNaN && !clock.isRunning } ?? true)
    }
    init(id: UUID = UUID(), title: String, type: WorkoutRecord.WorkoutType, intensity: WorkoutRecord.Intensity,
         restSeconds: Int = 60, at date: Date = Date()) {
        self.id = id; startedAt = date; self.title = title; self.type = type; self.intensity = intensity
        self.restSeconds = restSeconds; clock.start(at: date)
    }
    func restRemaining(at date: Date) -> TimeInterval { max(0, Double(restSeconds) - restClock.elapsed(at: date)) }
    mutating func pause(at date: Date) {
        clock.pause(at: date)
        for index in exercises.indices {
            exercises[index].resumeAfterPause = exercises[index].clock.isRunning
            exercises[index].clock.pause(at: date)
        }
        resumeRestAfterPause = hasRest && restClock.isRunning && restRemaining(at: date) > 0
        restClock.pause(at: date)
    }
    mutating func resume(at date: Date) {
        guard finishedAt == nil else { return }
        clock.start(at: date)
        for index in exercises.indices where exercises[index].resumeAfterPause {
            exercises[index].clock.start(at: date); exercises[index].resumeAfterPause = false
        }
        if resumeRestAfterPause { restClock.start(at: date); resumeRestAfterPause = false }
    }
    mutating func finish(at date: Date) {
        guard finishedAt == nil else { return }
        for index in exercises.indices { _ = exercises[index].completeSet(at: date) }
        pause(at: date); finishedAt = max(date, startedAt)
    }
    func record() -> WorkoutRecord? {
        guard let finishedAt else { return nil }
        let results = exercises.compactMap { $0.record() }
        return WorkoutRecord(id: id, date: startedAt, type: type, duration: clock.elapsed(at: finishedAt), intensity: intensity,
            exercises: results.isEmpty ? nil : results, notes: title)
    }
}

extension TimeInterval {
    var timerText: String {
        let seconds = Int(min(604800, max(0, isFinite ? self : 0)))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
