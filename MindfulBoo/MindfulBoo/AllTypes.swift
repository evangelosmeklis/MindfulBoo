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

enum AppearanceMode: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil // Uses system setting
        }
    }
}

// MARK: - Mindfulness Reminder Types

enum MindfulnessInterval: Int, Codable, CaseIterable {
    case every30min = 30
    case every1hour = 60
    case every2hours = 120
    case every3hours = 180
    case every4hours = 240

    var displayName: String {
        switch self {
        case .every30min: return "every 30 min"
        case .every1hour: return "every hour"
        case .every2hours: return "every 2 hours"
        case .every3hours: return "every 3 hours"
        case .every4hours: return "every 4 hours"
        }
    }
}

enum MindfulnessMode: String, Codable, CaseIterable {
    case window = "window"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .window: return "time window"
        case .custom: return "custom times"
        }
    }
}

struct MindfulnessCustomTime: Codable, Identifiable, Equatable {
    let id: UUID
    var time: Date

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    init(id: UUID = UUID(), time: Date) {
        self.id = id
        self.time = time
    }
}

struct MindfulnessReminderSettings: Codable {
    var isEnabled: Bool = false
    var mode: MindfulnessMode = .window
    var windowStart: Date
    var windowEnd: Date
    var interval: MindfulnessInterval = .every1hour
    var customTimes: [MindfulnessCustomTime] = []

    init() {
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.hour = 9
        startComponents.minute = 0
        windowStart = calendar.date(from: startComponents) ?? Date()

        var endComponents = DateComponents()
        endComponents.hour = 21
        endComponents.minute = 0
        windowEnd = calendar.date(from: endComponents) ?? Date()
    }
}

struct AppSettings: Codable {
    var sessionNotifications: SessionNotificationSettings
    var dailyReminders: DailyReminderSettings
    var mindfulnessReminders: MindfulnessReminderSettings
    var appearanceMode: AppearanceMode = .auto

    static let `default` = AppSettings(
        sessionNotifications: SessionNotificationSettings(),
        dailyReminders: DailyReminderSettings(),
        mindfulnessReminders: MindfulnessReminderSettings(),
        appearanceMode: .auto
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
    
    private let mindfulnessMessages: [String] = [
        "pause. take a slow breath. notice where you are.",
        "soften your shoulders and unclench your jaw.",
        "what can you feel right now? just notice.",
        "let your next exhale be a little longer.",
        "look up from your screen for a moment.",
        "notice three things you can hear right now.",
        "feel your feet on the ground beneath you.",
        "take one conscious breath before you continue.",
        "are you rushing? you can slow down.",
        "notice the temperature of the air around you.",
        "release any tension you're holding in your face.",
        "you are here. this moment is enough.",
        "check in with your body. what does it need?",
        "let go of the last thing. this is now.",
        "breathe in slowly. breathe out completely.",
        "where is your attention right now?",
        "soften your gaze for just one breath.",
        "nothing to do for this one breath.",
        "notice the weight of your body where you sit.",
        "this is a moment of rest. let it be."
    ]

    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
        } else {
            self.settings = AppSettings.default
        }
        rescheduleMindfulnessNotifications()
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

    // MARK: - Appearance Settings

