import Foundation
import Combine
import AVFoundation
import AudioToolbox
import UserNotifications
import UIKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity Attributes
struct MindfulBooActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the session
        var timeRemaining: TimeInterval
        var progress: Double
        var sessionState: SessionState
        var sessionEndTime: Date // Add fixed end time for consistent countdown
    }

    // Static data that doesn't change
    var sessionDuration: TimeInterval
    var sessionStartTime: Date // Add start time for reference
}

enum SessionState: String, Codable, Hashable {
    case running
    case paused
    case ended
}

// MARK: - Settings Types (from Settings.swift)

struct AppSettings: Codable {
    var sessionNotifications: SessionNotificationSettings
    var dailyReminders: DailyReminderSettings
    
    static let `default` = AppSettings(
        sessionNotifications: SessionNotificationSettings(),
        dailyReminders: DailyReminderSettings()
    )
}

struct SessionNotificationSettings: Codable {
    var isEnabled: Bool = true
    var intervalType: NotificationInterval = .none
    var progressNotifications: Set<ProgressNotification> = []
    
    enum NotificationInterval: String, CaseIterable, Codable {
        case none = "none"
        case everyMinute = "every_minute"
        case every2Minutes = "every_2_minutes"
        case every5Minutes = "every_5_minutes"
        case every10Minutes = "every_10_minutes"
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .everyMinute: return "Every minute"
            case .every2Minutes: return "Every 2 minutes"
            case .every5Minutes: return "Every 5 minutes"
            case .every10Minutes: return "Every 10 minutes"
            }
        }
        
        var intervalSeconds: TimeInterval {
            switch self {
            case .none: return 0
            case .everyMinute: return 60
            case .every2Minutes: return 120
            case .every5Minutes: return 300
            case .every10Minutes: return 600
            }
        }
    }
    
    enum ProgressNotification: String, CaseIterable, Codable {
        case percent25 = "25_percent"
        case percent50 = "50_percent"
        case percent75 = "75_percent"
        case twoMinutesLeft = "2_minutes_left"
        case oneMinuteLeft = "1_minute_left"
        
        var displayName: String {
            switch self {
            case .percent25: return "25% complete"
            case .percent50: return "50% complete"
            case .percent75: return "75% complete"
            case .twoMinutesLeft: return "2 minutes remaining"
            case .oneMinuteLeft: return "1 minute remaining"
            }
        }
        
        func getNotificationTime(for sessionDuration: TimeInterval) -> TimeInterval? {
            switch self {
            case .percent25:
                return sessionDuration * 0.25
            case .percent50:
                return sessionDuration * 0.5
            case .percent75:
                return sessionDuration * 0.75
            case .twoMinutesLeft:
                return sessionDuration > 120 ? sessionDuration - 120 : nil
            case .oneMinuteLeft:
                return sessionDuration > 60 ? sessionDuration - 60 : nil
            }
        }
    }
}

struct DailyReminderSettings: Codable {
    var isEnabled: Bool = false
    var reminders: [DailyReminder] = []
    
    struct DailyReminder: Codable, Identifiable, Equatable {
        let id = UUID()
        var time: Date
        var isEnabled: Bool = true
        var message: String = "Time for your daily meditation 🧘‍♀️"
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: time)
        }
        
        private enum CodingKeys: String, CodingKey {
            case time, isEnabled, message
        }
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "MindfulBooSettings"
    
    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
        } else {
            self.settings = AppSettings.default
        }
    }
    
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            print("Settings saved successfully")
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    // MARK: - Session Notification Settings
    
    func updateSessionNotificationInterval(_ interval: SessionNotificationSettings.NotificationInterval) {
        settings.sessionNotifications.intervalType = interval
        saveSettings()
    }
    
    func toggleProgressNotification(_ notification: SessionNotificationSettings.ProgressNotification) {
        if settings.sessionNotifications.progressNotifications.contains(notification) {
            settings.sessionNotifications.progressNotifications.remove(notification)
        } else {
            settings.sessionNotifications.progressNotifications.insert(notification)
        }
        saveSettings()
    }
    
    func toggleSessionNotifications() {
        settings.sessionNotifications.isEnabled.toggle()
        saveSettings()
    }
    
    // MARK: - Daily Reminder Settings
    
    func toggleDailyReminders() {
        settings.dailyReminders.isEnabled.toggle()
        saveSettings()
        
        if settings.dailyReminders.isEnabled {
            scheduleDailyReminders()
        } else {
            cancelDailyReminders()
        }
    }
    
    func addDailyReminder(time: Date, message: String = "Time for your daily meditation 🧘‍♀️") {
        guard settings.dailyReminders.reminders.count < 10 else { return }
        
        let reminder = DailyReminderSettings.DailyReminder(
            time: time,
            message: message
        )
        settings.dailyReminders.reminders.append(reminder)
        saveSettings()
        
        if settings.dailyReminders.isEnabled {
            scheduleDailyReminder(reminder)
        }
    }
    
    func removeDailyReminder(at index: Int) {
        guard index < settings.dailyReminders.reminders.count else { return }
        
        let reminder = settings.dailyReminders.reminders[index]
        settings.dailyReminders.reminders.remove(at: index)
        saveSettings()
        
        cancelDailyReminder(reminder)
    }
    
    func toggleDailyReminder(at index: Int) {
        guard index < settings.dailyReminders.reminders.count else { return }
        
        settings.dailyReminders.reminders[index].isEnabled.toggle()
        saveSettings()
        
        let reminder = settings.dailyReminders.reminders[index]
        if reminder.isEnabled && settings.dailyReminders.isEnabled {
            scheduleDailyReminder(reminder)
        } else {
            cancelDailyReminder(reminder)
        }
    }
    
    func updateDailyReminder(_ reminder: DailyReminderSettings.DailyReminder) {
        guard let index = settings.dailyReminders.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        
        settings.dailyReminders.reminders[index] = reminder
        saveSettings()
        
        // Reschedule the notification
        cancelDailyReminder(reminder)
        if reminder.isEnabled && settings.dailyReminders.isEnabled {
            scheduleDailyReminder(reminder)
        }
    }
    
    // MARK: - Notification Scheduling
    
    private func scheduleDailyReminders() {
        for reminder in settings.dailyReminders.reminders where reminder.isEnabled {
            scheduleDailyReminder(reminder)
        }
    }
    
    private func scheduleDailyReminder(_ reminder: DailyReminderSettings.DailyReminder) {
        let content = UNMutableNotificationContent()
        content.title = "MindfulBoo Reminder"
        content.body = reminder.message
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminder.time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder_\(reminder.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            } else {
                print("Scheduled daily reminder for \(reminder.formattedTime)")
            }
        }
    }
    
    private func cancelDailyReminders() {
        let identifiers = settings.dailyReminders.reminders.map { "daily_reminder_\($0.id.uuidString)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Cancelled all daily reminders")
    }
    
    private func cancelDailyReminder(_ reminder: DailyReminderSettings.DailyReminder) {
        let identifier = "daily_reminder_\(reminder.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled daily reminder for \(reminder.formattedTime)")
    }
}

