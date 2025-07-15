import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var lastError: Error?
    
    private let typesToRead: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.respiratoryRate),
        HKCategoryType(.mindfulSession)
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession)
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                self?.lastError = error
                if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        isAuthorized = heartRateStatus == .sharingAuthorized && mindfulSessionStatus != .notDetermined
    }
    
    func saveMindfulSession(_ session: MeditationSession) {
        guard isAuthorized else { 
            print("HealthKit not authorized - cannot save mindful session")
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
                    print("Mindful session saved successfully - Duration: \(session.formattedDuration)")
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
} 