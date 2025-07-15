import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var healthStore: HealthKitManager
    @EnvironmentObject var meditationManager: MeditationManager
    @State private var selectedDuration: TimeInterval = 300 // 5 minutes default
    @State private var isTimerPickerPresented = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Mindful")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Meditation & Wellness")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Current session or timer setup
                if meditationManager.isSessionActive {
                    ActiveSessionView()
                } else {
                    // Duration selector
                    VStack(spacing: 20) {
                        Text("Session Duration")
                            .font(.headline)
                        
                        Button(action: {
                            isTimerPickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                Text(formatDuration(selectedDuration))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.blue)
                        
                        // Start meditation button
                        Button(action: startMeditation) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Meditation")
                                    .fontWeight(.semibold)
                            }
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green, .blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                        }
                        
                        // HealthKit status indicator
                        if healthStore.isAuthorized {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("Syncing with Health app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Heart rate monitoring status
                        HStack {
                            Image(systemName: healthStore.canMonitorHeartRate ? "applewatch" : "applewatch.slash")
                                .foregroundColor(healthStore.canMonitorHeartRate ? .blue : .orange)
                                .font(.caption)
                            Text(healthStore.heartRatePermissionStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                healthStore.forceRefreshPermissions()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 4)
                        .onTapGesture {
                            if !healthStore.canMonitorHeartRate {
                                healthStore.retryHeartRatePermission()
                            }
                        }
                        .onLongPressGesture {
                            // Debug: Long press to show detailed permissions
                            healthStore.debugPermissions()
                        }
                        
                        // Respiratory rate monitoring status
                        HStack {
                            Image(systemName: healthStore.canMonitorRespiratoryRate ? "lungs.fill" : "lungs")
                                .foregroundColor(healthStore.canMonitorRespiratoryRate ? .blue : .orange)
                                .font(.caption)
                            Text(healthStore.respiratoryRatePermissionStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.top, 2)
                        .onTapGesture {
                            if !healthStore.canMonitorRespiratoryRate {
                                healthStore.retryRespiratoryRatePermission()
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Bottom actions
                HStack {
                    Spacer()
                    Button(action: { showingHistory = true }) {
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                            Text("History")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isTimerPickerPresented) {
            DurationPickerView(selectedDuration: $selectedDuration)
        }
        .sheet(isPresented: $showingHistory) {
            SessionHistoryView()
        }
        .overlay(
            // Session saved notification
            VStack {
                Spacer()
                if meditationManager.showSessionSavedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Session saved to Health app")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .gray.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: meditationManager.showSessionSavedMessage)
                    .padding(.bottom, 100)
                }
            }
        )
    }
    
    private func startMeditation() {
        meditationManager.startSession(duration: selectedDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

struct ActiveSessionView: View {
    @EnvironmentObject var meditationManager: MeditationManager
    @EnvironmentObject var healthStore: HealthKitManager
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: meditationManager.progress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: meditationManager.progress)
                
                VStack {
                    Text(meditationManager.formattedTimeRemaining)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Live heart rate from Apple Watch
            if let heartRate = meditationManager.currentHeartRate {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "applewatch")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Live from Apple Watch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("\(Int(heartRate))")
                                .font(.title)
                                .fontWeight(.bold)
                                .monospacedDigit()
                            Text("BPM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let respiratoryRate = meditationManager.currentRespiratoryRate {
                            VStack {
                                Image(systemName: "lungs.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("\(Int(respiratoryRate))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                Text("BR/MIN")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text(meditationManager.isHeartRateMonitoring ? "Monitoring" : "Connecting")
                                .font(.caption)
                                .foregroundColor(meditationManager.isHeartRateMonitoring ? .green : .orange)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .animation(.easeInOut(duration: 0.3), value: heartRate)
            } else if meditationManager.isSessionActive {
                // Heart rate monitoring status during session
                VStack {
                    HStack {
                        if healthStore.canMonitorHeartRate {
                            Image(systemName: "applewatch")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Starting heart rate monitoring...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "applewatch.slash")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Heart rate monitoring unavailable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if healthStore.canMonitorHeartRate {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else {
                        Button("Enable Permission") {
                            healthStore.retryHeartRatePermission()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            
            // Stop button
            Button(action: {
                meditationManager.stopSession()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("End Session")
                        .fontWeight(.semibold)
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color.red)
                .cornerRadius(20)
            }
        }
    }
}

struct DurationPickerView: View {
    @Binding var selectedDuration: TimeInterval
    @Environment(\.presentationMode) var presentationMode
    
    private let durations: [TimeInterval] = [
        300,   // 5 min
        600,   // 10 min  
        900,   // 15 min
        1200,  // 20 min
        1500,  // 25 min
        1800,  // 30 min
        2700,  // 45 min
        3600   // 60 min
    ]
    
    var body: some View {
        NavigationView {
            List(durations, id: \.self) { duration in
                Button(action: {
                    selectedDuration = duration
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(formatDuration(duration))
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedDuration == duration {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Duration")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) minutes"
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(MeditationManager())
} 