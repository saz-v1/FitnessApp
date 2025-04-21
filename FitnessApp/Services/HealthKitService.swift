import Foundation
import HealthKit

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private init() {}
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let typesToRead: Set<HKObjectType> = [weightType]
        let typesToWrite: Set<HKSampleType> = [weightType]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }
    
    func syncWithHealthKit() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            try await requestAuthorization()
            try await fetchWeightHistory()
            lastSyncDate = Date()
        } catch {
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    private func fetchWeightHistory() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .year, value: -1, to: Date()), end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthKitError.fetchFailed)
                    return
                }
                
                let weightRecords = samples.map { sample in
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    return WeightRecord(weight: weightInKg, date: sample.startDate)
                }
                
                Task { @MainActor in
                    UserManager.shared.user.weightHistory = weightRecords
                    UserManager.shared.saveUser()
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    func saveWeight(_ weight: Double, date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let weightQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: weightType, quantity: weightQuantity, start: date, end: date)
        
        try await healthStore.save(sample)
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case fetchFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .fetchFailed:
            return "Failed to fetch data from HealthKit"
        case .saveFailed:
            return "Failed to save data to HealthKit"
        }
    }
} 