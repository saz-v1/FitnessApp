import Foundation
import HealthKit

/// Service for interacting with Apple HealthKit
class HealthKitService: ObservableObject {
    /// Singleton instance for app-wide access
    static let shared = HealthKitService()
    
    /// HealthKit store for accessing health data
    private let healthStore = HKHealthStore()
    
    /// Published properties for UI updates
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Request authorization to access HealthKit data
    func requestAuthorization() async throws {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // Define the types of data we want to access
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let typesToRead: Set<HKObjectType> = [weightType]
        let typesToWrite: Set<HKSampleType> = [weightType]
        
        // Request authorization from the user
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }
    
    /// Sync weight data with HealthKit
    func syncWithHealthKit() async {
        // Prevent multiple sync operations from running simultaneously
        guard !isSyncing else { return }
        
        // Update UI on main thread
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Request authorization and fetch weight history
            try await requestAuthorization()
            try await fetchWeightHistory()
            
            // Update last sync date on main thread
            await MainActor.run {
                lastSyncDate = Date()
            }
        } catch {
            // Handle errors on main thread
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
        
        // Reset syncing state on main thread
        await MainActor.run {
            isSyncing = false
        }
    }
    
    /// Fetch weight history from HealthKit
    private func fetchWeightHistory() async throws {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // Set up query parameters
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .year, value: -1, to: Date()), end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        // Execute query with continuation
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                // Handle query errors
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Ensure samples are of the correct type
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(throwing: HealthKitError.fetchFailed)
                    return
                }
                
                // Convert HealthKit samples to app's WeightRecord model
                let weightRecords = samples.map { sample in
                    let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    return WeightRecord(weight: weightInKg, date: sample.startDate)
                }
                
                // Update user data on main thread
                Task { @MainActor in
                    UserManager.shared.user.weightHistory = weightRecords
                    UserManager.shared.saveUser()
                    continuation.resume()
                }
            }
            
            // Execute the query
            healthStore.execute(query)
        }
    }
    
    /// Save a weight measurement to HealthKit
    func saveWeight(_ weight: Double, date: Date) async throws {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // Create a HealthKit sample
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let weightQuantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: weightType, quantity: weightQuantity, start: date, end: date)
        
        // Save the sample to HealthKit
        try await healthStore.save(sample)
    }
}

/// Errors that can occur during HealthKit operations
enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
    case fetchFailed
    case saveFailed
} 