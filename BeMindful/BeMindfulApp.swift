import SwiftUI
import HealthKit

@main
struct BeMindfulApp: App {
    @StateObject private var healthStore = HealthKitManager()
    @StateObject private var sessionManager = SessionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(sessionManager)
                .onAppear {
                    healthStore.requestPermissions()
                    sessionManager.setHealthManager(healthStore)
                    
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
                }
        }
    }
} 