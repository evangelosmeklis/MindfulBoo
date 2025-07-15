import Foundation
import Combine
import AVFoundation
import WatchConnectivity

class MeditationManager: ObservableObject {
    @Published var isSessionActive = false
    @Published var currentSession: MeditationSession?
    @Published var progress: Double = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentHeartRate: Double?
    @Published var currentBreathingRate: Double?
    @Published var sessions: [MeditationSession] = []
    
    private var timer: Timer?
    private var sessionDuration: TimeInterval = 0
    private var startTime: Date?
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        loadSessions()
        setupAudioSession()
        
        // Listen for watch connectivity updates
        NotificationCenter.default.publisher(for: .watchConnectivityDidReceiveData)
            .sink { [weak self] notification in
                self?.handleWatchData(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startSession(duration: TimeInterval) {
        guard !isSessionActive else { return }
        
        sessionDuration = duration
        timeRemaining = duration
        startTime = Date()
        isSessionActive = true
        progress = 0
        
        // Create new session
        currentSession = MeditationSession(
            id: UUID(),
            startDate: Date(),
            duration: duration,
            endDate: nil,
            heartRateData: [],
            breathingRateData: [],
            averageHeartRate: nil,
            averageBreathingRate: nil
        )
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // Start watch session
        WatchConnectivityManager.shared.startMeditationSession(duration: duration)
        
        print("Started meditation session for \(duration/60) minutes")
    }
    
    func stopSession() {
        guard isSessionActive else { return }
        
        timer?.invalidate()
        timer = nil
        isSessionActive = false
        
        // Complete current session
        if var session = currentSession {
            session.endDate = Date()
            session.actualDuration = Date().timeIntervalSince(session.startDate)
            
            // Save session
            sessions.append(session)
            saveSessions()
            
            // Save to HealthKit
            if let healthManager = getHealthManager() {
                healthManager.saveMindfulSession(session)
            }
            
            currentSession = nil
        }
        
        // Stop watch session
        WatchConnectivityManager.shared.stopMeditationSession()
        
        // Play completion sound
        playCompletionSound()
        
        print("Stopped meditation session")
    }
    
    private func updateTimer() {
        guard let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        timeRemaining = max(0, sessionDuration - elapsed)
        progress = min(1.0, elapsed / sessionDuration)
        
        // Check if session should end
        if timeRemaining <= 0 {
            stopSession()
        }
    }
    
    private func handleWatchData(_ notification: Notification) {
        guard let data = notification.userInfo?["data"] as? [String: Any] else { return }
        
        if let heartRate = data["heartRate"] as? Double {
            currentHeartRate = heartRate
        }
        
        if let breathingRate = data["breathingRate"] as? Double {
            currentBreathingRate = breathingRate
        }
        
        // Update current session with new data
        if var session = currentSession {
            if let heartRate = currentHeartRate {
                let heartRateDataPoint = HealthDataPoint(
                    timestamp: Date(),
                    value: heartRate
                )
                session.heartRateData.append(heartRateDataPoint)
            }
            
            if let breathingRate = currentBreathingRate {
                let breathingRateDataPoint = HealthDataPoint(
                    timestamp: Date(),
                    value: breathingRate
                )
                session.breathingRateData.append(breathingRateDataPoint)
            }
            
            currentSession = session
        }
    }
    
    private func playCompletionSound() {
        // Play system sound for meditation completion
        AudioServicesPlaySystemSound(1327) // Gentle bell sound
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "MeditationSessions")
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "MeditationSessions") else { return }
        
        do {
            sessions = try JSONDecoder().decode([MeditationSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    private func getHealthManager() -> HealthKitManager? {
        // This would be injected in a real app
        return nil
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let watchConnectivityDidReceiveData = Notification.Name("watchConnectivityDidReceiveData")
}

import AudioToolbox
import UIKit 