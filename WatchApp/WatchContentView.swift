import SwiftUI
import HealthKit

struct WatchContentView: View {
    @EnvironmentObject var healthStore: WatchHealthManager
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @State private var sessionDuration: TimeInterval = 300
    
    var body: some View {
        NavigationView {
            VStack {
                if workoutManager.isSessionActive {
                    ActiveWorkoutView()
                } else {
                    IdleView(sessionDuration: $sessionDuration)
                }
            }
        }
    }
}

struct IdleView: View {
    @Binding var sessionDuration: TimeInterval
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundColor(.green)
            
            Text("Mindful")
                .font(.headline)
            
            Button(action: {
                workoutManager.startWorkout(duration: sessionDuration)
            }) {
                VStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Start")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            
            Text("\(Int(sessionDuration/60)) min")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Meditation")
    }
}

struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    
    var body: some View {
        VStack(spacing: 15) {
            // Timer
            Text(workoutManager.formattedElapsedTime)
                .font(.title2)
                .monospacedDigit()
                .foregroundColor(.green)
            
            // Heart rate
            if let heartRate = workoutManager.currentHeartRate {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(Int(heartRate))")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            // Breathing rate (if available)
            if let breathingRate = workoutManager.currentBreathingRate {
                HStack {
                    Image(systemName: "lungs.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("\(Int(breathingRate))")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    workoutManager.pauseWorkout()
                }) {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                Button(action: {
                    workoutManager.endWorkout()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .navigationTitle("Meditating")
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchHealthManager())
        .environmentObject(WatchWorkoutManager())
} 