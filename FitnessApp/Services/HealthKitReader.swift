import Foundation
import HealthKit

/// Injectable queries let tests reproduce partial access without personal Health data.
@MainActor
protocol HealthKitReading {
    var isAvailable: Bool { get }
    func requestAuthorization(read: Set<HKObjectType>) async throws
    func dailySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                  from start: Date, to end: Date, calendar: Calendar) async throws -> Double?
    func samples(_ type: HKSampleType, from start: Date?, to end: Date,
                 options: HKQueryOptions, limit: Int) async throws -> [HKSample]
}

@MainActor
final class SystemHealthKitReader: HealthKitReading {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(read: Set<HKObjectType>) async throws {
        try await store.requestAuthorization(toShare: [], read: read)
    }

    func dailySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                  from start: Date, to end: Date, calendar: Calendar) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let interval = DateComponents(calendar: calendar, timeZone: calendar.timeZone, day: 1)
        let healthStore = store
        return try await withCheckedThrowingContinuation { continuation in
            // Calendar buckets retain the part of a sample that crosses midnight.
            let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                options: .cumulativeSum, anchorDate: start, intervalComponents: interval)
            query.initialResultsHandler = { query, collection, error in
                healthStore.stop(query)
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: collection?.statistics(for: start)?.sumQuantity()?.doubleValue(for: unit)) }
            }
            healthStore.execute(query)
        }
    }

    func samples(_ type: HKSampleType, from start: Date?, to end: Date,
                 options: HKQueryOptions, limit: Int) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: options)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
    }
}

enum HealthKitReadError {
    static func isNoData(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == HKErrorDomain && error.code == HKError.errorNoData.rawValue
    }
}
