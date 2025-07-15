import SwiftUI
import HealthKit

@main
struct MeditationAppApp: App {
    @StateObject private var healthStore = HealthKitManager()
    @StateObject private var meditationManager = MeditationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthStore)
                .environmentObject(meditationManager)
                .onAppear {
                    healthStore.requestPermissions()
                    meditationManager.setHealthManager(healthStore)
                }
        }
    }
} 