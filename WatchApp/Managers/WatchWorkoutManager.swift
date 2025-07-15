import Foundation
import HealthKit
import Combine

class WatchWorkoutManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentHeartRate: Double?
    @Published var currentBreathingRate: Double?
    
    private var timer: Timer?
    private var sessionStartDate: Date?
    private var sessionDuration: TimeInterval = 0
    
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        // Request authorization when manager is created
        requestHealthAuthorization()
    }
    
    private func requestHealthAuthorization() {
        let typesToRead: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout(duration: TimeInterval) {
        guard !isSessionActive else { return }
        
        sessionDuration = duration
        sessionStartDate = Date()
        
        // Create workout configuration for mindfulness
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown
        
        do {
            // Create workout session
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            // Set up delegates
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            // Set data source
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { [weak self] success, error in
                if let error = error {
                    print("Failed to begin workout collection: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self?.isSessionActive = success
                        self?.startTimer()
                    }
                }
            }
            
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func pauseWorkout() {
        guard isSessionActive else { return }
        
        if isPaused {
            workoutSession?.resume()
            isPaused = false
        } else {
            workoutSession?.pause()
            isPaused = true
        }
    }
    
    func endWorkout() {
        guard isSessionActive else { return }
        
        workoutSession?.end()
        stopTimer()
        
        // Send final data to iPhone
        sendDataToPhone()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        guard let startDate = sessionStartDate else { return }
        
        elapsedTime = Date().timeIntervalSince(startDate)
        
        // Auto-end session when duration is reached
        if elapsedTime >= sessionDuration {
            endWorkout()
        }
        
        // Send periodic updates to iPhone
        if Int(elapsedTime) % 5 == 0 { // Every 5 seconds
            sendDataToPhone()
        }
    }
    
    private func sendDataToPhone() {
        var data: [String: Any] = [:]
        
        if let heartRate = currentHeartRate {
            data["heartRate"] = heartRate
        }
        
        if let breathingRate = currentBreathingRate {
            data["breathingRate"] = breathingRate
        }
        
        data["elapsedTime"] = elapsedTime
        data["timestamp"] = Date()
        
        WatchConnectivityManager.shared.sendHealthData(data)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isSessionActive = true
                self.isPaused = false
            case .paused:
                self.isPaused = true
            case .ended:
                self.isSessionActive = false
                self.isPaused = false
                self.stopTimer()
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isSessionActive = false
            self.stopTimer()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let heartRateUnit = statistics?.mostRecentQuantity() {
                        self.currentHeartRate = heartRateUnit.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    }
                case HKQuantityType(.respiratoryRate):
                    if let breathingRateUnit = statistics?.mostRecentQuantity() {
                        self.currentBreathingRate = breathingRateUnit.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    }
                default:
                    break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
} 