    func updateAppearanceMode(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
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
        // First check if we have notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("⚠️ Cannot schedule daily reminder - notifications not authorized")
                // Request permissions for future use
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
                    if granted {
                        // Retry scheduling after permission is granted
                        self.scheduleDailyReminder(reminder)
                    }
                }
                return
            }

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

    // MARK: - Mindfulness Reminder Settings

    func toggleMindfulnessReminders() {
        settings.mindfulnessReminders.isEnabled.toggle()
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func updateMindfulnessMode(_ mode: MindfulnessMode) {
        settings.mindfulnessReminders.mode = mode
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func updateMindfulnessWindowStart(_ date: Date) {
        settings.mindfulnessReminders.windowStart = date
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func updateMindfulnessWindowEnd(_ date: Date) {
        settings.mindfulnessReminders.windowEnd = date
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func updateMindfulnessInterval(_ interval: MindfulnessInterval) {
        settings.mindfulnessReminders.interval = interval
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func addMindfulnessCustomTime(_ time: Date) {
        settings.mindfulnessReminders.customTimes.append(MindfulnessCustomTime(time: time))
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    func removeMindfulnessCustomTime(at index: Int) {
        guard index < settings.mindfulnessReminders.customTimes.count else { return }
        settings.mindfulnessReminders.customTimes.remove(at: index)
        saveSettings()
        rescheduleMindfulnessNotifications()
    }

    private func rescheduleMindfulnessNotifications() {
        cancelMindfulnessNotifications()

        guard settings.mindfulnessReminders.isEnabled else { return }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] notifSettings in
            guard let self = self else { return }
            guard notifSettings.authorizationStatus == .authorized ||
                  notifSettings.authorizationStatus == .provisional else { return }

            let remSettings = self.settings.mindfulnessReminders
            var slots: [DateComponents] = []

            if remSettings.mode == .window {
                let calendar = Calendar.current
                let startComps = calendar.dateComponents([.hour, .minute], from: remSettings.windowStart)
                let endComps = calendar.dateComponents([.hour, .minute], from: remSettings.windowEnd)
                let startMinutes = (startComps.hour ?? 9) * 60 + (startComps.minute ?? 0)
                let endMinutes = (endComps.hour ?? 21) * 60 + (endComps.minute ?? 0)
                let step = remSettings.interval.rawValue
                var current = startMinutes
                while current <= endMinutes {
                    var comps = DateComponents()
                    comps.hour = current / 60
                    comps.minute = current % 60
                    slots.append(comps)
                    current += step
                }
            } else {
                for customTime in remSettings.customTimes {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: customTime.time)
                    slots.append(comps)
                }
            }

            for (index, slot) in slots.enumerated() {
                let message = self.mindfulnessMessages[index % self.mindfulnessMessages.count]
                let content = UNMutableNotificationContent()
                content.title = "mindful moment"
                content.body = message
                content.sound = UNNotificationSound.default

                let trigger = UNCalendarNotificationTrigger(dateMatching: slot, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "mindfulness_\(index)_\(slot.hour ?? 0)h\(slot.minute ?? 0)m",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule mindfulness notification: \(error)")
                    } else {
                        print("Scheduled mindfulness notification at \(slot.hour ?? 0):\(String(format: "%02d", slot.minute ?? 0))")
                    }
                }
            }
        }
    }

    private func cancelMindfulnessNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix("mindfulness_") }
                .map { $0.identifier }
            if !ids.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                print("Cancelled \(ids.count) mindfulness notifications")
            }
        }
    }
}

// MARK: - SessionManager

class SessionManager: NSObject, ObservableObject {
    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var currentSession: Session?
    @Published var progress: Double = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var sessions: [Session] = []
    @Published var showSessionSavedMessage = false

    private var timer: Timer?
    private var sessionDuration: TimeInterval = 0
    private var startTime: Date?
    private var sessionEndTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var healthManager: HealthKitManager?
    private var notificationIdentifier = "meditation_session_complete"
    private var settingsManager: SettingsManager?
    private var currentActivity: Activity<MindfulBooActivityAttributes>?
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    override init() {
        super.init()
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
            // Configure audio session for alarm playback only
            // .duckOthers ensures our alarm can interrupt other audio
            // .interruptSpokenAudioAndMixWithOthers allows alarm to play even if other audio is active
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for alarm playback")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
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
        isPaused = false
        pauseStartTime = nil
        totalPausedDuration = 0
        progress = 0

        print("📱 isSessionActive set to: \(isSessionActive)")

        // Disable idle timer to keep phone awake during meditation
        UIApplication.shared.isIdleTimerDisabled = true
        print("📱 Idle timer disabled - phone will stay awake during meditation")

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
        requestNotificationPermissions { granted in
            // Debug: Check current notification settings before scheduling
            self.checkNotificationSettingsBeforeScheduling {
                // Only schedule if we have authorization or provisional authorization
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                        self.scheduleSessionCompletionNotification(duration: duration)
                    } else {
                        print("⚠️ Cannot schedule notification - authorization status: \(settings.authorizationStatus.rawValue)")
                    }
                }
            }
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
        isPaused = false
        pauseStartTime = nil
        totalPausedDuration = 0

        // Re-enable idle timer to allow phone to sleep normally
        UIApplication.shared.isIdleTimerDisabled = false
        print("📱 Idle timer re-enabled - phone can sleep normally")

