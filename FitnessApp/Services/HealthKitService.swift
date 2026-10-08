import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()
    private let preference = HealthIntegrationPreference.shared
    private var syncToken: UInt?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    private init() {}

    func syncWithHealthKit() async {
        guard let token = try? preference.accessToken(), syncToken == nil else { return }
        syncToken = token
        isSyncing = true
        syncError = nil
        defer {
            if syncToken == token { syncToken = nil; isSyncing = false }
        }
        do {
            guard HKHealthStore.isHealthDataAvailable(), let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { throw HealthKitError.notAvailable }
            try await healthStore.requestAuthorization(toShare: [], read: [type])
            try preference.validate(token)
            let now = Date()
            let start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now.addingTimeInterval(-31536000)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKQuantitySample }) }
                }
                healthStore.execute(query)
            }
            try preference.validate(token)
            let records = samples.compactMap { sample -> WeightRecord? in
                let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                guard kilograms.isFinite, (1...700).contains(kilograms), sample.startDate <= now else { return nil }
                return WeightRecord(id: sample.uuid, weight: kilograms, date: sample.startDate)
            }
            guard UserManager.shared.syncWeights(records) else { throw HealthKitError.saveFailed }
            lastSyncDate = now
        } catch is CancellationError { return
        } catch {
            guard (try? preference.validate(token)) != nil else { return }
            syncError = "Apple Health records could not be synced. Unlock your device and try again."
        }
    }

    func disconnect() {
        preference.invalidate()
        syncToken = nil
        isSyncing = false
        lastSyncDate = nil
        syncError = nil
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable, fetchFailed, saveFailed
    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Apple Health is unavailable on this device."
        case .fetchFailed: return "Apple Health records could not be read."
        case .saveFailed: return "Records could not be saved. Unlock your device and try again."
        }
    }
}
