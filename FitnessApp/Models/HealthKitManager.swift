import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let preference = HealthIntegrationPreference.shared
    /// Indicates the permission request completed, not that read access was granted.
    @Published private(set) var isAuthorized = false
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
    
    func requestAuthorization() async throws {
        let token = try preference.accessToken()
        try await requestAuthorization(token: token)
    }

    private func requestAuthorization(token: UInt) async throws {
        try preference.validate(token)
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.notAvailable }
        guard !isAuthorized else { return }
        let identifiers: [HKQuantityTypeIdentifier] = [.bodyMass, .height, .activeEnergyBurned,
            .stepCount, .heartRate, .appleStandTime, .appleExerciseTime]
        var types = Set<HKObjectType>(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        types.insert(HKObjectType.workoutType())
        try await healthStore.requestAuthorization(toShare: [], read: types)
        try preference.validate(token)
        isAuthorized = true
    }
    
    private func samples(_ type: HKSampleType, predicate: NSPredicate? = nil,
                         limit: Int = HKObjectQueryNoLimit, token: UInt) async throws -> [HKSample] {
        try preference.validate(token)
        let result: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            healthStore.execute(query)
        }
        try preference.validate(token)
        return result
    }

    private func dailySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, token: UInt) async throws -> Double {
        try preference.validate(token)
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now, options: .strictStartDate)
        let result: Double = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0) }
            }
            healthStore.execute(query)
        }
        try preference.validate(token)
        return result
    }

    func fetchLatestWeight() async {
        guard let token = try? preference.accessToken(),
              let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        do {
            if let sample = try await samples(type, limit: 1, token: token).first as? HKQuantitySample {
                let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                guard kilograms.isFinite, (1...700).contains(kilograms), sample.startDate <= Date() else { return }
                let manager = UserManager.shared
                manager.updateWeight(manager.user.usesMetric ? kilograms : kilograms / 0.45359237)
            }
        } catch is CancellationError { return
        } catch { reportError("Weight could not be read from Apple Health.", token: token) }
    }
    
    func fetchLatestHeight() async {
        guard let token = try? preference.accessToken(),
              let type = HKObjectType.quantityType(forIdentifier: .height) else { return }
        do {
            if let sample = try await samples(type, limit: 1, token: token).first as? HKQuantitySample {
                let centimeters = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                guard centimeters.isFinite, (30...300).contains(centimeters), sample.startDate <= Date() else { return }
                let manager = UserManager.shared
                manager.updateHeight(manager.user.usesMetric ? centimeters : centimeters / 2.54)
            }
        } catch is CancellationError { return
        } catch { reportError("Height could not be read from Apple Health.", token: token) }
    }
    
    func syncWorkouts() async { await fetchWorkoutHistory(monthsToFetch: 1) }
    
    func fetchWorkoutHistory(monthsToFetch: Int = 3) async {
        guard let token = try? preference.accessToken() else { return }
        do {
            try await fetchWorkoutHistory(monthsToFetch: monthsToFetch, token: token)
        } catch is CancellationError { return
        } catch { reportError("Workouts could not be read from Apple Health.", token: token) }
    }

    private func fetchWorkoutHistory(monthsToFetch: Int = 3, token: UInt) async throws {
        try preference.validate(token)
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .month, value: -max(1, min(12, monthsToFetch)), to: now) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let fetched = try await samples(HKObjectType.workoutType(), predicate: predicate, token: token)
            .compactMap { $0 as? HKWorkout }
            .filter { $0.startDate <= now && $0.duration.isFinite && (0...604800).contains($0.duration) }
        try preference.validate(token)
        let saved = UserManager.shared.syncWorkouts(fetched.map {
                WorkoutRecord(id: $0.uuid, date: $0.startDate, type: mapWorkoutType($0.workoutActivityType),
                    duration: $0.duration, intensity: .moderate)
            })
        workouts = fetched
        if !saved { errorMessage = "Imported workouts could not be saved. Unlock your device and try again." }
    }
    
    func fetchTodaysHealthData() async {
        guard let token = try? preference.accessToken() else { return }
        do {
            guard refreshToken == nil else { return }
            refreshToken = token
            defer { if refreshToken == token { refreshToken = nil } }
            errorMessage = nil
            try await requestAuthorization(token: token)
            // Reset before refreshing so revoked access or empty queries do not show stale data.
            clearReadings()
            // Independent statistics queries run together rather than serially delaying the screen.
            async let stepCount = dailySum(.stepCount, unit: .count(), token: token)
            async let energy = dailySum(.activeEnergyBurned, unit: .kilocalorie(), token: token)
            async let stand = dailySum(.appleStandTime, unit: .hour(), token: token)
            async let exercise = dailySum(.appleExerciseTime, unit: .minute(), token: token)
            let (count, active, standing, exercising) = try await (stepCount, energy, stand, exercise)
            try preference.validate(token)
            steps = Int(Self.sanitizedValue(count, maximum: 1_000_000))
            activeEnergy = Self.sanitizedValue(active, maximum: 100_000)
            standHours = Self.sanitizedValue(standing, maximum: 24)
            exerciseMinutes = Self.sanitizedValue(exercising, maximum: 1440)
            if let type = HKObjectType.quantityType(forIdentifier: .heartRate),
               let sample = try await samples(type, limit: 1, token: token).first as? HKQuantitySample,
               sample.startDate <= Date() {
                heartRate = Self.sanitizedValue(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())), maximum: 500)
                heartRateTimestamp = heartRate > 0 ? sample.startDate : nil
            }
            if let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                let now = Date()
                let cutoff = now.addingTimeInterval(-86400)
                let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: now, options: [])
                let sleep = try await samples(type, predicate: predicate, token: token).compactMap { $0 as? HKCategorySample }
                let asleepValues = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue])
                let intervals = sleep.filter { asleepValues.contains($0.value) }
                    .map { (max(cutoff, $0.startDate), min(now, $0.endDate)) }
                    .filter { $0.0 < $0.1 }.sorted { $0.0 < $1.0 }
                var end = cutoff
                for interval in intervals {
                    let start = max(end, interval.0)
                    if interval.1 > start { sleepHours += interval.1.timeIntervalSince(start) / 3600 }
                    end = max(end, interval.1)
                }
            }
            try await fetchWorkoutHistory(token: token)
        } catch is CancellationError { return
        } catch { reportError("Apple Health data could not be loaded. You can continue logging manually.", token: token) }
    }

    /// Called as soon as Apple Health is disconnected; completed queries cannot restore this snapshot.
    func disconnect() {
        preference.invalidate()
        refreshToken = nil
        isAuthorized = false
        clearReadings()
        workouts = []
        errorMessage = nil
    }

    private func clearReadings() {
        steps = 0; activeEnergy = 0; heartRate = 0; heartRateTimestamp = nil
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