        // End Live Activity
        endLiveActivity()

        cancelSessionNotification()

        // Complete current session
        completeAndSaveSession()

        // Play completion sound
        playCompletionSound()

        print("✅ Meditation session stopped - timers synchronized")
    }
    
    // MARK: - Pause / Resume

    func pauseSession() {
        guard isSessionActive, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        isPaused = true
        pauseStartTime = Date()
        // Allow screen to sleep while paused
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func resumeSession() {
        guard isSessionActive, isPaused else { return }
        if let ps = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(ps)
            pauseStartTime = nil
        }
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
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
        let elapsed = now.timeIntervalSince(startTime) - totalPausedDuration
        let syncedTimeRemaining = max(0, sessionDuration - elapsed)
        let syncedProgress = min(1.0, elapsed / sessionDuration)
        
        timeRemaining = syncedTimeRemaining
        progress = syncedProgress
        
        updateLiveActivity()
        
        // Check if session should have ended while app was in background
        if syncedTimeRemaining <= 0 && isSessionActive {
            print("🔄 Session completed while app was in background - completing session safely")
            completeAndSaveSession()
            cancelSessionNotification()

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
        guard let startTime = startTime, isSessionActive, !isPaused else { return }

        // Use consistent time calculation for both app and widget
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime) - totalPausedDuration
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
            await currentActivity?.update(
                ActivityContent<MindfulBooActivityAttributes.ContentState>(
                    state: updatedState,
                    staleDate: nil
                )
            )
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
            await currentActivity?.end(
                ActivityContent<MindfulBooActivityAttributes.ContentState>(
                    state: finalState,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
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
    
    private func requestNotificationPermissions(completion: @escaping (Bool) -> Void = { _ in }) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            } else {
                print("✅ Notification permission granted: \(granted)")
                if granted {
                    print("✅ Standard notifications enabled for locked device alarm functionality")
                } else {
                    print("⚠️ Notifications denied - alarm may not work when device is locked")
                }
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
    
    private func scheduleSessionCompletionNotification(duration: TimeInterval) {
        // Single, effective notification for session completion
        let content = UNMutableNotificationContent()
        content.title = "🧘‍♀️ Meditation Complete"
        content.body = "Your \(Int(duration/60))-minute session has finished. Well done!"
        content.badge = 1
        content.categoryIdentifier = "MEDITATION_COMPLETE"
        // Use default notification sound (distinct and reliable)
        content.sound = UNNotificationSound.default

        // For iOS 15+, use timeSensitive to ensure notification is delivered prominently
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
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
                let fireDate = Date().addingTimeInterval(duration)
                print("✅ Scheduled completion notification for \(Int(duration/60)) minutes")
                print("   📅 Will fire at: \(fireDate)")
                print("   🔔 Notification ID: \(self.notificationIdentifier)")
                print("   🔊 Sound: default (system notification sound)")
                print("   ⚡️ Interruption Level: timeSensitive")
            }
        }
        
        // Schedule additional notifications only if settings allow
        if let settings = settingsManager?.settings.sessionNotifications, settings.isEnabled {
            scheduleIntervalNotifications(duration: duration, settings: settings)
            scheduleProgressNotifications(duration: duration, settings: settings)
        }
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

        print("Cancelled all session notifications")
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
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)

                    Spacer()

                    Text("edit reminder")
                        .font(.custom("Georgia-Italic", size: 18))
                        .foregroundColor(.mbPrimary)

                    Spacer()

                    Button("save") {
                        onSave(reminder)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(
                        reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.mbSecondary.opacity(0.35)
                            : Color.mbAccent
                    )
                    .disabled(reminder.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 32)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // Time picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("time")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)

                            DatePicker("Time", selection: $reminder.time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .tint(Color.mbAccent)
                        }
                        .padding(.horizontal, 28)

                        Rectangle()
                            .fill(Color.mbSecondary.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.horizontal, 28)

                        // Message
                        VStack(alignment: .leading, spacing: 12) {
                            Text("message")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)

                            TextField("reminder message", text: $reminder.message, axis: .vertical)
                                .font(.custom("Georgia", size: 15))
                                .foregroundColor(.mbPrimary)
                                .lineLimit(3)
                                .padding(16)
                                .background(Color.mbSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.mbSecondary.opacity(0.12), lineWidth: 0.5)
                                )

                            Text("suggestions")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)
                                .padding(.top, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(defaultMessages, id: \.self) { defaultMessage in
                                        Button(action: { reminder.message = defaultMessage }) {
                                            Text(defaultMessage)
                                                .font(.system(size: 10))
                                                .foregroundColor(.mbSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Color.mbSurface)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.mbSecondary.opacity(0.15), lineWidth: 0.5)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                            .padding(.horizontal, -28)
                        }
                        .padding(.horizontal, 28)
                    }
                    .padding(.bottom, 60)
                }
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("settings")
                            .font(.custom("Georgia-Italic", size: 30))
                            .foregroundColor(.mbPrimary)
                        Text(tabLabel)
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                    }
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Circle()
                            .stroke(Color.mbSecondary.opacity(0.22), lineWidth: 0.7)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.mbSecondary)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 48)
                .padding(.bottom, 28)

                // Minimal tab row
                HStack(spacing: 0) {
                    ForEach(Array(["session", "reminders", "mindful", "appearance"].enumerated()), id: \.offset) { i, label in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i }
                        }) {
                            VStack(spacing: 6) {
                                Text(label)
                                    .font(.system(size: 9, weight: selectedTab == i ? .semibold : .regular))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                                    .foregroundColor(selectedTab == i ? Color.mbPrimary : Color.mbSecondary)
                                Rectangle()
                                    .fill(selectedTab == i ? Color.mbAccent : Color.clear)
                                    .frame(height: 0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 4)

                // Thin separator
                Rectangle()
                    .fill(Color.mbSecondary.opacity(0.10))
                    .frame(height: 0.5)
                    .padding(.horizontal, 28)

                // Tab content
                TabView(selection: $selectedTab) {
                    SessionNotificationSettingsView()
                        .tag(0)
                    DailyReminderSettingsView()
                        .tag(1)
                    MindfulnessSettingsView()
                        .tag(2)
                    AppearanceSettingsView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
    }

    private var tabLabel: String {
        switch selectedTab {
        case 0: return "notifications"
        case 1: return "daily reminders"
        case 2: return "mindfulness reminders"
        default: return "appearance"
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(isSelected ? Color.mbPrimary : Color.mbSecondary)
                Rectangle()
                    .fill(isSelected ? Color.mbAccent : Color.clear)
                    .frame(height: 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Notification Settings

struct SessionNotificationSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("notifications")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                    Text("during sessions")
                        .font(.custom("Georgia-Italic", size: 22))
                        .foregroundColor(.mbPrimary)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Enable/Disable toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("enable notifications")
                                .font(.custom("Georgia", size: 15))
                                .foregroundColor(.mbPrimary)
                            Text("notify during meditation")
                                .font(.system(size: 9))
                                .tracking(1)
                                .foregroundColor(.mbSecondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsManager.settings.sessionNotifications.isEnabled },
                            set: { _ in settingsManager.toggleSessionNotifications() }
                        ))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.mbSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.mbSecondary.opacity(0.15), lineWidth: 0.5))
                    )
                }
                .padding(.horizontal)

                if settingsManager.settings.sessionNotifications.isEnabled {
                    // Interval notifications
                    VStack(alignment: .leading, spacing: 12) {
                        Text("interval")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("milestones")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
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
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(isSelected ? Color.mbAccent : Color.mbSecondary.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.mbSurface : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.mbAccent.opacity(0.35) : Color.mbSecondary.opacity(0.15),
                                lineWidth: 0.7
                            )
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
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(.mbPrimary)
                Spacer()
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(isEnabled ? Color.mbAccent : Color.mbSecondary.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.mbSurface : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isEnabled ? Color.mbAccent.opacity(0.35) : Color.mbSecondary.opacity(0.15),
                                lineWidth: 0.7
                            )
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                VStack(alignment: .leading, spacing: 5) {
                    Text("reminders")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                    Text("daily practice")
                        .font(.custom("Georgia-Italic", size: 22))
                        .foregroundColor(.mbPrimary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Master toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("enable reminders")
                            .font(.custom("Georgia", size: 15))
                            .foregroundColor(.mbPrimary)
                        Text("receive daily meditation prompts")
                            .font(.system(size: 9))
                            .tracking(0.5)
                            .foregroundColor(.mbSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.dailyReminders.isEnabled },
                        set: { _ in settingsManager.toggleDailyReminders() }
                    ))
                    .tint(Color.mbAccent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(Color.mbSurface)
                .overlay(
                    Rectangle()
                        .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.5)
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

                if settingsManager.settings.dailyReminders.isEnabled {
                    // Add reminder button
                    if settingsManager.settings.dailyReminders.reminders.count < 10 {
                        Button(action: { showingAddReminder = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .light))
                                    .foregroundColor(Color.mbAccent)
                                Text("add reminder")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.mbAccent)
                            }
                            .padding(.horizontal, 28)
                            .padding(.bottom, 20)
                        }
                        .buttonStyle(.plain)
                    }

                    // Reminders list
                    if !settingsManager.settings.dailyReminders.reminders.isEmpty {
                        VStack(spacing: 0) {
                            Text("scheduled")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 12)

                            ForEach(Array(sortedReminders.enumerated()), id: \.element.id) { index, reminder in
                                let originalIndex = settingsManager.settings.dailyReminders.reminders.firstIndex(where: { $0.id == reminder.id }) ?? 0
                                DailyReminderRow(
                                    reminder: reminder,
                                    isEnabled: reminder.isEnabled,
                                    onToggle: { settingsManager.toggleDailyReminder(at: originalIndex) },
                                    onDelete: { settingsManager.removeDailyReminder(at: originalIndex) },
                                    onEdit: { reminderToEdit = reminder }
                                )

                                Rectangle()
                                    .fill(Color.mbSecondary.opacity(0.07))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 28)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Circle()
                                .stroke(Color.mbSecondary.opacity(0.18), lineWidth: 0.7)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "bell")
                                        .font(.system(size: 18, weight: .ultraLight))
                                        .foregroundColor(Color.mbSecondary.opacity(0.45))
                                )
                            Text("no reminders set")
                                .font(.custom("Georgia-Italic", size: 16))
                                .foregroundColor(Color.mbPrimary.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                    }
                }

                Spacer(minLength: 60)
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(
                time: $newReminderTime,
                message: $newReminderMessage,
                onSave: {
                    settingsManager.addDailyReminder(time: newReminderTime, message: newReminderMessage)
                    showingAddReminder = false
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.formattedTime)
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(isEnabled ? .mbPrimary : Color.mbPrimary.opacity(0.35))
                Text(reminder.message)
                    .font(.system(size: 9))
                    .tracking(0.5)
                    .foregroundColor(.mbSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                .tint(Color.mbAccent)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.mbSecondary)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(.red.opacity(0.50))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
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
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)

                    Spacer()

                    Text("add reminder")
                        .font(.custom("Georgia-Italic", size: 18))
                        .foregroundColor(.mbPrimary)

                    Spacer()

                    Button("save") {
                        onSave()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(
                        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.mbSecondary.opacity(0.35)
                            : Color.mbAccent
                    )
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 32)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // Time picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("time")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)

                            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .tint(Color.mbAccent)
                        }
                        .padding(.horizontal, 28)

                        Rectangle()
                            .fill(Color.mbSecondary.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.horizontal, 28)

                        // Message
                        VStack(alignment: .leading, spacing: 12) {
                            Text("message")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)

                            TextField("reminder message", text: $message, axis: .vertical)
                                .font(.custom("Georgia", size: 15))
                                .foregroundColor(.mbPrimary)
                                .lineLimit(3)
                                .padding(16)
                                .background(Color.mbSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.mbSecondary.opacity(0.12), lineWidth: 0.5)
                                )

                            Text("suggestions")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)
                                .padding(.top, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(defaultMessages, id: \.self) { defaultMessage in
                                        Button(action: { message = defaultMessage }) {
                                            Text(defaultMessage)
                                                .font(.system(size: 10))
                                                .foregroundColor(.mbSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Color.mbSurface)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.mbSecondary.opacity(0.15), lineWidth: 0.5)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 28)
                            }
                            .padding(.horizontal, -28)
                        }
                        .padding(.horizontal, 28)
                    }
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("appearance")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                    Text("how the app looks")
                        .font(.custom("Georgia-Italic", size: 22))
                        .foregroundColor(.mbPrimary)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        let isSelected = settingsManager.settings.appearanceMode == mode
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settingsManager.updateAppearanceMode(mode)
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(isSelected ? Color.mbAccent : Color.mbSecondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.displayName)
                                        .font(.custom("Georgia", size: 15))
                                        .foregroundColor(.mbPrimary)
                                    Text(modeDescription(for: mode))
                                        .font(.system(size: 9))
                                        .tracking(0.5)
                                        .foregroundColor(.mbSecondary)
                                }

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(isSelected ? Color.mbAccent : Color.mbSecondary.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.mbSurface : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.mbAccent.opacity(0.35) : Color.mbSecondary.opacity(0.15), lineWidth: 0.7))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    private func modeDescription(for mode: AppearanceMode) -> String {
        switch mode {
        case .light: return "always light"
        case .dark:  return "always dark"
        case .auto:  return "follow system"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}

// MARK: - Mindfulness Settings

struct MindfulnessSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedMode: MindfulnessMode = .window
    @State private var showingAddTime = false
    @State private var newCustomTime = Date()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                VStack(alignment: .leading, spacing: 5) {
                    Text("mindful")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                    Text("throughout the day")
                        .font(.custom("Georgia-Italic", size: 22))
                        .foregroundColor(.mbPrimary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 8)

                Text("gentle nudges to pause and be present — not to meditate.")
                    .font(.system(size: 10))
                    .tracking(0.3)
                    .foregroundColor(.mbSecondary)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)

                // Master toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("enable reminders")
                            .font(.custom("Georgia", size: 15))
                            .foregroundColor(.mbPrimary)
                        Text("quiet prompts to come back to now")
                            .font(.system(size: 9))
                            .tracking(0.5)
                            .foregroundColor(.mbSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.mindfulnessReminders.isEnabled },
                        set: { _ in settingsManager.toggleMindfulnessReminders() }
                    ))
                    .tint(Color.mbAccent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(Color.mbSurface)
                .overlay(
                    Rectangle()
                        .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.5)
                )
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

                if settingsManager.settings.mindfulnessReminders.isEnabled {
                    // Mode selector
                    HStack(spacing: 0) {
                        ForEach(MindfulnessMode.allCases, id: \.self) { mode in
                            let isSelected = settingsManager.settings.mindfulnessReminders.mode == mode
                            Button(action: {
                                settingsManager.updateMindfulnessMode(mode)
                            }) {
                                VStack(spacing: 6) {
                                    Text(mode.displayName)
                                        .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                                        .tracking(1.5)
                                        .textCase(.uppercase)
                                        .foregroundColor(isSelected ? Color.mbPrimary : Color.mbSecondary)
                                    Rectangle()
                                        .fill(isSelected ? Color.mbAccent : Color.clear)
                                        .frame(height: 0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 4)

                    Rectangle()
                        .fill(Color.mbSecondary.opacity(0.10))
                        .frame(height: 0.5)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)

                    if settingsManager.settings.mindfulnessReminders.mode == .window {
                        // Window mode
                        VStack(alignment: .leading, spacing: 16) {
                            Text("window")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)
                                .padding(.horizontal, 28)

                            // From row
                            HStack {
                                Text("from")
                                    .font(.custom("Georgia", size: 15))
                                    .foregroundColor(.mbPrimary)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { settingsManager.settings.mindfulnessReminders.windowStart },
                                        set: { settingsManager.updateMindfulnessWindowStart($0) }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(Color.mbAccent)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.mbSurface)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 28)

                            // Until row
                            HStack {
                                Text("until")
                                    .font(.custom("Georgia", size: 15))
                                    .foregroundColor(.mbPrimary)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { settingsManager.settings.mindfulnessReminders.windowEnd },
                                        set: { settingsManager.updateMindfulnessWindowEnd($0) }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(Color.mbAccent)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.mbSurface)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.5)
                            )
                            .padding(.horizontal, 28)
                        }
                        .padding(.bottom, 24)

                        // Frequency
                        VStack(alignment: .leading, spacing: 12) {
                            Text("frequency")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(2)
                                .textCase(.uppercase)
                                .foregroundColor(.mbSecondary)
                                .padding(.horizontal, 28)

                            VStack(spacing: 8) {
                                ForEach(MindfulnessInterval.allCases, id: \.self) { interval in
                                    let isSelected = settingsManager.settings.mindfulnessReminders.interval == interval
                                    Button(action: {
                                        settingsManager.updateMindfulnessInterval(interval)
                                    }) {
                                        HStack {
                                            Text(interval.displayName)
                                                .font(.custom("Georgia", size: 15))
                                                .foregroundColor(.mbPrimary)
                                            Spacer()
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 16, weight: .light))
                                                .foregroundColor(isSelected ? Color.mbAccent : Color.mbSecondary.opacity(0.45))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.mbSurface : Color.clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(
                                                            isSelected ? Color.mbAccent.opacity(0.35) : Color.mbSecondary.opacity(0.15),
                                                            lineWidth: 0.7
                                                        )
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 28)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // Preview count
                        let count = windowReminderCount
                        Text("\(count) reminder\(count == 1 ? "" : "s") per day")
                            .font(.system(size: 9))
                            .tracking(0.5)
                            .foregroundColor(.mbSecondary)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 24)

                    } else {
                        // Custom times mode
                        VStack(alignment: .leading, spacing: 0) {
                            if !settingsManager.settings.mindfulnessReminders.customTimes.isEmpty {
                                Text("times")
                                    .font(.system(size: 8, weight: .medium))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(.mbSecondary)
                                    .padding(.horizontal, 28)
                                    .padding(.bottom, 12)

                                ForEach(Array(settingsManager.settings.mindfulnessReminders.customTimes.enumerated()), id: \.element.id) { index, customTime in
                                    HStack {
                                        Text(customTime.formattedTime)
                                            .font(.custom("Georgia", size: 16))
                                            .foregroundColor(.mbPrimary)
                                        Spacer()
                                        Button(action: {
                                            settingsManager.removeMindfulnessCustomTime(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .light))
                                                .foregroundColor(.red.opacity(0.50))
                                        }
                                    }
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 14)

                                    Rectangle()
                                        .fill(Color.mbSecondary.opacity(0.07))
                                        .frame(height: 0.5)
                                        .padding(.horizontal, 28)
                                }
                                .padding(.bottom, 4)
                            }

                            Button(action: { showingAddTime = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .light))
                                        .foregroundColor(Color.mbAccent)
                                    Text("add time")
                                        .font(.system(size: 9, weight: .medium))
                                        .tracking(2)
                                        .textCase(.uppercase)
                                        .foregroundColor(Color.mbAccent)
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)

                            let count = settingsManager.settings.mindfulnessReminders.customTimes.count
                            Text("\(count) reminder\(count == 1 ? "" : "s") per day")
                                .font(.system(size: 9))
                                .tracking(0.5)
                                .foregroundColor(.mbSecondary)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 24)
                        }
                    }
                }

                Spacer(minLength: 60)
            }
        }
        .sheet(isPresented: $showingAddTime) {
            AddMindfulnessTimeView(time: $newCustomTime) {
                settingsManager.addMindfulnessCustomTime(newCustomTime)
                showingAddTime = false
                newCustomTime = Date()
            }
        }
    }

    private var windowReminderCount: Int {
        let remSettings = settingsManager.settings.mindfulnessReminders
        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.hour, .minute], from: remSettings.windowStart)
        let endComps = calendar.dateComponents([.hour, .minute], from: remSettings.windowEnd)
        let startMinutes = (startComps.hour ?? 9) * 60 + (startComps.minute ?? 0)
        let endMinutes = (endComps.hour ?? 21) * 60 + (endComps.minute ?? 0)
        let step = remSettings.interval.rawValue
        guard step > 0, endMinutes >= startMinutes else { return 0 }
        return (endMinutes - startMinutes) / step + 1
    }
}

