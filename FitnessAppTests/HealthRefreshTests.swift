import Foundation
import HealthKit
import Testing
@testable import FitnessApp

@MainActor
private final class HealthReaderDouble: HealthKitReading {
    var isAvailable = true
    var authorizationCalls = 0
    var sumCalls: [(HKQuantityTypeIdentifier, Date, Date)] = []
    var sampleCalls: [(String, Date?, Date, HKQueryOptions, Int)] = []
    var values: [HKQuantityTypeIdentifier: Double] = [:]
    var errors: [HKQuantityTypeIdentifier: Error] = [:]
    var sampleValues: [String: [HKSample]] = [:]
    var suspendNextStep = false
    var stepStarted: (() -> Void)?
    var suspendedStep: CheckedContinuation<Double?, Error>?

    func requestAuthorization(read: Set<HKObjectType>) async throws { authorizationCalls += 1 }

    func dailySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date,
                  to end: Date, calendar: Calendar) async throws -> Double? {
        sumCalls.append((identifier, start, end))
        if identifier == .stepCount && suspendNextStep {
            suspendNextStep = false
            return try await withCheckedThrowingContinuation { continuation in
                suspendedStep = continuation
                stepStarted?()
            }
        }
        if let error = errors[identifier] { throw error }
        return values[identifier]
    }

    func samples(_ type: HKSampleType, from start: Date?, to end: Date,
                 options: HKQueryOptions, limit: Int) async throws -> [HKSample] {
        sampleCalls.append((type.identifier, start, end, options, limit))
        return sampleValues[type.identifier] ?? []
    }
}

