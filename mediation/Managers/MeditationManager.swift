import Foundation
import Combine
import AVFoundation

class MeditationManager: ObservableObject {
    @Published var isSessionActive = false
    @Published var currentSession: MeditationSession?
    @Published var progress: Double = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var sessions: [MeditationSession] = []
    
    private var timer: Timer?
    private var sessionDuration: TimeInterval = 0
    private var startTime: Date?
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var healthManager: HealthKitManager?
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        loadSessions()
        setupAudioSession()
    }
    
    func setHealthManager(_ healthManager: HealthKitManager) {
        self.healthManager = healthManager
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
            
            // Calculate averages if we have health data
            session.calculateAverages()
            
            // Save session
            sessions.append(session)
            saveSessions()
            
            // Save to HealthKit
            healthManager?.saveMindfulSession(session)
            
            currentSession = nil
        }
        
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
    
    private func playCompletionSound() {
        // Play system sound for meditation completion
        AudioServicesPlaySystemSound(1327) // Gentle bell sound
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Session Management
    
    func deleteSession(_ session: MeditationSession) {
        // Remove from local storage
        sessions.removeAll { $0.id == session.id }
        saveSessions()
        
        // Also delete from HealthKit if available
        healthManager?.deleteMindfulSession(session) { success in
            if success {
                print("Session deleted from HealthKit")
            } else {
                print("Failed to delete session from HealthKit")
            }
        }
    }
    
    func deleteAllSessions() {
        // Delete each session from HealthKit first
        let sessionsToDelete = sessions
        sessions.removeAll()
        saveSessions()
        
        // Delete from HealthKit
        for session in sessionsToDelete {
            healthManager?.deleteMindfulSession(session) { success in
                if success {
                    print("Session deleted from HealthKit")
                } else {
                    print("Failed to delete session from HealthKit")
                }
            }
        }
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
}

import AudioToolbox
import UIKit 