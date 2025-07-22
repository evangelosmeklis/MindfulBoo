import Foundation
import Combine
import AVFoundation
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
        
        // Start Live Activity
        startLiveActivity()
        
        // Request notification permissions and schedule completion notification
        requestNotificationPermissions()
        scheduleSessionCompletionNotification(duration: duration)
        
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
        
        // End Live Activity
        endLiveActivity()
        
        // Cancel scheduled notification since session is ending
        cancelSessionNotification()
        
        // Complete current session
        if var session = currentSession {
            session.endDate = Date()
            session.actualDuration = Date().timeIntervalSince(session.startDate)
            
            // Save session
            sessions.append(session)
            saveSessions()
            
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
        }
        
        // Play completion sound
        playCompletionSound()
        
        print("✅ Meditation session stopped - timers synchronized")
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
        print("🔍 Calculating consecutive days from session history...")
        
        guard !sessions.isEmpty else {
            print("⚠️ No sessions found, consecutive days = 0")
            return 0
        }
        
        let calendar = Calendar.current
        var consecutive = 0
        
        // Group sessions by day (using start date)
        var sessionsByDay: Set<Date> = []
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.startDate)
            sessionsByDay.insert(dayStart)
        }
        
        // Sort days in descending order (most recent first)
        let sortedDays = Array(sessionsByDay).sorted(by: >)
        
        // Check if there's a session today
        let today = calendar.startOfDay(for: Date())
        
        if sessionsByDay.contains(today) {
            // There's a session today - start counting from today
            consecutive = 1
            print("   ✅ Day \(consecutive): Today")
            
            // Check previous days for consecutive streak
            var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            
            while sessionsByDay.contains(checkDate) {
                consecutive += 1
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                print("   ✅ Day \(consecutive): \(formatter.string(from: checkDate))")
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
        } else {
            // No session today - check if we can continue streak from yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            
            if sessionsByDay.contains(yesterday) {
                // There was a session yesterday - streak continues (today hasn't ended yet)
                consecutive = 1
                print("   ✅ Day \(consecutive): Yesterday (today hasn't ended yet)")
                
                // Check days before yesterday for consecutive streak
                var checkDate = calendar.date(byAdding: .day, value: -2, to: today)!
                
                while sessionsByDay.contains(checkDate) {
                    consecutive += 1
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    print("   ✅ Day \(consecutive): \(formatter.string(from: checkDate))")
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                }
            } else {
                // No session yesterday either - check if streak should be broken
                if let lastSessionDay = sortedDays.first {
                    let daysSinceLastSession = calendar.dateComponents([.day], from: lastSessionDay, to: today).day ?? 0
                    
                    if daysSinceLastSession <= 1 {
                        // Last session was yesterday or today - maintain streak
                        consecutive = 1
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        print("   ✅ Day \(consecutive): \(formatter.string(from: lastSessionDay)) (within 24 hours)")
                        
                        // Check previous days
                        var checkDate = calendar.date(byAdding: .day, value: -1, to: lastSessionDay)!
                        
                        while sessionsByDay.contains(checkDate) {
                            consecutive += 1
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            print("   ✅ Day \(consecutive): \(formatter.string(from: checkDate))")
                            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                        }
                    } else {
                        // More than a day has passed - streak is broken
                        consecutive = 0
                        print("   ❌ More than 24 hours since last session - streak broken")
                    }
                } else {
                    // No sessions at all
                    consecutive = 0
                    print("   ❌ No sessions found - streak is 0")
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
    
    // MARK: - Notification Support
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    private func scheduleSessionCompletionNotification(duration: TimeInterval) {
        guard let settings = settingsManager?.settings.sessionNotifications,
              settings.isEnabled else {
            print("Session notifications disabled, skipping notification scheduling")
            return
        }
        
        // Always schedule completion notification
        let content = UNMutableNotificationContent()
        content.title = "🧘‍♀️ Meditation Complete"
        content.body = "Your \(Int(duration/60))-minute session has finished. Well done!"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            } else {
                print("Scheduled completion notification for \(duration/60) minutes")
            }
        }
        
        // Schedule interval notifications based on settings
        scheduleIntervalNotifications(duration: duration, settings: settings)
        
        // Schedule progress notifications based on settings
        scheduleProgressNotifications(duration: duration, settings: settings)
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
        
        print("Cancelled session notifications")
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
                    // Time picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminder Time")
                            .font(.headline)
                        
                        DatePicker("Time", selection: $reminder.time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                    
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
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(16)
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
                // Custom tab picker
                HStack(spacing: 0) {
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
                .padding(.top, 8)
                
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
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? Color.blue : Color.clear, lineWidth: 1)
                    )
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
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
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
                            
                            ForEach(Array(settingsManager.settings.dailyReminders.reminders.enumerated()), id: \.element.id) { index, reminder in
                                DailyReminderRow(
                                    reminder: reminder,
                                    isEnabled: reminder.isEnabled,
                                    onToggle: { settingsManager.toggleDailyReminder(at: index) },
                                    onDelete: { settingsManager.removeDailyReminder(at: index) },
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
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? Color(.systemGray6) : Color(.systemGray5))
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
                    // Time picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reminder Time")
                            .font(.headline)
                        
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                    
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
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(16)
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