@MainActor
struct HealthRefreshTests {
    private func setup(reader: HealthReaderDouble, enabled: Bool = true, now: Date = Date(),
                       calendar: Calendar = .current) -> (HealthKitManager, UserManager, UserDefaults, URL) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(enabled, forKey: "healthIntegrationEnabled")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let user = UserManager(storageURL: directory.appendingPathComponent("user.json"), defaults: defaults)
        let health = HealthKitManager(reader: reader, preference: HealthIntegrationPreference(defaults: defaults),
            userManager: user, now: { now }, calendar: calendar)
        return (health, user, defaults, directory)
    }

    @Test func missingWatchDataDoesNotDiscardStepsEnergyOrWorkouts() async {
        let reader = HealthReaderDouble(), now = Date()
        reader.values = [.stepCount: 5321, .activeEnergyBurned: 210.5]
        let noData = NSError(domain: HKErrorDomain, code: HKError.errorNoData.rawValue)
        reader.errors = [.appleStandTime: noData, .appleExerciseTime: noData]
        let workout = HKWorkout(activityType: .walking, start: now.addingTimeInterval(-1800),
            end: now.addingTimeInterval(-600))
        reader.sampleValues[HKObjectType.workoutType().identifier] = [workout]
        let (health, user, _, directory) = setup(reader: reader, now: now)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchTodaysHealthData()
        #expect(health.steps == 5321 && health.activeEnergy == 210.5)
        #expect(health.availableReadings == [.steps, .activeEnergy, .workouts])
        #expect(health.errorMessage == nil && !health.isRefreshing)
        #expect(user.user.workoutHistory.first?.id == workout.uuid)
        #expect(user.user.workoutHistory.first?.duration == 1200)
        await health.fetchTodaysHealthData()
        #expect(user.user.workoutHistory.count == 1)
        #expect(reader.authorizationCalls == 1)
    }

    @Test func failingCategoryKeepsSuccessfulReadingsAndFractionalStandTime() async {
        let reader = HealthReaderDouble(), now = Date()
        reader.errors[.appleExerciseTime] = NSError(domain: HKErrorDomain, code: HKError.errorDatabaseInaccessible.rawValue)
        reader.values = [.stepCount: 8000, .activeEnergyBurned: 300, .appleStandTime: 0.25]
        let heart = HKQuantitySample(type: HKQuantityType(.heartRate),
            quantity: HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: 72),
            start: now.addingTimeInterval(-60), end: now.addingTimeInterval(-60))
        reader.sampleValues[heart.sampleType.identifier] = [heart]
        let (health, _, _, directory) = setup(reader: reader, now: now)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchTodaysHealthData()
        #expect(health.steps == 8000 && health.heartRate == 72)
        #expect(health.standHours == 0.25)
        #expect(health.heartRateTimestamp == heart.startDate)
        #expect(health.availableReadings.contains(.steps) && !health.availableReadings.contains(.exerciseTime))
        #expect(health.errorMessage?.contains("exercise time") == true)
        #expect(health.lastRefreshDate == now)
    }

    @Test func noSharedDataIsDifferentFromAnActualZeroAndClearsOldReadings() async {
        let reader = HealthReaderDouble()
        reader.values[.stepCount] = 0
        let (health, _, _, directory) = setup(reader: reader)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchTodaysHealthData()
        #expect(health.availableReadings.contains(.steps) && health.steps == 0)
        #expect(!health.availableReadings.contains(.activeEnergy))
        reader.values[.stepCount] = 1234
        await health.fetchTodaysHealthData()
        #expect(health.steps == 1234)
        reader.values.removeAll()
        await health.fetchTodaysHealthData()
        #expect(health.steps == 0 && health.availableReadings.isEmpty)
        #expect(health.errorMessage == nil)
    }

    @Test func disconnectAndReconnectCannotApplyAnOldDelayedRefresh() async {
        let reader = HealthReaderDouble()
        reader.suspendNextStep = true
        let (started, continuation) = AsyncStream<Void>.makeStream()
        reader.stepStarted = { continuation.yield(()) }
        let (health, _, defaults, directory) = setup(reader: reader)
        defer { continuation.finish(); try? FileManager.default.removeItem(at: directory) }
        let oldRefresh = Task { await health.fetchTodaysHealthData() }
        for await _ in started { break }
        defaults.set(false, forKey: "healthIntegrationEnabled")
        health.disconnect()
        #expect(!health.isRefreshing && health.availableReadings.isEmpty)
        defaults.set(true, forKey: "healthIntegrationEnabled")
        reader.values[.stepCount] = 9000
        await health.fetchTodaysHealthData()
        reader.suspendedStep?.resume(returning: 100)
        reader.suspendedStep = nil
        await oldRefresh.value
        #expect(health.steps == 9000 && health.availableReadings.contains(.steps))
        #expect(health.errorMessage == nil && !health.isRefreshing)
    }

    @Test func connectionDisabledAndUnavailableDeviceNeverRunQueries() async {
        let disabled = HealthReaderDouble()
        let (health, _, _, firstDirectory) = setup(reader: disabled, enabled: false)
        defer { try? FileManager.default.removeItem(at: firstDirectory) }
        await health.fetchTodaysHealthData()
        #expect(disabled.authorizationCalls == 0 && disabled.sumCalls.isEmpty && disabled.sampleCalls.isEmpty)
        let unavailable = HealthReaderDouble(); unavailable.isAvailable = false
        let (other, _, _, secondDirectory) = setup(reader: unavailable)
        defer { try? FileManager.default.removeItem(at: secondDirectory) }
        await other.fetchTodaysHealthData()
        #expect(other.errorMessage == "Apple Health is unavailable on this device.")
        #expect(unavailable.authorizationCalls == 0 && unavailable.sumCalls.isEmpty)
    }

    @Test func invalidQuantityDoesNotCrashOrHideAnotherCategory() async {
        let reader = HealthReaderDouble()
        reader.values = [.stepCount: .nan, .activeEnergyBurned: 123]
        let (health, _, _, directory) = setup(reader: reader)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchTodaysHealthData()
        #expect(!health.availableReadings.contains(.steps))
        #expect(health.availableReadings.contains(.activeEnergy) && health.activeEnergy == 123)
        #expect(health.errorMessage?.contains("steps") == true)
    }

    @Test func queriesShareCalendarDayAndExcludeFutureLatestSamples() async {
        let reader = HealthReaderDouble()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let now = calendar.date(from: DateComponents(year: 2025, month: 3, day: 30, hour: 8))!
        let (health, _, _, directory) = setup(reader: reader, now: now, calendar: calendar)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchTodaysHealthData()
        #expect(reader.sumCalls.count == 4)
        #expect(reader.sumCalls.allSatisfy { $0.1 == calendar.startOfDay(for: now) && $0.2 == now })
        let heart = reader.sampleCalls.first { $0.0 == HKQuantityType(.heartRate).identifier }
        #expect(heart?.2 == now && heart?.3.contains(.strictEndDate) == true && heart?.4 == 1)
    }

    @Test func latestWeightUsesStableSampleIDAndPreservesLaterManualChanges() async {
        let reader = HealthReaderDouble(), now = Date()
        let sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 71),
            start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-3600))
        reader.sampleValues[sample.sampleType.identifier] = [sample]
        let (health, user, _, directory) = setup(reader: reader, now: now)
        defer { try? FileManager.default.removeItem(at: directory) }
        await health.fetchLatestWeight()
        #expect(user.user.weightHistory.first?.id == sample.uuid)
        #expect(user.user.weight == 71)
        #expect(user.updateUser { $0.weight = 73 })
        await health.fetchLatestWeight()
        #expect(user.user.weightHistory.count == 1 && user.user.weight == 73)
        #expect(reader.authorizationCalls == 1)
    }

    @Test func sleepStagesOverlapAndWindowClippingDoNotInflateTotals() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-86400)
        func sample(_ value: HKCategoryValueSleepAnalysis, _ start: Date, _ end: Date) -> HKCategorySample {
            HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: value.rawValue, start: start, end: end)
        }
        let readings = [
            sample(.asleepUnspecified, cutoff.addingTimeInterval(-3600), cutoff.addingTimeInterval(7200)),
            sample(.asleepCore, cutoff.addingTimeInterval(3600), cutoff.addingTimeInterval(10800)),
            sample(.asleepREM, now.addingTimeInterval(-3600), now.addingTimeInterval(3600)),
            sample(.inBed, cutoff, now), sample(.awake, cutoff.addingTimeInterval(10800), now)
        ]
        #expect(abs(HealthKitManager.asleepHours(readings, from: cutoff, to: now) - 4) < 0.0001)
    }
}