// MARK: - SessionManager

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
    private var settingsManager: SettingsManager?
    private var currentActivity: Activity<MindfulBooActivityAttributes>?
    
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
    
    func setSettingsManager(_ settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session for critical alarm functionality
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for critical alarm functionality")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupCriticalAudioSession() {
        do {
            // More aggressive audio session for alarm notifications
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .overrideMutedMicrophoneInterruption]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("🚨 Critical audio session activated for alarm")
        } catch {
            print("❌ Failed to setup critical audio session: \(error)")
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
        
        // Setup audio session for background playback
        setupAudioSession()
        
        // Start background task to keep timer running when app is backgrounded
        startBackgroundTask()
        
        // Create new session
        currentSession = Session(
            id: UUID(),
            startDate: Date(),
            duration: duration,
            endDate: nil
        )
        
        // Start Live Activity
        startLiveActivity()
        
        // Request notification permissions and schedule completion notification
        requestNotificationPermissions()
        
        // Setup critical audio session for alarm functionality
        setupCriticalAudioSession()
        
        // Debug: Check current notification settings before scheduling
        checkNotificationSettingsBeforeScheduling {
            self.scheduleSessionCompletionNotification(duration: duration)
        }
        
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
        
        // End background task
        endBackgroundTask()
        
        // End Live Activity
        endLiveActivity()
        
        // Cancel scheduled notification since session is ending
        cancelSessionNotification()
        
        // Complete current session
        completeAndSaveSession()
        
        // Play completion sound
        playCompletionSound()
        
        print("✅ Meditation session stopped - timers synchronized")
    }
    
    // MARK: - Safe Session Completion
    
    private func completeSessionSafely() {
        DispatchQueue.main.async {
            self.stopSession()
        }
    }
    
    private func completeAndSaveSession() {
        guard var session = currentSession else { return }
        
        session.endDate = Date()
        session.actualDuration = Date().timeIntervalSince(session.startDate)
        
        // Save session immediately and robustly
        sessions.append(session)
        saveSessions()
        
        // Force save to UserDefaults immediately
        UserDefaults.standard.synchronize()
        
        // Save to HealthKit as a mindful session
        healthManager?.saveMindfulSession(session)
        
        // Recalculate streak after saving new session
        let streakCount = calculateConsecutiveDays()
        healthManager?.updateConsecutiveDays(streakCount)
        
        // Show save confirmation briefly
        showSessionSavedMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showSessionSavedMessage = false
        }
        
        currentSession = nil
        print("✅ Session completed and saved: \(session.formattedDuration)")
    }
    
    // MARK: - Timer Synchronization Helper
    
    func forceSyncTimers() {
        guard let startTime = startTime, isSessionActive else { return }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let syncedTimeRemaining = max(0, sessionDuration - elapsed)
        let syncedProgress = min(1.0, elapsed / sessionDuration)
        
        timeRemaining = syncedTimeRemaining
        progress = syncedProgress
        
        updateLiveActivity()
        
        // Check if session should have ended while app was in background
        if syncedTimeRemaining <= 0 && isSessionActive {
            print("🔄 Session completed while app was in background - completing session safely")
            completeAndSaveSession()
            
            // Update UI state
            DispatchQueue.main.async {
                self.isSessionActive = false
                self.timer?.invalidate()
                self.timer = nil
            }
            
            // Play completion sound to alert user
            playCompletionSound()
            return
        }
        
        print("🔄 Timers force synchronized - Remaining: \(Int(syncedTimeRemaining))s, Progress: \(Int(syncedProgress * 100))%")
    }
    
    private func updateTimer() {
        guard let startTime = startTime, isSessionActive else { return }
        
        // Use consistent time calculation for both app and widget
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let calculatedTimeRemaining = max(0, sessionDuration - elapsed)
        let calculatedProgress = min(1.0, elapsed / sessionDuration)
        
        // Update properties
        timeRemaining = calculatedTimeRemaining
        progress = calculatedProgress
        
        // Update Live Activity with synchronized timing
        updateLiveActivity()
        
        // Check if session should end
        if timeRemaining <= 0 {
            print("⏰ Session timer reached zero - completing session")
            // Ensure session is saved even if app is backgrounded
            self.completeSessionSafely()
        }
    }
    
    private func playCompletionSound() {
        // Ensure audio session is active for sound playback
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session for completion sound: \(error)")
        }
        
        // Play multiple system sounds for critical alarm functionality
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1327) // Gentle bell sound
        }
        
        // Additional alarm sounds with delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioServicesPlaySystemSound(1327)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AudioServicesPlaySystemSound(1327)
        }
        
        // Strong haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Additional haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            impactFeedback.impactOccurred()
        }
        
        print("🔔 Critical completion sound and haptics played")
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MeditationTimer") {
            // This block is called when the background task is about to expire
            print("⚠️ Background task expiring - ensuring session completion")
            DispatchQueue.main.async {
                // If session is still active, save current progress and schedule a backup notification
                if self.isSessionActive {
                    print("💾 Saving session progress before background task expires")
                    
                    // Force save current session state
                    if var currentSession = self.currentSession {
                        currentSession.endDate = Date()
                        currentSession.actualDuration = Date().timeIntervalSince(currentSession.startDate)
                        
                        // Save the session even if incomplete
                        self.sessions.append(currentSession)
                        self.saveSessions()
                        UserDefaults.standard.synchronize()
                        
                        // Save to HealthKit
                        self.healthManager?.saveMindfulSession(currentSession)
                        
                        print("✅ Session saved before background expiration: \(currentSession.formattedDuration)")
                    }
                    
                    // Schedule a backup notification for when the session should end
                    if self.timeRemaining > 0 {
                        self.scheduleBackupCompletionNotification(remainingTime: self.timeRemaining)
                    }
                }
                self.endBackgroundTask()
            }
        }
        print("🔄 Background task started: \(backgroundTaskID.rawValue)")
    }
    
    private func scheduleBackupCompletionNotification(remainingTime: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "🧘‍♀️ Meditation Complete"
        content.body = "Your meditation session has finished while the app was in background."
        content.sound = UNNotificationSound.default
        content.badge = 1
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime, repeats: false)
        let request = UNNotificationRequest(identifier: "backup_completion", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule backup notification: \(error)")
            } else {
                print("✅ Backup completion notification scheduled for \(Int(remainingTime))s")
            }
        }
        
        // Schedule additional backup notifications at 10-second intervals
        for i in 1...3 {
            let backupContent = UNMutableNotificationContent()
            backupContent.title = "🧘‍♀️ Meditation Complete"
            backupContent.body = "Your meditation session has finished. Tap to return to the app."
            backupContent.sound = UNNotificationSound.default
            backupContent.badge = 1
            
            if #available(iOS 15.0, *) {
                backupContent.interruptionLevel = .timeSensitive
            }
            
            let backupTrigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime + TimeInterval(i * 10), repeats: false)
            let backupRequest = UNNotificationRequest(identifier: "backup_completion_\(i)", content: backupContent, trigger: backupTrigger)
            
            UNUserNotificationCenter.current().add(backupRequest) { error in
                if error == nil {
                    print("✅ Backup alarm \(i) scheduled")
                }
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("🔄 Background task ended")
        }
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity() {
        guard let startTime = startTime else { return }
        
        let sessionEndTime = startTime.addingTimeInterval(sessionDuration)
        let attributes = MindfulBooActivityAttributes(
            sessionDuration: sessionDuration,
            sessionStartTime: startTime
        )
        let initialState = MindfulBooActivityAttributes.ContentState(
            timeRemaining: timeRemaining,
            progress: progress,
            sessionState: .running,
            sessionEndTime: sessionEndTime
        )
        
        do {
            currentActivity = try Activity<MindfulBooActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            print("Live Activity started with end time: \(sessionEndTime)")
        } catch (let error) {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    private func updateLiveActivity() {
        guard let startTime = startTime else { return }
        
        // Calculate the exact end time for consistent timing across app and widget
        let sessionEndTime = startTime.addingTimeInterval(sessionDuration)
        let now = Date()
        let actualTimeRemaining = max(0, sessionEndTime.timeIntervalSince(now))
        
        // Debug logging to track synchronization
        let timeDifference = abs(actualTimeRemaining - timeRemaining)
        if timeDifference > 1.0 { // Log if difference is more than 1 second
            print("⚠️ Timer sync issue detected - App: \(Int(timeRemaining))s, Widget: \(Int(actualTimeRemaining))s, Diff: \(timeDifference)s")
        }
        
        let updatedState = MindfulBooActivityAttributes.ContentState(
            timeRemaining: actualTimeRemaining,
            progress: progress,
            sessionState: .running,
            sessionEndTime: sessionEndTime
        )
        
        Task {
            await currentActivity?.update(using: updatedState)
        }
    }
    
    private func endLiveActivity() {
        guard let startTime = startTime else { return }
        
        let sessionEndTime = startTime.addingTimeInterval(sessionDuration)
        let finalState = MindfulBooActivityAttributes.ContentState(
            timeRemaining: 0,
            progress: 1.0,
            sessionState: .ended,
            sessionEndTime: sessionEndTime
        )
        
        Task {
            await currentActivity?.end(using: finalState, dismissalPolicy: .immediate)
            print("Live Activity ended")
        }
    }
    
    // MARK: - Streak Calculation
    
    func calculateConsecutiveDays() -> Int {
        print("🔍 Calculating consecutive days...")
        
        guard !sessions.isEmpty else {
            print("⚠️ No sessions found, consecutive days = 0")
            return 0
        }
        
        let calendar = Calendar.current
        
        // Group sessions by calendar day (using start date)
        var sessionsByDay: Set<Date> = []
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.startDate)
            sessionsByDay.insert(dayStart)
        }
        
        // Sort session days in descending order (most recent first)
        let sortedDays = sessionsByDay.sorted(by: >)
        
        // Get current time and today's start
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        print("   📅 Sessions found on \(sessionsByDay.count) different days")
        print("   📅 Today: \(DateFormatter.localizedString(from: today, dateStyle: .medium, timeStyle: .none))")
        
        var consecutive = 0
        var currentCheckDate = today
        
        // Start checking from today and go backwards
        while sessionsByDay.contains(currentCheckDate) {
            consecutive += 1
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            print("   ✅ Day \(consecutive): \(formatter.string(from: currentCheckDate))")
            
            // Move to previous day
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentCheckDate) else {
                break
            }
            currentCheckDate = previousDay
        }
        
        // If no session today, check if yesterday has a session (streak continues for today)
        if consecutive == 0 {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if sessionsByDay.contains(yesterday) {
                consecutive = 1
                print("   ✅ Day 1: Yesterday (streak continues for today)")
                
                // Continue counting backwards from yesterday
                var checkDate = calendar.date(byAdding: .day, value: -2, to: today)!
                while sessionsByDay.contains(checkDate) {
                    consecutive += 1
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    print("   ✅ Day \(consecutive): \(formatter.string(from: checkDate))")
                    
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                        break
                    }
                    checkDate = previousDay
                }
            } else {
                print("   ❌ No session today or yesterday - streak broken")
                
                // Show when the last session was for debugging
                if let lastSessionDay = sortedDays.first {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    let daysBetween = calendar.dateComponents([.day], from: lastSessionDay, to: today).day ?? 0
                    print("   📊 Last session was \(daysBetween) day(s) ago: \(formatter.string(from: lastSessionDay))")
                }
            }
        }
        
        print("⚡ Final consecutive days count: \(consecutive)")
        return consecutive
    }
    
    func deleteSession(_ session: Session) {
        // Remove from local storage only (preserve HealthKit data)
        sessions.removeAll { $0.id == session.id }
        saveSessions()
        
        // Recalculate streak after deleting session
        let streakCount = calculateConsecutiveDays()
        healthManager?.updateConsecutiveDays(streakCount)
        
        print("Session deleted from app (HealthKit data preserved)")
    }
    
    func deleteAllSessions() {
        // Delete from local storage only (preserve HealthKit data)
        sessions.removeAll()
        saveSessions()
        
        // Recalculate streak after deleting all sessions
        let streakCount = calculateConsecutiveDays()
        healthManager?.updateConsecutiveDays(streakCount)
        
        print("All sessions deleted from app (HealthKit data preserved)")
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: "MindfulBooSessions")
            
            // Force immediate synchronization to disk
            UserDefaults.standard.synchronize()
            
            print("💾 Sessions saved successfully (\(sessions.count) total)")
        } catch {
            print("❌ Failed to save sessions: \(error)")
            
            // Fallback: try to save individual session data
            if let latestSession = sessions.last {
                let sessionData = [
                    "id": latestSession.id.uuidString,
                    "startDate": latestSession.startDate.timeIntervalSince1970,
                    "duration": latestSession.duration,
                    "endDate": latestSession.endDate?.timeIntervalSince1970 ?? 0,
                    "actualDuration": latestSession.actualDuration ?? 0
                ] as [String : Any]
                
                UserDefaults.standard.set(sessionData, forKey: "LastSession_\(latestSession.id.uuidString)")
                UserDefaults.standard.synchronize()
                print("💾 Fallback: saved latest session individually")
            }
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
    
    // MARK: - Notification Support
    
    private func requestNotificationPermissions() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("✅ Notification permission granted: \(granted)")
                if granted {
                    print("✅ Standard notifications enabled for locked device alarm functionality")
                } else {
                    print("⚠️ Notifications denied - alarm may not work when device is locked")
                }
            }
        }
    }
    
    private func scheduleSessionCompletionNotification(duration: TimeInterval) {
        // Standard alarm notification with maximum effectiveness
        let content = UNMutableNotificationContent()
        content.title = "🧘‍♀️ Meditation Complete"
        content.body = "Your \(Int(duration/60))-minute session has finished. Well done!"
        content.badge = 1
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        content.sound = UNNotificationSound.defaultCritical
        
        // For iOS 15+, use critical interruption level to break through Do Not Disturb and locked screen
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .critical
            content.relevanceScore = 1.0
        }
        
        // Add actions for better user experience
        let completeAction = UNNotificationAction(identifier: "COMPLETE_ACTION", title: "Mark Complete", options: [])
        let extendAction = UNNotificationAction(identifier: "EXTEND_ACTION", title: "Extend 5 min", options: [])
        let category = UNNotificationCategory(identifier: "MEDITATION_COMPLETE", actions: [completeAction, extendAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule completion notification: \(error)")
            } else {
                print("✅ Scheduled time-sensitive completion notification for \(Int(duration/60)) minutes")
            }
        }
        
        // Schedule multiple backup alarms at different intervals to ensure notification
        scheduleBackupAlarms(duration: duration)
        
        // Schedule rapid-fire alarm sequence for locked device scenarios
        scheduleRapidFireAlarms(duration: duration)
        
        // Schedule additional notifications if settings allow
        if let settings = settingsManager?.settings.sessionNotifications, settings.isEnabled {
            scheduleIntervalNotifications(duration: duration, settings: settings)
            scheduleProgressNotifications(duration: duration, settings: settings)
        }
    }
    
    private func scheduleBackupAlarms(duration: TimeInterval) {
        // Schedule multiple backup alarms to ensure the user gets notified
        let backupTimes = [10, 20, 30] // seconds after main notification
        
        for (index, delay) in backupTimes.enumerated() {
            let backupContent = UNMutableNotificationContent()
            backupContent.title = "🚨 Meditation Session Complete"
            backupContent.body = "Your meditation timer has finished. Tap to return to the app."
            backupContent.badge = 1
            backupContent.sound = UNNotificationSound.defaultCritical
            
            // Critical interruption for backup alarms
            if #available(iOS 15.0, *) {
                backupContent.interruptionLevel = .critical
                backupContent.relevanceScore = 1.0
            }
            
            let backupTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: duration + TimeInterval(delay),
                repeats: false
            )
            
            let backupRequest = UNNotificationRequest(
                identifier: "meditation_alarm_backup_\(index)",
                content: backupContent,
                trigger: backupTrigger
            )
            
            UNUserNotificationCenter.current().add(backupRequest) { error in
                if let error = error {
                    print("❌ Failed to schedule backup alarm \(index): \(error)")
                } else {
                    print("✅ Scheduled backup alarm \(index) (\(delay)s delay)")
                }
            }
        }
    }
    
    private func scheduleRapidFireAlarms(duration: TimeInterval) {
        // Schedule rapid-fire alarms to break through iOS power management
        let rapidFireDelays = [0, 3, 6, 9, 12, 15, 20, 25, 30] // seconds after main alarm
        
        for (index, delay) in rapidFireDelays.enumerated() {
            let rapidContent = UNMutableNotificationContent()
            rapidContent.title = "🚨 Meditation Timer Complete"
            rapidContent.body = "Your meditation session has finished. Wake up!"
            rapidContent.badge = 1
            rapidContent.sound = UNNotificationSound.defaultCritical
            
            // Maximum interruption level
            if #available(iOS 15.0, *) {
                rapidContent.interruptionLevel = .critical
                rapidContent.relevanceScore = 1.0
            }
            
            let rapidTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: duration + TimeInterval(delay),
                repeats: false
            )
            
            let rapidRequest = UNNotificationRequest(
                identifier: "meditation_rapid_alarm_\(index)",
                content: rapidContent,
                trigger: rapidTrigger
            )
            
            UNUserNotificationCenter.current().add(rapidRequest) { error in
                if error == nil {
                    print("✅ Scheduled rapid-fire alarm \(index) (\(delay)s delay)")
                }
            }
        }
        
        print("🚨 Scheduled \(rapidFireDelays.count) rapid-fire critical alarms")
    }
    
    private func scheduleIntervalNotifications(duration: TimeInterval, settings: SessionNotificationSettings) {
        guard settings.intervalType != .none else { return }
        
        let intervalSeconds = settings.intervalType.intervalSeconds
        let totalIntervals = Int(duration / intervalSeconds)
        
        print("Scheduling \(totalIntervals) interval notifications every \(Int(intervalSeconds/60)) minutes")
        
        for i in 1...totalIntervals {
            let notificationTime = TimeInterval(i) * intervalSeconds
            
            // Don't schedule if it's too close to the end (within 30 seconds)
            if notificationTime >= duration - 30 { break }
            
            let content = UNMutableNotificationContent()
            content.title = "🧘‍♀️ Meditation Check-in"
            
            let remainingMinutes = Int((duration - notificationTime) / 60)
            if remainingMinutes > 0 {
                content.body = "\(remainingMinutes) minutes remaining - Stay focused on your breath"
            } else {
                content.body = "Almost done - Stay present"
            }
            
            content.sound = UNNotificationSound.default
            content.badge = nil
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationTime, repeats: false)
            let request = UNNotificationRequest(
                identifier: "interval_\(i)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule interval notification \(i): \(error)")
                } else {
                    print("Scheduled interval notification \(i)")
                }
            }
        }
    }
    
    private func scheduleProgressNotifications(duration: TimeInterval, settings: SessionNotificationSettings) {
        guard !settings.progressNotifications.isEmpty else { return }
        
        print("Scheduling \(settings.progressNotifications.count) progress notifications")
        
        for progressNotification in settings.progressNotifications {
            guard let notificationTime = progressNotification.getNotificationTime(for: duration) else {
                print("Skipping \(progressNotification.displayName) - session too short")
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🧘‍♀️ Meditation Progress"
            
            switch progressNotification {
            case .percent25:
                content.body = "25% complete - You're doing great!"
            case .percent50:
                content.body = "Halfway through - Keep going!"
            case .percent75:
                content.body = "75% complete - Almost there!"
            case .twoMinutesLeft:
                content.body = "2 minutes remaining - Stay present"
            case .oneMinuteLeft:
                content.body = "1 minute remaining - Finish strong"
            }
            
            content.sound = UNNotificationSound.default
            content.badge = nil
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationTime, repeats: false)
            let request = UNNotificationRequest(
                identifier: "progress_\(progressNotification.rawValue)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule progress notification \(progressNotification.displayName): \(error)")
                } else {
                    print("Scheduled progress notification: \(progressNotification.displayName)")
                }
            }
        }
    }
    
    private func cancelSessionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        
        // Cancel backup completion notifications
        let backupIds = ["backup_completion", "backup_completion_1", "backup_completion_2", "backup_completion_3"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: backupIds)
        
        // Cancel new backup alarms
        let backupAlarmIds = (0...2).map { "meditation_alarm_backup_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: backupAlarmIds)
        
        // Cancel rapid-fire alarms
        let rapidFireAlarmIds = (0...8).map { "meditation_rapid_alarm_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: rapidFireAlarmIds)
        
        // Cancel all session-related notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let sessionIds = requests.compactMap { request in
                request.identifier.hasPrefix("interval_") || 
                request.identifier.hasPrefix("progress_") ? request.identifier : nil
            }
            
            if !sessionIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: sessionIds)
                print("Cancelled \(sessionIds.count) session notifications")
            }
        }
        
        print("Cancelled all session notifications, backup completion, and backup alarms")
    }
    
    private func checkNotificationSettingsBeforeScheduling(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("\n🔔 PRE-SCHEDULING NOTIFICATION CHECK:")
            print("   Authorization: \(settings.authorizationStatus.rawValue) (2 = authorized)")
            print("   Sound: \(settings.soundSetting.rawValue) (2 = enabled)")
            print("   Lock Screen: \(settings.lockScreenSetting.rawValue) (2 = enabled)")
            
            if #available(iOS 15.0, *) {
                print("   Time Sensitive: \(settings.timeSensitiveSetting.rawValue) (2 = enabled)")
            }
            
            let canSendNotifications = settings.authorizationStatus == .authorized
            let canPlaySound = settings.soundSetting == .enabled
            let canShowOnLockScreen = settings.lockScreenSetting == .enabled
            
            if canSendNotifications && canPlaySound && canShowOnLockScreen {
                print("✅ All notification settings optimal for alarm functionality")
            } else {
                print("⚠️ ALARM WARNING: Some notification settings may prevent alarm from working properly")
                if !canSendNotifications { print("   - Notifications not authorized") }
                if !canPlaySound { print("   - Sound not enabled") }
                if !canShowOnLockScreen { print("   - Lock screen display not enabled") }
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

import AudioToolbox

// MARK: - EditReminderView

struct EditReminderView: View {
    @State private var reminder: DailyReminderSettings.DailyReminder
    let onSave: (DailyReminderSettings.DailyReminder) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    init(reminder: DailyReminderSettings.DailyReminder, onSave: @escaping (DailyReminderSettings.DailyReminder) -> Void) {
        _reminder = State(initialValue: reminder)
        self.onSave = onSave
    }
    
    private let defaultMessages = [
        "Time for your daily meditation 🧘‍♀️",
        "Take a moment to breathe and center yourself 🌸",
        "Your mindfulness practice awaits ✨",
        "Time to find your inner peace 🕯️",
        "A few minutes of meditation can transform your day 🌅",
        "Your mental wellness matters - take a meditation break 💚",
        "Pause, breathe, and reconnect with yourself 🍃"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time picker with Liquid Glass
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminder Time")
                            .font(.headline)
                        
                        DatePicker("Time", selection: $reminder.time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Liquid Glass time picker background
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .opacity(0.9)
                            
                            // Glass highlight
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear,
                                            Color.orange.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                    )
                    
                    // Message input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Message")
                            .font(.headline)
                        
                        TextField("Reminder message", text: $reminder.message, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3)
                        
                        Text("Suggested messages:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(defaultMessages, id: \.self) { defaultMessage in
                                    Button(defaultMessage) {
                                        reminder.message = defaultMessage
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        ZStack {
                                            // Liquid Glass suggestion button
                                            Capsule()
                                                .fill(.thinMaterial)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.2))
                                                )
                                            
                                            // Glass highlight
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.4),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                    )
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Reminder")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave(reminder)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom tab picker with Liquid Glass
                HStack(spacing: 4) {
                    TabButton(
                        title: "Session",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: "Daily Reminders",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        // Liquid Glass tab bar background
                        Capsule()
                            .fill(.thinMaterial)
                            .opacity(0.8)
                            .frame(height: 44) // Fixed height for consistent alignment
                        
                        // Glass highlight
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 44)
                    }
                    .padding(.horizontal)
                )
                
                // Tab content
                TabView(selection: $selectedTab) {
                    SessionNotificationSettingsView()
                        .tag(0)
                    
                    DailyReminderSettingsView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(height: 40) // Fixed height for proper alignment
                .padding(.horizontal, 16)
                .background(
                    ZStack {
                        if isSelected {
                            // Selected state with Liquid Glass
                            Capsule()
                                .fill(.regularMaterial)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            
                            // Glass highlight for selected tab
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.overlay)
                        } else {
                            // Unselected state - subtle glass
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.3)
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Session Notification Settings

struct SessionNotificationSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Notifications")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure how often you receive notifications during your meditation sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Enable/Disable toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session Notifications")
                                .font(.headline)
                            Text("Enable notifications during meditation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsManager.settings.sessionNotifications.isEnabled },
                            set: { _ in settingsManager.toggleSessionNotifications() }
                        ))
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Liquid Glass settings card
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .opacity(0.9)
                            
                            // Glass highlight
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear,
                                            Color.blue.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                    )
                }
                .padding(.horizontal)
                
                if settingsManager.settings.sessionNotifications.isEnabled {
                    // Interval notifications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Interval Notifications")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(SessionNotificationSettings.NotificationInterval.allCases, id: \.self) { interval in
                                IntervalOptionRow(
                                    interval: interval,
                                    isSelected: settingsManager.settings.sessionNotifications.intervalType == interval
                                ) {
                                    settingsManager.updateSessionNotificationInterval(interval)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Progress notifications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Notifications")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Get notified at specific points during your session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(SessionNotificationSettings.ProgressNotification.allCases, id: \.self) { notification in
                                ProgressNotificationRow(
                                    notification: notification,
                                    isEnabled: settingsManager.settings.sessionNotifications.progressNotifications.contains(notification)
                                ) {
                                    settingsManager.toggleProgressNotification(notification)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
}

struct IntervalOptionRow: View {
    let interval: SessionNotificationSettings.NotificationInterval
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(interval.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if interval != .none {
                        Text("Every \(Int(interval.intervalSeconds / 60)) minute\(interval.intervalSeconds == 60 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No interval notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? .thinMaterial : .ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                        )
                    
                    // Glass highlight
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.3 : 0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glass border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressNotificationRow: View {
    let notification: SessionNotificationSettings.ProgressNotification
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(notification.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                ZStack {
                    // Base glass material for progress notifications
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isEnabled ? .thinMaterial : .ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isEnabled ? Color.blue.opacity(0.2) : Color.clear)
                        )
                    
                    // Glass highlight
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isEnabled ? 0.3 : 0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Glass border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isEnabled ? Color.blue.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: isEnabled ? 1.5 : 0.5
                        )
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Daily Reminder Settings

struct DailyReminderSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAddReminder = false
    @State private var newReminderTime = Date()
    @State private var newReminderMessage = "Time for your daily meditation 🧘‍♀️"
    @State private var reminderToEdit: DailyReminderSettings.DailyReminder?
    
    // Computed property to sort reminders by time
    private var sortedReminders: [DailyReminderSettings.DailyReminder] {
        settingsManager.settings.dailyReminders.reminders.sorted { reminder1, reminder2 in
            let calendar = Calendar.current
            let time1 = calendar.dateComponents([.hour, .minute], from: reminder1.time)
            let time2 = calendar.dateComponents([.hour, .minute], from: reminder2.time)
            
            if time1.hour != time2.hour {
                return (time1.hour ?? 0) < (time2.hour ?? 0)
            }
            return (time1.minute ?? 0) < (time2.minute ?? 0)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Reminders")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Set up to 10 daily reminders to help you maintain your meditation practice.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Enable/Disable toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Reminders")
                                .font(.headline)
                            Text("Enable daily meditation reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsManager.settings.dailyReminders.isEnabled },
                            set: { _ in settingsManager.toggleDailyReminders() }
                        ))
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Liquid Glass daily reminders card
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .opacity(0.9)
                            
                            // Glass highlight with green tint
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear,
                                            Color.green.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                    )
                }
                .padding(.horizontal)
                
                if settingsManager.settings.dailyReminders.isEnabled {
                    // Add reminder button
                    if settingsManager.settings.dailyReminders.reminders.count < 10 {
                        Button(action: { showingAddReminder = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Reminder")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Reminders list
                    if !settingsManager.settings.dailyReminders.reminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Reminders")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(sortedReminders.enumerated()), id: \.element.id) { index, reminder in
                                let originalIndex = settingsManager.settings.dailyReminders.reminders.firstIndex(where: { $0.id == reminder.id }) ?? 0
                                DailyReminderRow(
                                    reminder: reminder,
                                    isEnabled: reminder.isEnabled,
                                    onToggle: { settingsManager.toggleDailyReminder(at: originalIndex) },
                                    onDelete: { settingsManager.removeDailyReminder(at: originalIndex) },
                                    onEdit: {
                                        reminderToEdit = reminder
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No reminders set")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add your first reminder to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(
                time: $newReminderTime,
                message: $newReminderMessage,
                onSave: {
                    settingsManager.addDailyReminder(time: newReminderTime, message: newReminderMessage)
                    showingAddReminder = false
                    // Reset for next time
                    newReminderTime = Date()
                    newReminderMessage = "Time for your daily meditation 🧘‍♀️"
                }
            )
        }
        .sheet(item: $reminderToEdit) { reminder in
            EditReminderView(
                reminder: reminder,
                onSave: { editedReminder in
                    settingsManager.updateDailyReminder(editedReminder)
                }
            )
        }
    }
}

struct DailyReminderRow: View {
    let reminder: DailyReminderSettings.DailyReminder
    let isEnabled: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.formattedTime)
                    .font(.headline)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Text(reminder.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                // Liquid Glass reminder row
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? .thinMaterial : .ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isEnabled ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                
                // Glass highlight
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isEnabled ? 0.2 : 0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.white.opacity(isEnabled ? 0.2 : 0.1),
                        lineWidth: 0.5
                    )
            }
        )
    }
}

struct AddReminderView: View {
    @Binding var time: Date
    @Binding var message: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    private let defaultMessages = [
        "Time for your daily meditation 🧘‍♀️",
        "Take a moment to breathe and center yourself 🌸",
        "Your mindfulness practice awaits ✨",
        "Time to find your inner peace 🕯️",
        "A few minutes of meditation can transform your day 🌅",
        "Your mental wellness matters - take a meditation break 💚",
        "Pause, breathe, and reconnect with yourself 🍃"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time picker with Liquid Glass
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminder Time")
                            .font(.headline)
                        
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Liquid Glass time picker background
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .opacity(0.9)
                            
                            // Glass highlight
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear,
                                            Color.orange.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            // Glass border
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                    )
                    
                    // Message input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Message")
                            .font(.headline)
                        
                        TextField("Reminder message", text: $message, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3)
                        
                        Text("Suggested messages:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(defaultMessages, id: \.self) { defaultMessage in
                                    Button(defaultMessage) {
                                        message = defaultMessage
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        ZStack {
                                            // Liquid Glass suggestion button
                                            Capsule()
                                                .fill(.thinMaterial)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.blue.opacity(0.2))
                                                )
                                            
                                            // Glass highlight
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.4),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                    )
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Reminder")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}

// MARK: - State of Mind Models

enum StateOfMindEmotion: String, CaseIterable, Identifiable {
    case amazed = "amazed"
    case amused = "amused"
    case angry = "angry"
    case annoyed = "annoyed"
    case anxious = "anxious"
    case ashamed = "ashamed"
    case brave = "brave"
    case calm = "calm"
    case confident = "confident"
    case content = "content"
    case determined = "determined"
    case disappointed = "disappointed"
    case disgusted = "disgusted"
    case embarrassed = "embarrassed"
    case excited = "excited"
    case frustrated = "frustrated"
    case grateful = "grateful"
    case happy = "happy"
    case hopeful = "hopeful"
    case indifferent = "indifferent"
    case irritated = "irritated"
    case jealous = "jealous"
    case joyful = "joyful"
    case lonely = "lonely"
    case passionate = "passionate"
    case peaceful = "peaceful"
    case pleased = "pleased"
    case proud = "proud"
    case relieved = "relieved"
    case sad = "sad"
    case scared = "scared"
    case stressed = "stressed"
    case surprised = "surprised"
    case worried = "worried"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var emoji: String {
        switch self {
        case .amazed: return "🤩"
        case .amused: return "😄"
        case .angry: return "😠"
        case .annoyed: return "😤"
        case .anxious: return "😰"
        case .ashamed: return "😳"
        case .brave: return "💪"
        case .calm: return "😌"
        case .confident: return "😎"
        case .content: return "😊"
        case .determined: return "😤"
        case .disappointed: return "😞"
        case .disgusted: return "🤢"
        case .embarrassed: return "😅"
        case .excited: return "🤗"
        case .frustrated: return "😫"
        case .grateful: return "🙏"
        case .happy: return "😊"
        case .hopeful: return "🌟"
        case .indifferent: return "😐"
        case .irritated: return "😒"
        case .jealous: return "😡"
        case .joyful: return "😄"
        case .lonely: return "😔"
        case .passionate: return "🔥"
        case .peaceful: return "☮️"
        case .pleased: return "😌"
        case .proud: return "🦚"
        case .relieved: return "😌"
        case .sad: return "😢"
        case .scared: return "😨"
        case .stressed: return "😩"
        case .surprised: return "😲"
        case .worried: return "😟"
        }
    }
    
    var category: StateOfMindCategory {
        switch self {
        case .happy, .joyful, .content, .pleased, .grateful, .excited, .amazed, .amused:
            return .positive
        case .calm, .peaceful, .confident, .relieved, .hopeful, .determined, .brave:
            return .balanced
        case .sad, .lonely, .disappointed, .worried, .anxious, .scared, .stressed:
            return .negative
        case .angry, .frustrated, .annoyed, .irritated, .disgusted, .jealous:
            return .challenging
        case .indifferent, .ashamed, .embarrassed:
            return .neutral
        case .passionate, .surprised, .proud:
            return .intense
        }
    }
}

enum StateOfMindCategory: String, CaseIterable {
    case positive = "positive"
    case balanced = "balanced" 
    case negative = "negative"
    case challenging = "challenging"
    case neutral = "neutral"
    case intense = "intense"
    
    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .balanced: return "Balanced"
        case .negative: return "Difficult"
        case .challenging: return "Challenging"
        case .neutral: return "Neutral"
        case .intense: return "Intense"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .balanced: return .blue
        case .negative: return .purple
        case .challenging: return .red
        case .neutral: return .gray
        case .intense: return .orange
        }
    }
}

