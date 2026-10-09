import Foundation
import HealthKit
import Combine

enum HealthReading: String, CaseIterable {
    case steps = "steps", activeEnergy = "active energy", standTime = "stand time"
    case exerciseTime = "exercise time", heartRate = "heart rate", sleep = "sleep", workouts = "workouts"
}

private struct HealthRead<Value> {
    let value: Value
    var failed = false
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let reader: any HealthKitReading
    private let preference: HealthIntegrationPreference
    private let userManager: UserManager
    private let now: () -> Date
    private let calendar: Calendar
    /// Indicates the permission request completed, not that read access was granted.
    @Published private(set) var isAuthorized = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var availableReadings: Set<HealthReading> = []
    @Published private(set) var steps = 0
    @Published private(set) var activeEnergy: Double = 0
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var heartRateTimestamp: Date?
    @Published private(set) var sleepHours: Double = 0
    @Published private(set) var standHours: Double = 0
    @Published private(set) var exerciseMinutes: Double = 0
    @Published private(set) var workouts: [HKWorkout] = []
    @Published private(set) var errorMessage: String?
    private var refreshToken: UInt?

    init(reader: (any HealthKitReading)? = nil, preference: HealthIntegrationPreference? = nil,
         userManager: UserManager? = nil, now: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent) {
        self.reader = reader ?? SystemHealthKitReader(); self.preference = preference ?? .shared
        self.userManager = userManager ?? .shared; self.now = now; self.calendar = calendar
    }

    func requestAuthorization() async throws {
        let token = try preference.accessToken()
        try await requestAuthorization(token: token)
    }