struct AddMindfulnessTimeView: View {
    @Binding var time: Date
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)

                    Spacer()

                    Text("add time")
                        .font(.custom("Georgia-Italic", size: 18))
                        .foregroundColor(.mbPrimary)

                    Spacer()

                    Button("add") {
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Color.mbAccent)
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 12) {
                    Text("time")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)

                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .tint(Color.mbAccent)
                }
                .padding(.horizontal, 28)

                Spacer()
            }
        }
    }
}

// MARK: - State of Mind Models

enum StateOfMindEmotion: String, CaseIterable, Identifiable {
    case happy = "happy"
    case calm = "calm"
    case excited = "excited"
    case grateful = "grateful"
    case content = "content"
    case anxious = "anxious"
    case sad = "sad"
    case angry = "angry"
    case stressed = "stressed"
    case frustrated = "frustrated"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .calm: return "😌"
        case .excited: return "🤗"
        case .grateful: return "🙏"
        case .content: return "😊"
        case .anxious: return "😰"
        case .sad: return "😢"
        case .angry: return "😠"
        case .stressed: return "😩"
        case .frustrated: return "😫"
        }
    }
    
    var category: StateOfMindCategory {
        switch self {
        case .happy, .content, .grateful, .excited:
            return .positive
        case .calm:
            return .balanced
        case .sad, .anxious, .stressed:
            return .negative
        case .angry, .frustrated:
            return .challenging
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
    @State private var showingSuccessMessage = false
    @State private var selectedKind: StateOfMindKind = .momentaryEmotion
    
    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("mood")
                            .font(.custom("Georgia-Italic", size: 30))
                            .foregroundColor(.mbPrimary)
                        Text("how are you feeling?")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                    }

                    Spacer()

                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Circle()
                            .stroke(Color.mbSecondary.opacity(0.20), lineWidth: 0.7)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.mbSecondary)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 48)
                .padding(.bottom, 32)

                // Kind selector
                HStack(spacing: 0) {
                    ForEach(StateOfMindKind.allCases, id: \.self) { kind in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedKind = kind
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(kind.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(selectedKind == kind ? .mbPrimary : .mbSecondary)
                                Rectangle()
                                    .fill(selectedKind == kind ? Color.mbAccent : Color.clear)
                                    .frame(height: 0.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)

                Rectangle()
                    .fill(Color.mbSecondary.opacity(0.10))
                    .frame(height: 0.5)
                    .padding(.horizontal, 28)

                // Emotions list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(StateOfMindEmotion.allCases) { emotion in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedEmotion == emotion {
                                        selectedEmotion = nil
                                    } else {
                                        selectedEmotion = emotion
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
                            }) {
                                HStack(spacing: 16) {
                                    Text(emotion.emoji)
                                        .font(.system(size: 22))
                                        .frame(width: 32)
                                    Text(emotion.displayName)
                                        .font(.custom("Georgia", size: 16))
                                        .foregroundColor(.mbPrimary)
                                    Spacer()
                                    if selectedEmotion == emotion {
                                        Rectangle()
                                            .fill(Color.mbAccent)
                                            .frame(width: 2, height: 16)
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 16)
                                .background(
                                    selectedEmotion == emotion
                                        ? Color.mbSurface
                                        : Color.clear
                                )
                            }
                            .buttonStyle(.plain)

                            Rectangle()
                                .fill(Color.mbSecondary.opacity(0.07))
                                .frame(height: 0.5)
                                .padding(.horizontal, 28)
                        }

                        // Intensity slider
                        if selectedEmotion != nil {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("intensity")
                                    .font(.system(size: 8, weight: .medium))
                                    .tracking(2)
                                    .textCase(.uppercase)
                                    .foregroundColor(.mbSecondary)

                                HStack {
                                    Text("−")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundColor(.mbSecondary)
                                    Slider(value: $valence, in: -1...1, step: 0.1)
                                        .tint(Color.mbAccent)
                                    Text("+")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundColor(.mbSecondary)
                                }

                                Text((valence >= 0 ? "+" : "") + String(format: "%.1f", valence))
                                    .font(.custom("Georgia", size: 22))
                                    .foregroundColor(.mbPrimary)
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 28)
                        }

                        // Save button
                        if selectedEmotion != nil {
                            Button(action: saveStateOfMind) {
                                Text("save mood")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(3)
                                    .textCase(.uppercase)
                                    .foregroundColor(Color.mbAccent)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.mbAccent.opacity(0.45), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 60)
                        }
                    }
                }
            }

            // Success toast
            if showingSuccessMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.mbAccent)
                            .frame(width: 2, height: 16)
                        Text("mood logged")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbPrimary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.mbSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.mbSecondary.opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.35), value: showingSuccessMessage)
            }
        }
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


