import HealthKit

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var steps: Int = 0
    @Published var activeEnergy: Double = 0
    @Published var heartRate: Double = 0
    @Published var heartRateTimestamp: Date?
    @Published var sleepHours: Double = 0
    @Published var workouts: [HKWorkout] = []
    
    static let shared = HealthKitManager()
    
    private let requiredTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType()
    ]
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        try await healthStore.requestAuthorization(toShare: requiredTypes, read: requiredTypes)
        isAuthorized = true
    }
    
    func fetchLatestWeight() async {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let weightInKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            Task { @MainActor in
                UserManager.shared.updateWeight(weightInKg)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchLatestHeight() async {
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            let heightInCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            Task { @MainActor in
                UserManager.shared.updateHeight(heightInCm)
            }
        }
        
        healthStore.execute(query)
    }
    
    func syncWorkouts() async {
        await fetchWorkoutHistory(monthsToFetch: 1)
    }
    
    func fetchWorkoutHistory(monthsToFetch: Int = 3) async {
        let workoutType = HKObjectType.workoutType()
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -monthsToFetch, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let workouts = samples as? [HKWorkout] else { return }
            
            Task { @MainActor [weak self] in
                self?.workouts = workouts
                
                // Create a set of existing workout dates to check for duplicates
                let existingWorkoutDates = Set(UserManager.shared.user.workoutHistory.map { 
                    calendar.startOfDay(for: $0.date)
                })
                
                // Filter out workouts that already exist for the same day and type
                let newWorkouts = workouts.filter { workout in
                    let workoutDate = calendar.startOfDay(for: workout.startDate)
                    return !existingWorkoutDates.contains(workoutDate)
                }
                
                let workoutRecords = newWorkouts.map { workout in
                    WorkoutRecord(
                        id: UUID(),
                        date: workout.startDate,
                        type: self?.mapWorkoutType(workout.workoutActivityType) ?? .other,
                        duration: workout.duration,
                        notes: nil
                    )
                }
                
                if !workoutRecords.isEmpty {
                    UserManager.shared.syncWorkouts(workoutRecords)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodaysHealthData() async {
        do {
            try await requestAuthorization()
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchSteps() }
                group.addTask { await self.fetchActiveEnergy() }
                group.addTask { await self.fetchHeartRate() }
                group.addTask { await self.fetchSleepHours() }
                group.addTask { await self.fetchWorkoutHistory() }
            }
        } catch {
            print("Error fetching health data: \(error)")
        }
    }
    
    private func fetchSteps() async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, _ in
            guard let sum = statistics?.sumQuantity() else { return }
            let steps = Int(sum.doubleValue(for: .count()))
            Task { @MainActor [weak self] in
                self?.steps = steps
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy() async {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        // Create predicate for today's data
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        // Query for statistics
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            guard let statistics = statistics,
                  let sum = statistics.sumQuantity() else {
                print("No active energy data available")
                return
            }
            
            let calories = sum.doubleValue(for: .kilocalorie())
            Task { @MainActor [weak self] in
                self?.activeEnergy = calories
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHeartRate() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,  // No time predicate - just get the latest reading
            limit: 1,        // Only get the most recent reading
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                print("No heart rate data available")
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            Task { @MainActor [weak self] in
                self?.heartRate = heartRate
                self?.heartRateTimestamp = sample.startDate
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchSleepHours() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Query for the most recent sleep samples
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: nil,  // No time predicate - get the latest sleep session
            limit: 10,       // Get a few samples to ensure we get a complete sleep session
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample],
                  error == nil else {
                print("Error fetching sleep data: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            // Filter for sleep samples using the new API
            let sleepSamples = samples.filter { sample in
                if #available(iOS 16.0, *) {
                    return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                           sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                } else {
                    return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                }
            }
            
            guard let lastSleep = sleepSamples.first else {
                print("No recent sleep data available")
                return
            }
            
            // Get duration of the last sleep session
            let sleepDuration = lastSleep.endDate.timeIntervalSince(lastSleep.startDate)
            let hours = sleepDuration / 3600.0
            
            Task { @MainActor [weak self] in
                self?.sleepHours = hours
            }
        }
        
        healthStore.execute(query)
    }
    
    private func createTodayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
    }
    
    @MainActor
    private func mapWorkoutType(_ hkType: HKWorkoutActivityType) -> WorkoutRecord.WorkoutType {
        switch hkType {
        case .running, .walking, .cycling, .swimming, .hiking:
            return .cardio
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return .strength
        case .yoga, .flexibility:
            return .flexibility
        case .highIntensityIntervalTraining:
            return .hiit
        default:
            return .other
        }
    }
} 
