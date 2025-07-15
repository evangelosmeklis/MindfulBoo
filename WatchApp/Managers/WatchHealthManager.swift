import Foundation
import HealthKit
import Combine

class WatchHealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var lastError: Error?
    
    private let typesToRead: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.respiratoryRate)
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
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
        isAuthorized = heartRateStatus == .sharingAuthorized
    }
    
    func startHeartRateQuery(completion: @escaping (Double?) -> Void) {
        guard isAuthorized else { 
            completion(nil)
            return 
        }
        
        let heartRateType = HKQuantityType(.heartRate)
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Heart rate observer query failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            self?.fetchLatestHeartRate(completion: completion)
        }
        
        healthStore.execute(query)
        
        // Also fetch immediately
        fetchLatestHeartRate(completion: completion)
    }
    
    private func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        let heartRateType = HKQuantityType(.heartRate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            
            if let error = error {
                print("Failed to fetch latest heart rate: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            DispatchQueue.main.async {
                completion(heartRate)
            }
        }
        
        healthStore.execute(query)
    }
    
    func startBreathingRateQuery(completion: @escaping (Double?) -> Void) {
        guard isAuthorized else { 
            completion(nil)
            return 
        }
        
        let breathingRateType = HKQuantityType(.respiratoryRate)
        
        let query = HKObserverQuery(sampleType: breathingRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Breathing rate observer query failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            self?.fetchLatestBreathingRate(completion: completion)
        }
        
        healthStore.execute(query)
        
        // Also fetch immediately
        fetchLatestBreathingRate(completion: completion)
    }
    
    private func fetchLatestBreathingRate(completion: @escaping (Double?) -> Void) {
        let breathingRateType = HKQuantityType(.respiratoryRate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: breathingRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            
            if let error = error {
                print("Failed to fetch latest breathing rate: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            
            let breathingRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            DispatchQueue.main.async {
                completion(breathingRate)
            }
        }
        
        healthStore.execute(query)
    }
} 