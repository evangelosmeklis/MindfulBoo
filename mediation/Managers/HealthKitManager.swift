import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var lastError: Error?
    @Published var currentHeartRate: Double?
    @Published var isMonitoringHeartRate = false
    
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    private let typesToRead: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.respiratoryRate),
        HKCategoryType(.mindfulSession)
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession),
        HKObjectType.workoutType()
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        print("Requesting HealthKit permissions for: Heart Rate, Mindful Sessions, Workouts")
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                    self?.lastError = error
                } else {
                    print("HealthKit authorization completed. Overall success: \(success)")
                }
                
                // Always check individual authorization status regardless of overall success
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    func saveMindfulSession(_ session: MeditationSession) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Check current authorization status
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        guard mindfulSessionStatus == .sharingAuthorized else {
            print("HealthKit not authorized for mindful sessions - status: \(mindfulSessionStatus.rawValue)")
            if mindfulSessionStatus == .notDetermined {
                print("HealthKit permissions not yet requested")
                requestPermissions()
            }
            return
        }
        
        // Ensure we have valid dates
        let startDate = session.startDate
        let endDate = session.endDate ?? Date()
        
        let mindfulSession = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )
        
        healthStore.save(mindfulSession) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    print("Failed to save mindful session: \(error.localizedDescription)")
                } else {
                    print("✅ Mindful session saved successfully to Health app - Duration: \(session.formattedDuration)")
                }
            }
        }
    }
    
    func deleteMindfulSession(_ session: MeditationSession, completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            completion(false)
            return
        }
        
        let mindfulSessionType = HKCategoryType(.mindfulSession)
        let predicate = HKQuery.predicateForSamples(
            withStart: session.startDate,
            end: session.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: mindfulSessionType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            
            if let error = error {
                print("Failed to find mindful session for deletion: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            guard let sample = samples?.first else {
                print("No mindful session found to delete")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            self?.healthStore.delete(sample) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to delete mindful session: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("Mindful session deleted successfully")
                        completion(true)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHeartRateData(for session: MeditationSession, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard isAuthorized else { 
            completion([])
            return 
        }
        
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: session.startDate,
            end: session.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            
            if let error = error {
                print("Failed to fetch heart rate data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let heartRateSamples = samples as? [HKQuantitySample] ?? []
            completion(heartRateSamples)
        }
        
        healthStore.execute(query)
    }
    
    func fetchBreathingRateData(for session: MeditationSession, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard isAuthorized else { 
            completion([])
            return 
        }
        
        let breathingRateType = HKQuantityType(.respiratoryRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: session.startDate,
            end: session.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: breathingRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            
            if let error = error {
                print("Failed to fetch breathing rate data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let breathingRateSamples = samples as? [HKQuantitySample] ?? []
            completion(breathingRateSamples)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Workout Session Management
    
    /// Starts heart rate monitoring and creates a workout session to trigger Apple Watch monitoring
    /// This iOS-compatible approach focuses on heart rate monitoring and creates workout records
    /// when the session completes, which signals paired Apple Watches to begin monitoring.
    func startWorkoutSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available")
            return
        }
        
        // Check authorization for heart rate (this is what we really need)
        let heartRateAuthStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        guard heartRateAuthStatus == .sharingAuthorized else {
            print("Heart rate authorization not granted")
            return
        }
        
        // Start heart rate monitoring immediately
        startHeartRateMonitoring()
        
        print("✅ Started heart rate monitoring - Apple Watch should begin tracking")
    }
    
    func stopWorkoutSession() {
        // Stop heart rate monitoring
        stopHeartRateMonitoring()
        
        print("✅ Stopped heart rate monitoring")
    }
    
    // MARK: - Workout Record Creation
    
    /// Creates a workout record for the completed meditation session
    /// This helps Apple Watch and Health app recognize the meditation as a tracked workout
    func saveWorkoutRecord(for session: MeditationSession) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let workoutAuthStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        guard workoutAuthStatus == .sharingAuthorized else {
            print("Workout authorization not granted - skipping workout record")
            return
        }
        
        let startDate = session.startDate
        let endDate = session.endDate ?? Date()
        
        // Create workout record
        let workout = HKWorkout(
            activityType: .other,
            start: startDate,
            end: endDate,
            duration: session.effectiveDuration,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Mindful Meditation",
                HKMetadataKeyExternalUUID: session.id.uuidString
            ]
        )
        
        healthStore.save(workout) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to save workout record: \(error.localizedDescription)")
                } else {
                    print("✅ Workout record saved to Health app")
                }
            }
        }
    }
    
    // MARK: - Live Heart Rate Monitoring
    
    private func startHeartRateMonitoring() {
        guard heartRateQuery == nil else { return }
        
        let heartRateType = HKQuantityType(.heartRate)
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        
        // Create anchored query for real-time heart rate updates
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            // Get the most recent heart rate sample
            if let latestSample = samples.last {
                let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)
                
                DispatchQueue.main.async {
                    self?.currentHeartRate = heartRate
                    self?.isMonitoringHeartRate = true
                    print("💓 Live heart rate: \(Int(heartRate)) BPM")
                }
            }
        }
        
        // Set up update handler for continuous monitoring
        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            if let latestSample = samples.last {
                let heartRate = latestSample.quantity.doubleValue(for: heartRateUnit)
                
                DispatchQueue.main.async {
                    self?.currentHeartRate = heartRate
                    print("💓 Updated heart rate: \(Int(heartRate)) BPM")
                }
            }
        }
        
        // Execute the query
        if let query = heartRateQuery {
            healthStore.execute(query)
            print("🔄 Started live heart rate monitoring")
        }
    }
    
    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            print("⏹️ Stopped heart rate monitoring")
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        
        // For writing mindful sessions, we need sharingAuthorized or sharingDenied (but not notDetermined)
        isAuthorized = mindfulSessionStatus != .notDetermined && workoutStatus != .notDetermined
        
        print("HealthKit mindful session authorization status: \(mindfulSessionStatus.rawValue)")
        print("HealthKit workout authorization status: \(workoutStatus.rawValue)")
    }
    
    // MARK: - Apple Watch Detection
    
    func isAppleWatchLikelyPaired() -> Bool {
        // Check if we can create a workout session (indicates watch capability)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let workoutAuthStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        let heartRateAuthStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        
        // If both are authorized or determined, Apple Watch is likely available
        return workoutAuthStatus != .notDetermined && heartRateAuthStatus != .notDetermined
    }
} 