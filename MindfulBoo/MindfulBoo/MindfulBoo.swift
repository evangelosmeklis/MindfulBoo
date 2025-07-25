import SwiftUI
import HealthKit
import UserNotifications 

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification actions
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            print("✅ User marked meditation as complete")
            // Session should already be completed by the timer/notification
        case "EXTEND_ACTION":
            print("⏰ User wants to extend meditation by 5 minutes")
            // Could add logic here to extend the current session
        case "STOP_SESSION_ACTION":
            print("🛑 User wants to stop the current session")
            // Could add logic here to stop the current session
        case "EXTEND_SESSION_ACTION":
            print("⏰ User wants to extend the current session by 5 minutes")
            // Could add logic here to extend the current session
        case UNNotificationDefaultActionIdentifier:
            print("🔔 User tapped meditation completion notification")
            // This handles when user taps the notification itself
        default:
            print("🔔 User interacted with meditation notification: \(response.actionIdentifier)")
        }
        completionHandler()
    }
}

@main
struct MindfulBooApp: App {
    @StateObject private var healthStore = HealthKitManager()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var settingsManager = SettingsManager()
    private let notificationDelegate = NotificationDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(sessionManager)
                .environmentObject(settingsManager)
                .onAppear {
                    // Setup notification delegate
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    
                    // Connect the managers so they can work together
                    healthStore.requestPermissions()
                    sessionManager.setHealthManager(healthStore)
                    sessionManager.setSettingsManager(settingsManager)
                    
                    // Calculate initial streak from existing sessions
                    let streakCount = sessionManager.calculateConsecutiveDays()
                    healthStore.updateConsecutiveDays(streakCount)
                    
                    // Give a moment for permissions to be processed, then log status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("\n🚀 Meditation App Started")
                        print("📋 Checking HealthKit permissions...")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh permissions when app becomes active (e.g., returning from Settings)
                    print("📱 App became active - refreshing HealthKit permissions...")
                    healthStore.forceRefreshPermissions()
                    
                    // Sync session timers when app becomes active (fixes background timer issues)
                    sessionManager.forceSyncTimers()
                    
                    // Clear notification badge when app becomes active
                    UNUserNotificationCenter.current().setBadgeCount(0)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Handle app going to background during active session
                    print("📱 App entered background")
                    if sessionManager.isSessionActive {
                        print("🔄 Active session detected - ensuring background task is running")
                    }
                }
        }
    }
} 