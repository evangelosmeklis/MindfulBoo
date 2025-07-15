import SwiftUI
import HealthKit

@main
struct WatchAppApp: App {
    @StateObject private var healthStore = WatchHealthManager()
    @StateObject private var workoutManager = WatchWorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(healthStore)
                .environmentObject(workoutManager)
                .onAppear {
                    healthStore.requestPermissions()
                }
        }
    }
} 