    private func requestAuthorization(token: UInt) async throws {
        try preference.validate(token)
        guard reader.isAvailable else { throw HealthKitError.notAvailable }
        guard !isAuthorized else { return }
        let identifiers: [HKQuantityTypeIdentifier] = [.bodyMass, .height, .activeEnergyBurned,
            .stepCount, .heartRate, .appleStandTime, .appleExerciseTime]
        var types = Set<HKObjectType>(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        types.insert(HKObjectType.workoutType())
        try await reader.requestAuthorization(read: types)
        try preference.validate(token)
        isAuthorized = true
    }

    private func samples(_ type: HKSampleType, from start: Date? = nil, to end: Date,
                         options: HKQueryOptions = .strictEndDate, limit: Int = HKObjectQueryNoLimit,
                         token: UInt) async throws -> [HKSample] {
        try preference.validate(token)
        let result = try await reader.samples(type, from: start, to: end, options: options, limit: limit)
        try preference.validate(token)
        return result
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, maximum: Double,
                     at date: Date, token: UInt) async throws -> Double? {
        try preference.validate(token)
        let value = try await reader.dailySum(identifier, unit: unit,
            from: calendar.startOfDay(for: date), to: date, calendar: calendar)
        try preference.validate(token)
        guard let value else { return nil }
        guard value.isFinite, (0...maximum).contains(value) else { throw HealthKitError.fetchFailed }
        return value
    }

    /// An empty or denied category must never cancel unrelated successful queries.
    private func read<Value>(empty: Value, operation: () async throws -> Value) async -> HealthRead<Value> {
        do { return HealthRead(value: try await operation()) }
        catch { return HealthRead(value: empty, failed: !HealthKitReadError.isNoData(error) && !(error is CancellationError)) }
    }

    func fetchLatestWeight() async {
        guard let token = try? preference.accessToken(),
              let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        do {
            try await requestAuthorization(token: token)
            if let sample = try await samples(type, to: now(), limit: 1, token: token).first as? HKQuantitySample {
                let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                guard kilograms.isFinite, (1...700).contains(kilograms) else { return }
                if !userManager.syncWeights([WeightRecord(id: sample.uuid, weight: kilograms, date: sample.startDate)]) {
                    reportError("Imported weight could not be saved. Unlock your device and try again.", token: token)
                }
            }
        } catch is CancellationError { return
        } catch { if !HealthKitReadError.isNoData(error) { reportError("Weight could not be read from Apple Health.", token: token) } }
    }

    func fetchLatestHeight() async {
        guard let token = try? preference.accessToken(),
              let type = HKObjectType.quantityType(forIdentifier: .height) else { return }
        do {
            try await requestAuthorization(token: token)
            if let sample = try await samples(type, to: now(), limit: 1, token: token).first as? HKQuantitySample {
                let centimeters = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                guard centimeters.isFinite, (30...300).contains(centimeters) else { return }
                let height = userManager.user.usesMetric ? centimeters : centimeters / 2.54
                if height != userManager.user.height { userManager.updateHeight(height) }
            }
        } catch is CancellationError { return
        } catch { if !HealthKitReadError.isNoData(error) { reportError("Height could not be read from Apple Health.", token: token) } }
    }

    func syncWorkouts() async { await fetchWorkoutHistory(monthsToFetch: 1) }

    private func readWorkouts(months: Int, at date: Date, token: UInt) async throws -> [HKWorkout] {
        guard let start = calendar.date(byAdding: .month, value: -max(1, min(12, months)), to: date) else { return [] }
        return try await samples(HKObjectType.workoutType(), from: start, to: date,
            options: [.strictStartDate, .strictEndDate], token: token).compactMap { $0 as? HKWorkout }
            .filter { $0.startDate <= date && $0.endDate <= date && $0.duration.isFinite && (0...604800).contains($0.duration) }
    }

    func fetchWorkoutHistory(monthsToFetch: Int = 3) async {
        guard let token = try? preference.accessToken() else { return }
        do {
            try await requestAuthorization(token: token)
            let fetched = try await readWorkouts(months: monthsToFetch, at: now(), token: token)
            try preference.validate(token)
            workouts = fetched
            if !saveWorkouts(fetched) { reportError("Imported workouts could not be saved. Unlock your device and try again.", token: token) }
        } catch is CancellationError { return
        } catch { if !HealthKitReadError.isNoData(error) { reportError("Workouts could not be read from Apple Health.", token: token) } }
    }

    private func saveWorkouts(_ fetched: [HKWorkout]) -> Bool {
        userManager.syncWorkouts(fetched.map { workout in
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let calories = energy.flatMap { $0.isFinite && (0...100000).contains($0) ? Int($0) : nil }
            return WorkoutRecord(id: workout.uuid, date: workout.startDate, type: mapWorkoutType(workout.workoutActivityType),
                duration: workout.duration, intensity: .moderate, caloriesBurned: calories)
        })
    }

    func fetchTodaysHealthData() async {
        guard let token = try? preference.accessToken(), refreshToken == nil else { return }
        refreshToken = token; isRefreshing = true
        defer { if refreshToken == token { refreshToken = nil; isRefreshing = false } }
        do {
            errorMessage = nil
            try await requestAuthorization(token: token)
            let date = now()
            async let count = read(empty: Optional<Double>.none) { try await sum(.stepCount, unit: .count(), maximum: 1_000_000, at: date, token: token) }
            async let energy = read(empty: Optional<Double>.none) { try await sum(.activeEnergyBurned, unit: .kilocalorie(), maximum: 100_000, at: date, token: token) }
            async let stand = read(empty: Optional<Double>.none) { try await sum(.appleStandTime, unit: .hour(), maximum: 24, at: date, token: token) }
            async let exercise = read(empty: Optional<Double>.none) { try await sum(.appleExerciseTime, unit: .minute(), maximum: 1440, at: date, token: token) }
            async let heart = read(empty: [HKSample]()) { try await samples(HKQuantityType(.heartRate), to: date, limit: 1, token: token) }
            async let sleep = read(empty: [HKSample]()) { try await samples(HKCategoryType(.sleepAnalysis), from: date.addingTimeInterval(-86400), to: date, options: [], token: token) }
            async let activity = read(empty: [HKWorkout]()) { try await readWorkouts(months: 3, at: date, token: token) }
            let (stepResult, energyResult, standResult, exerciseResult, heartResult, sleepResult, workoutResult) =
                await (count, energy, stand, exercise, heart, sleep, activity)
            try preference.validate(token)
            clearReadings()
            steps = Int(stepResult.value ?? 0); activeEnergy = energyResult.value ?? 0
            standHours = standResult.value ?? 0; exerciseMinutes = exerciseResult.value ?? 0
            if stepResult.value != nil { availableReadings.insert(.steps) }
            if energyResult.value != nil { availableReadings.insert(.activeEnergy) }
            if standResult.value != nil { availableReadings.insert(.standTime) }
            if exerciseResult.value != nil { availableReadings.insert(.exerciseTime) }
            if let sample = heartResult.value.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                if value.isFinite, (1...500).contains(value), sample.startDate <= date {
                    heartRate = value; heartRateTimestamp = sample.startDate; availableReadings.insert(.heartRate)
                }
            }
            let sleepSamples = sleepResult.value.compactMap { $0 as? HKCategorySample }
            if !sleepSamples.isEmpty {
                sleepHours = Self.asleepHours(sleepSamples, from: date.addingTimeInterval(-86400), to: date)
                availableReadings.insert(.sleep)
            }
            workouts = workoutResult.value
            if !workouts.isEmpty { availableReadings.insert(.workouts) }
            var failures: [HealthReading] = []
            if stepResult.failed { failures.append(.steps) }; if energyResult.failed { failures.append(.activeEnergy) }
            if standResult.failed { failures.append(.standTime) }; if exerciseResult.failed { failures.append(.exerciseTime) }
            if heartResult.failed { failures.append(.heartRate) }; if sleepResult.failed { failures.append(.sleep) }
            if workoutResult.failed { failures.append(.workouts) }
            let saved = workoutResult.failed ? true : saveWorkouts(workouts)
            if !saved { errorMessage = "Imported workouts could not be saved. Unlock your device and try again." }
            else if !failures.isEmpty { errorMessage = "Could not refresh \(failures.map(\.rawValue).joined(separator: ", ")). Other available readings are shown. Unlock your device and refresh." }
            lastRefreshDate = date
        } catch is CancellationError { return
        } catch {
            guard (try? preference.validate(token)) != nil else { return }
            clearReadings(); workouts = []; lastRefreshDate = nil
            reportError(reader.isAvailable ? "Apple Health could not be opened. Check FitSwift's access in Apple Health and try again." : "Apple Health is unavailable on this device.", token: token)
        }
    }

