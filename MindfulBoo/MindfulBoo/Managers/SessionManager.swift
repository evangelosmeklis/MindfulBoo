import Foundation
import Combine
import AVFoundation
import UserNotifications
import UIKit

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
    private var sessionEndTime: Date?
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var healthManager: HealthKitManager?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var notificationIdentifier = "meditation_session_complete"



    
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
        sessionEndTime = Date().addingTimeInterval(duration)
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
        
        // Request notification permissions and schedule completion notification
        requestNotificationPermissions()
        scheduleSessionCompletionNotification(duration: duration)
        
        // Start background task to keep timer running
        startBackgroundTask()
        
        // Setup background/foreground observers
        setupAppStateObservers()
        

        
        // Start lock screen countdown display
        startLockScreenCountdown(duration: duration)
        
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
        
        // Cancel scheduled notification since session is ending
        cancelSessionNotification()
        
        // End background task
        endBackgroundTask()
        
        // End Live Activity
        endLiveActivity()
        
        // Cancel all countdown notifications
        cancelAllCountdownNotifications()
        
        // Remove app state observers
        removeAppStateObservers()
        
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
        guard let startTime = startTime, isSessionActive else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        timeRemaining = max(0, sessionDuration - elapsed)
        progress = min(1.0, elapsed / sessionDuration)
        

        
        // Update Live Activity with current progress
        updateLiveActivity()
        
        // Check if session should end
        if timeRemaining <= 0 {
            DispatchQueue.main.async {
                self.stopSession()
            }
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
            UserDefaults.standard.set(data, forKey: "MindfulBooSessions")
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "MindfulBooSessions") else { return }
        
        do {
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    // MARK: - Background & Notification Support
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
                
                // Setup notification categories for better UX
                if granted {
                    self.setupNotificationCategories()
                }
            }
        }
    }
    
    private func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let extendAction = UNNotificationAction(
            identifier: "EXTEND_ACTION", 
            title: "Extend 5 min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "MEDITATION_COMPLETE",
            actions: [completeAction, extendAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    private func scheduleSessionCompletionNotification(duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "🧘‍♀️ Meditation Complete"
        content.body = "Your \(Int(duration/60))-minute session has finished. Well done!"
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        
        // Add multiple notification strategies for reliability
        content.userInfo = [
            "sessionId": currentSession?.id.uuidString ?? "",
            "sessionDuration": duration,
            "startTime": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Scheduled completion notification for \(duration/60) minutes")
            }
        }
        
        // Schedule lock screen countdown notifications (fallback for devices without Live Activities)
        scheduleLockScreenCountdownNotifications(duration: duration)
        
        // Also schedule intermediate notifications to keep the session alive
        scheduleKeepAliveNotifications(duration: duration)
    }
    
    private func scheduleLockScreenCountdownNotifications(duration: TimeInterval) {
        // Schedule regular countdown notifications for lock screen (every minute for sessions > 5 min)
        if duration > 300 { // Only for sessions longer than 5 minutes
            let countdownIntervals: [TimeInterval] = [
                duration - 60,   // 1 minute remaining
                duration - 180,  // 3 minutes remaining
                duration - 300   // 5 minutes remaining
            ].filter { $0 > 0 } // Only schedule if the interval is positive
            
            for interval in countdownIntervals {
                let remainingMinutes = Int((duration - interval) / 60)
                let content = UNMutableNotificationContent()
                content.title = "🧘‍♀️ Meditation Timer"
                content.body = "\(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") remaining"
                content.sound = nil // Silent notification for lock screen display
                content.badge = nil
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "countdown_\(remainingMinutes)min",
                    content: content,
                    trigger: trigger
                )
                
                UNUserNotificationCenter.current().add(request) { _ in }
            }
        }
        
        // For shorter sessions, just show halfway point
        if duration > 120 && duration <= 300 { // 2-5 minutes
            let halfwayPoint = duration / 2
            let content = UNMutableNotificationContent()
            content.title = "🧘‍♀️ Meditation Timer"
            content.body = "Halfway through your session"
            content.sound = nil
            content.badge = nil
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: halfwayPoint, repeats: false)
            let request = UNNotificationRequest(
                identifier: "halfway_point",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }
    
    private func scheduleKeepAliveNotifications(duration: TimeInterval) {
        // Schedule progress notifications to keep user informed
        let progressIntervals: [TimeInterval] = [
            duration * 0.25,  // 25% complete
            duration * 0.5,   // 50% complete  
            duration * 0.75   // 75% complete
        ]
        
        for (index, interval) in progressIntervals.enumerated() {
            let content = UNMutableNotificationContent()
            let percentage = Int((Double(index + 1) * 25))
            content.title = "Meditation Progress"
            content.body = "\(percentage)% complete - Keep focusing on your breath"
            content.sound = nil
            content.badge = nil
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "progress_\(percentage)", 
                content: content, 
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { _ in }
        }
        
        // Also add a 2-minute warning for longer sessions
        if duration > 300 { // 5+ minutes
            let content = UNMutableNotificationContent()
            content.title = "Almost Done"
            content.body = "2 minutes remaining in your meditation"
            content.sound = UNNotificationSound.default
            content.badge = nil
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration - 120, repeats: false)
            let request = UNNotificationRequest(
                identifier: "two_minute_warning", 
                content: content, 
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }
    
    private func cancelSessionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        
        // Also cancel all progress notifications
        let progressIds = ["progress_25", "progress_50", "progress_75", "two_minute_warning"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: progressIds)
        
        print("Cancelled session notification and progress notifications")
    }
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MeditationTimer") { [weak self] in
            self?.endBackgroundTask()
        }
        print("Started background task: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("Ended background task")
        }
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func removeAppStateObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        print("App entered background during meditation session")
        // Timer continues running in background for a limited time
        // Notification will alert user when session completes
    }
    
    @objc private func appWillEnterForeground() {
        print("App returning to foreground during meditation session")
        
        // Check if session should have completed while in background
        guard isSessionActive, let sessionEndTime = sessionEndTime else { return }
        
        let now = Date()
        if now >= sessionEndTime {
            // Session completed while in background
            print("Session completed while in background, stopping now")
            DispatchQueue.main.async {
                self.stopSession()
            }
        } else {
            // Update timer to reflect current state
            updateTimer()
        }
    }
    
    // MARK: - Lock Screen Countdown Support
    
    private func startLockScreenCountdown(duration: TimeInterval) {
        // Start Live Activity for persistent lock screen display
        print("Starting Live Activity for lock screen countdown")
        startLiveActivity(duration: duration)
        
        // Also schedule enhanced notifications as fallback
        scheduleEnhancedLockScreenNotifications(duration: duration)
    }
    
    private func scheduleEnhancedLockScreenNotifications(duration: TimeInterval) {
        // Schedule frequent countdown notifications for better lock screen visibility
        let totalMinutes = Int(duration / 60)
        var intervals: [TimeInterval] = []
        
        // For sessions longer than 10 minutes, show every 2 minutes
        if totalMinutes > 10 {
            for minute in stride(from: totalMinutes - 2, through: 1, by: -2) {
                let interval = duration - TimeInterval(minute * 60)
                if interval > 0 {
                    intervals.append(interval)
                }
            }
        }
        // For sessions 5-10 minutes, show every minute
        else if totalMinutes > 5 {
            for minute in stride(from: totalMinutes - 1, through: 1, by: -1) {
                let interval = duration - TimeInterval(minute * 60)
                if interval > 0 {
                    intervals.append(interval)
                }
            }
        }
        // For sessions 2-5 minutes, show at halfway and 1 minute remaining
        else if totalMinutes >= 2 {
            intervals = [duration / 2, duration - 60].filter { $0 > 0 }
        }
        
        // Schedule all countdown notifications
        for interval in intervals {
            let remainingMinutes = Int((duration - interval) / 60)
            let remainingSeconds = Int((duration - interval).truncatingRemainder(dividingBy: 60))
            
            let content = UNMutableNotificationContent()
            content.title = "🧘‍♀️ Meditation Timer"
            
            if remainingMinutes > 0 {
                content.body = "\(remainingMinutes):\(String(format: "%02d", remainingSeconds)) remaining"
            } else {
                content.body = "\(remainingSeconds) seconds remaining"
            }
            
            content.sound = nil // Silent for lock screen display
            content.badge = nil
            content.categoryIdentifier = "MEDITATION_COUNTDOWN"
            
            // Add progress info to user info for potential future use
            content.userInfo = [
                "timeRemaining": duration - interval,
                "progress": interval / duration,
                "sessionId": currentSession?.id.uuidString ?? ""
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "countdown_\(Int(interval))",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule countdown notification: \(error)")
                } else {
                    print("Scheduled countdown notification for \(remainingMinutes):\(String(format: "%02d", remainingSeconds))")
                }
            }
        }
        
        // Add countdown category for better UX
        setupCountdownNotificationCategory()
    }
    
    private func setupCountdownNotificationCategory() {
        let stopAction = UNNotificationAction(
            identifier: "STOP_SESSION_ACTION",
            title: "Stop Session",
            options: [.foreground, .destructive]
        )
        
        let extendAction = UNNotificationAction(
            identifier: "EXTEND_SESSION_ACTION",
            title: "Extend +5min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "MEDITATION_COUNTDOWN",
            actions: [stopAction, extendAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    private func cancelAllCountdownNotifications() {
        // Cancel all countdown notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let countdownIds = requests.compactMap { request in
                request.identifier.hasPrefix("countdown_") ? request.identifier : nil
            }
            
            if !countdownIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: countdownIds)
                print("Cancelled \(countdownIds.count) countdown notifications")
            }
        }
        
        // Also cancel specific countdown notifications we know about
        let knownIds = ["halfway_point", "countdown_1min", "countdown_3min", "countdown_5min"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: knownIds)
    }
    
    // MARK: - Live Activity Support
    
    private func startLiveActivity(duration: TimeInterval) {
        // Live Activities not available - using enhanced notification system
        print("⚠️ Live Activities not available - using enhanced fallback notifications")
        print("💡 Enhanced notifications will provide lock screen countdown updates")
    }
    
    private func updateLiveActivity() {
        // No Live Activity to update - using notification system instead
    }
    
    private func endLiveActivity() {
        // No Live Activity to end - notifications will be cancelled separately
    }

}

import AudioToolbox
import UIKit 