enum StateOfMindKind: String, CaseIterable, Codable {
    case dailyMood = "dailyMood"
    case momentaryEmotion = "momentaryEmotion"
    
    var displayName: String {
        switch self {
        case .dailyMood: return "Overall Day Mood"
        case .momentaryEmotion: return "Current Feeling"
        }
    }
    
    var description: String {
        switch self {
        case .dailyMood: return "How you've been feeling throughout the day"
        case .momentaryEmotion: return "How you're feeling right now in this moment"
        }
    }
    
    var icon: String {
        switch self {
        case .dailyMood: return "calendar.circle.fill"
        case .momentaryEmotion: return "clock.circle.fill"
        }
    }
}

struct StateOfMindEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let emotion: String // Store raw value for compatibility
    let valence: Double // -1 (very unpleasant) to 1 (very pleasant)
    let labels: [String]
    let kind: String // Store as string for compatibility
    
    init(emotion: StateOfMindEmotion, valence: Double, labels: [StateOfMindEmotion] = [], kind: StateOfMindKind = .momentaryEmotion) {
        self.id = UUID()
        self.date = Date()
        self.emotion = emotion.rawValue
        self.valence = valence
        self.labels = labels.map { $0.rawValue }
        self.kind = kind.rawValue
    }
}

// MARK: - State of Mind Logging UI

