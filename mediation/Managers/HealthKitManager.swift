import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var lastError: Error?
    @Published var currentHeartRate: Double?
    @Published var currentRespiratoryRate: Double?
    @Published var isMonitoringHeartRate = false
    @Published var isMonitoringRespiratoryRate = false
    
    // Track actual data access test results
    private var heartRateAccessWorks = false
    private var respiratoryRateAccessWorks = false
    
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var respiratoryRateQuery: HKAnchoredObjectQuery?
    
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
    
    func forceRefreshPermissions() {
        print("🔄 Force refreshing HealthKit permissions...")
        
        // Add a small delay to ensure iOS has updated the permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAuthorizationStatus()
            
            // Also try to query samples to test actual access
            self.testHeartRateAccess()
            self.testRespiratoryRateAccess()
        }
    }
    
    private func testHeartRateAccess() {
        let heartRateType = HKQuantityType(.heartRate)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Heart rate test query failed: \(error.localizedDescription)")
                    self?.heartRateAccessWorks = false
                } else {
                    print("✅ Heart rate test query succeeded - access is working")
                    print("   Found \(samples?.count ?? 0) recent heart rate samples")
                    self?.heartRateAccessWorks = true
                }
                // Recheck authorization after test completes
                self?.updateAuthorizationStatus()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func testRespiratoryRateAccess() {
        let respiratoryRateType = HKQuantityType(.respiratoryRate)
        let query = HKSampleQuery(
            sampleType: respiratoryRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Respiratory rate test query failed: \(error.localizedDescription)")
                    self?.respiratoryRateAccessWorks = false
                } else {
                    print("✅ Respiratory rate test query succeeded - access is working")
                    print("   Found \(samples?.count ?? 0) recent respiratory rate samples")
                    self?.respiratoryRateAccessWorks = true
                }
                // Recheck authorization after test completes
                self?.updateAuthorizationStatus()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func updateAuthorizationStatus() {
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        // For this app to work properly, we need mindful session write access and working data access
        let mindfulOK = mindfulSessionStatus != .notDetermined
        // Use actual test results instead of unreliable authorization status
        let heartRateOK = heartRateAccessWorks
        
        isAuthorized = mindfulOK && heartRateOK
        
        print("🎯 Updated Authorization Status (using test results):")
        print("   • Mindful sessions: \(authStatusDescription(mindfulSessionStatus)) (\(mindfulOK ? "✅" : "❌"))")
        print("   • Heart rate access test: \(heartRateOK ? "✅ WORKING" : "❌ FAILED")")
        print("   • Respiratory rate access test: \(respiratoryRateAccessWorks ? "✅ WORKING" : "❌ FAILED")")
        print("   • Overall authorized: \(isAuthorized ? "✅ YES" : "❌ NO")")
        
        if isAuthorized {
            print("🚀 Ready to start monitoring!")
        }
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
            print("❌ HealthKit not available on this device")
            return
        }
        
        // Check authorization for heart rate (this is what we really need)
        let heartRateAuthStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        
        switch heartRateAuthStatus {
        case .notDetermined:
            print("💡 Heart rate permission not yet requested - requesting now...")
            requestPermissions()
            return
            
        case .sharingDenied:
            print("⚠️  Heart rate permission shows as denied, but checking if data access actually works...")
            // If our test query succeeded, trust that over the reported status
            if heartRateAccessWorks {
                print("✅ Heart rate data access test passed - proceeding with monitoring")
                break
            } else {
                print("❌ Heart rate permission denied and data access test failed")
                print("   Please enable Heart Rate permission in Settings > Privacy & Security > Health > [App Name]")
                return
            }
            
        case .sharingAuthorized:
            print("✅ Heart rate permission granted - starting monitoring")
            break
            
        @unknown default:
            print("⚠️ Unknown heart rate authorization status")
            return
        }
        
        // Start heart rate and respiratory rate monitoring immediately
        startHeartRateMonitoring()
        startRespiratoryRateMonitoring()
        
        print("🔄 Started heart rate & respiratory rate monitoring - Apple Watch should begin tracking")
    }
    
    func stopWorkoutSession() {
        // Stop heart rate and respiratory rate monitoring
        stopHeartRateMonitoring()
        stopRespiratoryRateMonitoring()
        
        print("✅ Stopped heart rate & respiratory rate monitoring")
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
    
    // MARK: - Live Respiratory Rate Monitoring
    
    private func startRespiratoryRateMonitoring() {
        guard respiratoryRateQuery == nil else { return }
        
        let respiratoryRateType = HKQuantityType(.respiratoryRate)
        let respiratoryRateUnit = HKUnit.count().unitDivided(by: .minute())
        
        // Create anchored query for real-time respiratory rate updates
        respiratoryRateQuery = HKAnchoredObjectQuery(
            type: respiratoryRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            // Get the most recent respiratory rate sample
            if let latestSample = samples.last {
                let respiratoryRate = latestSample.quantity.doubleValue(for: respiratoryRateUnit)
                
                DispatchQueue.main.async {
                    self?.currentRespiratoryRate = respiratoryRate
                    self?.isMonitoringRespiratoryRate = true
                    print("🫁 Live respiratory rate: \(Int(respiratoryRate)) breaths/min")
                }
            }
        }
        
        // Set up update handler for continuous monitoring
        respiratoryRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            if let latestSample = samples.last {
                let respiratoryRate = latestSample.quantity.doubleValue(for: respiratoryRateUnit)
                
                DispatchQueue.main.async {
                    self?.currentRespiratoryRate = respiratoryRate
                    print("🫁 Updated respiratory rate: \(Int(respiratoryRate)) breaths/min")
                }
            }
        }
        
        // Execute the query
        if let query = respiratoryRateQuery {
            healthStore.execute(query)
            print("🔄 Started live respiratory rate monitoring")
        }
    }
    
    private func stopRespiratoryRateMonitoring() {
        if let query = respiratoryRateQuery {
            healthStore.stop(query)
            respiratoryRateQuery = nil
            print("⏹️ Stopped respiratory rate monitoring")
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("❌ HealthKit not available on this device")
            return 
        }
        
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        let heartRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        let respiratoryRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.respiratoryRate))
        
        // Debug: Print raw values
        print("🔍 Raw Authorization Values:")
        print("   • Heart rate raw value: \(heartRateStatus.rawValue)")
        print("   • Respiratory rate raw value: \(respiratoryRateStatus.rawValue)")
        print("   • Mindful sessions raw value: \(mindfulSessionStatus.rawValue)")
        print("   • Workout raw value: \(workoutStatus.rawValue)")
        
        // NOTE: These reported statuses are often unreliable, actual authorization determined by test queries
        
        print("📊 HealthKit Authorization Status (reported by iOS):")
        print("   • Mindful sessions: \(authStatusDescription(mindfulSessionStatus))")
        print("   • Heart rate: \(authStatusDescription(heartRateStatus))")
        print("   • Respiratory rate: \(authStatusDescription(respiratoryRateStatus))")
        print("   • Workout: \(authStatusDescription(workoutStatus))")
        print("")
        print("⚠️  Note: iOS often reports incorrect status. Testing actual data access...")
    }
    
    func debugPermissions() {
        print("\n🐛 DEBUG: Full Permission Analysis")
        print("=======================================")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        print("Raw value meanings: 0=NotDetermined, 1=Denied, 2=Authorized")
        print("")
        
        // Check all relevant types
        let types: [(String, HKObjectType)] = [
            ("Heart Rate", HKQuantityType(.heartRate)),
            ("Respiratory Rate", HKQuantityType(.respiratoryRate)),
            ("Mindful Session", HKCategoryType(.mindfulSession)),
            ("Workout", HKObjectType.workoutType())
        ]
        
        for (name, type) in types {
            let status = healthStore.authorizationStatus(for: type)
            let statusName = authStatusDescription(status)
            let emoji = status == .sharingAuthorized ? "✅" : (status == .sharingDenied ? "❌" : "⚠️")
            print("   \(emoji) \(name): \(statusName) (raw: \(status.rawValue))")
        }
        
        print("")
        print("Expected for app to work:")
        print("   • Heart Rate should be: Authorized (raw: 2)")
        print("   • Mindful Session should be: Authorized (raw: 2)")
        print("=======================================\n")
    }
    
    private func authStatusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Permission Status Helpers
    
    var canMonitorHeartRate: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let heartRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        return heartRateStatus == .sharingAuthorized
    }
    
    var heartRatePermissionStatus: String {
        guard HKHealthStore.isHealthDataAvailable() else { return "HealthKit not available" }
        let heartRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        
        switch heartRateStatus {
        case .notDetermined:
            return "Tap to enable heart rate monitoring"
        case .sharingDenied:
            return "Heart rate access denied - check Settings"
        case .sharingAuthorized:
            return "Heart rate monitoring ready"
        @unknown default:
            return "Unknown permission status"
        }
    }
    
    func retryHeartRatePermission() {
        print("🔄 Retrying heart rate permission request...")
        requestPermissions()
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