    /// Union sleep stages/sources, clip the window and exclude in-bed/awake samples.
    static func asleepHours(_ samples: [HKCategorySample], from cutoff: Date, to endDate: Date) -> Double {
        let asleep = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue])
        var intervals: [(start: Date, end: Date)] = []
        for sample in samples where asleep.contains(sample.value) {
            let start = max(cutoff, sample.startDate)
            let end = min(endDate, sample.endDate)
            if start < end { intervals.append((start, end)) }
        }
        intervals.sort { $0.start < $1.start }
        var end = cutoff, duration = 0.0
        for interval in intervals {
            duration += max(0, interval.end.timeIntervalSince(max(end, interval.start)))
            end = max(end, interval.end)
        }
        return duration / 3600
    }

    func disconnect() {
        preference.invalidate(); refreshToken = nil; isRefreshing = false; isAuthorized = false
        clearReadings(); workouts = []; lastRefreshDate = nil; errorMessage = nil
    }

    private func clearReadings() {
        availableReadings = []; steps = 0; activeEnergy = 0; heartRate = 0; heartRateTimestamp = nil
        sleepHours = 0; standHours = 0; exerciseMinutes = 0
    }

    private func reportError(_ message: String, token: UInt) {
        guard (try? preference.validate(token)) != nil else { return }
        errorMessage = message
    }

    static func sanitizedValue(_ value: Double, maximum: Double) -> Double {
        value.isFinite && (0...maximum).contains(value) ? value : 0
    }

    private func mapWorkoutType(_ type: HKWorkoutActivityType) -> WorkoutRecord.WorkoutType {
        switch type {
        case .running, .walking, .cycling, .swimming, .hiking: return .cardio
        case .functionalStrengthTraining, .traditionalStrengthTraining: return .strength
        case .yoga: return .yoga
        case .flexibility: return .flexibility
        case .highIntensityIntervalTraining: return .hiit
        default: return .other
        }
    }
}