struct StateOfMindLoggingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var healthStore: HealthKitManager
    
    @State private var selectedEmotion: StateOfMindEmotion?
    @State private var valence: Double = 0.0
    @State private var selectedLabels: Set<StateOfMindEmotion> = []
    @State private var searchText = ""
    @State private var showingSuccessMessage = false
    @State private var selectedCategory: StateOfMindCategory? = nil
    @State private var selectedKind: StateOfMindKind = .momentaryEmotion
    
    private let emotionsByCategory: [StateOfMindCategory: [StateOfMindEmotion]] = {
        Dictionary(grouping: StateOfMindEmotion.allCases, by: { $0.category })
    }()
    
    private var filteredCategories: [StateOfMindCategory] {
        if let selectedCategory = selectedCategory {
            return [selectedCategory]
        }
        return StateOfMindCategory.allCases
    }
    
    private var filteredEmotions: [StateOfMindEmotion] {
        let emotions: [StateOfMindEmotion]
        
        if let selectedCategory = selectedCategory {
            emotions = emotionsByCategory[selectedCategory] ?? []
        } else {
            emotions = StateOfMindEmotion.allCases
        }
        
        if searchText.isEmpty {
            return emotions
        } else {
            return emotions.filter { emotion in
                emotion.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How are you feeling?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if #available(iOS 18.0, *) {
                            Text("Log your current state of mind to track your emotional wellbeing in the Health app.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Log your current state of mind to track your emotional wellbeing. Health app sync coming with iOS 18.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Kind Selector (Daily Mood vs Momentary Emotion)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What are you logging?")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(StateOfMindKind.allCases, id: \.self) { kind in
                                Button(action: {
                                    selectedKind = kind
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: kind.icon)
                                            .font(.title2)
                                            .foregroundColor(selectedKind == kind ? .white : .primary)
                                        
                                        Text(kind.displayName)
                                            .font(.headline)
                                            .foregroundColor(selectedKind == kind ? .white : .primary)
                                        
                                        Text(kind.description)
                                            .font(.caption)
                                            .foregroundColor(selectedKind == kind ? .white.opacity(0.8) : .secondary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selectedKind == kind ? .blue : .gray.opacity(0.1))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(.thinMaterial)
                                                )
                                            
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(selectedKind == kind ? 0.4 : 0.2),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                            
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    selectedKind == kind ? .blue : Color.white.opacity(0.1),
                                                    lineWidth: selectedKind == kind ? 2 : 0.5
                                                )
                                        }
                                    )
                                }
                                .scaleEffect(selectedKind == kind ? 1.02 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedKind)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // All button
                            Button("All") {
                                selectedCategory = nil
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(selectedCategory == nil ? .blue.opacity(0.2) : .gray.opacity(0.1))
                                        .background(
                                            Capsule()
                                                .fill(.thinMaterial)
                                        )
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            )
                            .foregroundColor(selectedCategory == nil ? .blue : .primary)
                            
                            ForEach(StateOfMindCategory.allCases, id: \.self) { category in
                                Button(category.displayName) {
                                    selectedCategory = category
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(selectedCategory == category ? category.color.opacity(0.2) : .gray.opacity(0.1))
                                            .background(
                                                Capsule()
                                                    .fill(.thinMaterial)
                                            )
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                )
                                .foregroundColor(selectedCategory == category ? category.color : .primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // Emotions Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(filteredEmotions) { emotion in
                            EmotionCard(
                                emotion: emotion,
                                isSelected: selectedEmotion == emotion,
                                isSecondarySelected: selectedLabels.contains(emotion)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedEmotion == emotion {
                                        selectedEmotion = nil
                                    } else {
                                        selectedEmotion = emotion
                                        // Auto-set valence based on emotion category
                                        switch emotion.category {
                                        case .positive: valence = 0.7
                                        case .balanced: valence = 0.2
                                        case .negative: valence = -0.6
                                        case .challenging: valence = -0.8
                                        case .neutral: valence = 0.0
                                        case .intense: valence = 0.5
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Valence Slider
                    if selectedEmotion != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How pleasant is this feeling?")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Very Unpleasant")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("Very Pleasant")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $valence, in: -1...1, step: 0.1)
                                    .accentColor(valence >= 0 ? .green : .red)
                                
                                Text("Current: \(valence >= 0 ? "+" : "")\(String(format: "%.1f", valence))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                                    .opacity(0.9)
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                (valence >= 0 ? Color.green : Color.red).opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        Color.white.opacity(0.1),
                                        lineWidth: 1
                                    )
                            }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Save Button
                    if selectedEmotion != nil {
                        Button(action: saveStateOfMind) {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Log State of Mind")
                                    .fontWeight(.semibold)
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.pink,
                                                    Color.purple,
                                                    Color.blue
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(.thinMaterial)
                                        .opacity(0.3)
                                    
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.clear,
                                                    Color.white.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .blendMode(.overlay)
                                }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("State of Mind")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .overlay(
            // Success message overlay
            VStack {
                Spacer()
                if showingSuccessMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        if #available(iOS 18.0, *) {
                            Text("\(selectedKind.displayName) logged to Health app")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text("\(selectedKind.displayName) logged successfully")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.green.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingSuccessMessage)
                    .padding(.bottom, 100)
                }
            }
        )
    }
    
    private func saveStateOfMind() {
        guard let selectedEmotion = selectedEmotion else { return }
        
        let entry = StateOfMindEntry(
            emotion: selectedEmotion,
            valence: valence,
            labels: Array(selectedLabels),
            kind: selectedKind
        )
        
        healthStore.saveStateOfMind(entry)
        
        // Show success message
        showingSuccessMessage = true
        
        // Dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            presentationMode.wrappedValue.dismiss()
        }
        
        // Hide success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showingSuccessMessage = false
        }
    }
}

struct EmotionCard: View {
    let emotion: StateOfMindEmotion
    let isSelected: Bool
    let isSecondarySelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emotion.emoji)
                    .font(.title)
                
                Text(emotion.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? emotion.category.color : .gray.opacity(0.1))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thinMaterial)
                        )
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.4 : 0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? emotion.category.color : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 2 : 0.5
                        )
                }
            )
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search emotions...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.thinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.gray.opacity(0.1))
                    )
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
    }
}

