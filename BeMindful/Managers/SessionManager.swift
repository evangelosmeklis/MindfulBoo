import Foundation
import Combine
import AVFoundation

class SessionManager: ObservableObject {
    @Published var isSessionActive = false
    @Published var currentSession: Session?
    @Published var progress: Double = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var sessions: [Session] = []
    @Published var showSessionSavedMessage = false
    
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
        print("🚀 startSession called with duration: \(duration/60) minutes")
        
        guard !isSessionActive else { 
            print("❌ Session already active, returning early")
            return 
        }
        
        print("✅ Starting new meditation session...")
        sessionDuration = duration
        timeRemaining = duration
        startTime = Date()
        isSessionActive = true
        progress = 0
        
        print("📱 isSessionActive set to: \(isSessionActive)")
        
        // Create new session
        currentSession = Session(
            id: UUID(),
            startDate: Date(),
            duration: duration,
            endDate: nil
        )
        
        // Start main session timer
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
            
            // Save session
            sessions.append(session)
            saveSessions()
            
            // Save to HealthKit as a mindful session
            healthManager?.saveMindfulSession(session)
            
            // Show save confirmation briefly
            showSessionSavedMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showSessionSavedMessage = false
            }
            
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
    
    func deleteSession(_ session: Session) {
        // Remove from local storage only (preserve HealthKit data)
        sessions.removeAll { $0.id == session.id }
        saveSessions()
        
        print("Session deleted from app (HealthKit data preserved)")
    }
    
    func deleteAllSessions() {
        // Delete from local storage only (preserve HealthKit data)
        sessions.removeAll()
        saveSessions()
        
        print("All sessions deleted from app (HealthKit data preserved)")
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "BeMindfulSessions")
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "BeMindfulSessions") else { return }
        
        do {
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
}

import AudioToolbox
import UIKit 