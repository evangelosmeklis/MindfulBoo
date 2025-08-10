import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var healthStore: HealthKitManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedMinutes: Int = 5
    @State private var selectedHours: Int = 0
    @State private var isTimerPickerPresented = false
    @State private var showingSettings = false
    @State private var showingStateOfMind = false
    @State private var currentWeather: WeatherCondition = .clear
    @State private var backgroundColors: [Color] = [.blue, .purple]

    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header with consecutive days streak
                VStack(spacing: 12) {
                    // Time-based weather indicator
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text(currentWeather.emoji)
                                .font(.caption)
                            Text(getTimeOfDayDescription())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground).opacity(0.7))
                        )
                    }
                    .padding(.horizontal)
                    
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("MindfulBoo")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Meditation & Wellness")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Consecutive days streak with Liquid Glass - always show, even if 0
                    HStack(spacing: 6) {
                        Text("⚡")
                            .font(.title2)
                        Text("\(healthStore.consecutiveDays)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text(healthStore.consecutiveDays == 1 ? "day streak" : "day streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            // Base translucent glass
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.thinMaterial)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.orange.opacity(0.2))
                                )
                            
                            // Liquid Glass shine effect
                            RoundedRectangle(cornerRadius: 20)
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
                        }
                    )
                    .onTapGesture {
                        // Debug tap - force recalculate
                        print("🐛 DEBUG TAP: Forcing streak recalculation...")
                        print("📊 Current sessions count: \(sessionManager.sessions.count)")
                        
                        // Show recent sessions for debugging
                        let recentSessions = sessionManager.sessions.suffix(5)
                        for session in recentSessions {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            print("   - Session: \(formatter.string(from: session.startDate))")
                        }
                        
                        let streakCount = sessionManager.calculateConsecutiveDays()
                        healthStore.updateConsecutiveDays(streakCount)
                        
                        // Also show debug permissions info
                        healthStore.debugPermissions()
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Current session or timer setup
                if sessionManager.isSessionActive {
                    ActiveSessionView()
                } else {
                    // Duration selector and settings
                    VStack(spacing: 20) {
                        Text("Session Duration")
                            .font(.headline)
                        
                        Button(action: {
                            isTimerPickerPresented = true
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                Text(formatDurationDisplay())
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(
                                // Liquid Glass effect
                                ZStack {
                                    // Base translucent layer
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.8)
                                    
                                    // Specular highlight overlay
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear,
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                            )
                        }
                        .foregroundColor(.primary)
                        
                        // Start meditation button with Liquid Glass
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
                                ZStack {
                                    // Vibrant color base layer
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.2, green: 0.8, blue: 0.4), // Vibrant green
                                                    Color(red: 0.1, green: 0.6, blue: 0.9), // Vibrant blue
                                                    Color(red: 0.3, green: 0.5, blue: 1.0)  // Electric blue
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .saturation(1.2) // Boost color saturation
                                    
                                    // Liquid glass overlay with tint
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(.thinMaterial)
                                        .opacity(0.3)
                                    
                                    // Enhanced specular highlights
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.cyan.opacity(0.2),
                                                    Color.clear,
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .blendMode(.overlay)
                                    
                                    // Liquid glass depth effect
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.clear,
                                                    Color.blue.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                }
                            )
                        }
                        
                        // HealthKit status indicator
                        VStack(spacing: 4) {
                            if healthStore.isAuthorized {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Sessions sync with Health app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Button(action: {
                                    healthStore.requestPermissions()
                                }) {
                                    HStack {
                                        Image(systemName: "heart")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text("Tap to enable Health app sync")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            
                            // State of Mind status
                            if healthStore.canLogStateOfMind {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.pink)
                                        .font(.caption)
                                    Text("Mood logging ready")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Button(action: {
                                    healthStore.requestPermissions()
                                }) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Enable mood logging")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        

                    }
                }
                
                Spacer()
                
                // Bottom actions with Liquid Glass effects
                HStack(spacing: 40) {
                    Spacer()
                    
                    // State of Mind Button
                    Button(action: { showingStateOfMind = true }) {
                        VStack {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                            Text("Mood Log")
                                .font(.caption)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)
                                    .background(
                                        Capsule()
                                            .fill(Color.pink.opacity(0.1))
                                    )
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.pink.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                    }
                    .foregroundColor(.pink)
                    
                    Button(action: { showingSettings = true }) {
                        VStack {
                            Image(systemName: "gear")
                                .font(.title2)
                            Text("Settings")
                                .font(.caption)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)
                                
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
                            }
                        )
                    }
                    .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal)
            .navigationBarHidden(true)
            .background(
                // Dynamic animated background based on time and weather
                ZStack {
                    // Base gradient
                    LinearGradient(
                        gradient: Gradient(colors: backgroundColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Subtle animated overlay for dynamic feel
                    LinearGradient(
                        gradient: Gradient(colors: backgroundColors.map { $0.opacity(0.3) }),
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: backgroundColors)
                }
                .ignoresSafeArea()
            )
        }
        .sheet(isPresented: $isTimerPickerPresented) {
            DurationPickerView(selectedHours: $selectedHours, selectedMinutes: $selectedMinutes)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStateOfMind) {
            StateOfMindLoggingView()
        }


        .overlay(
            // Session saved notification
            VStack {
                Spacer()
                if sessionManager.showSessionSavedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Session saved to Health app")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(
                        ZStack {
                            // Liquid Glass base
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                            
                            // Glass reflection
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.clear,
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: sessionManager.showSessionSavedMessage)
                    .padding(.bottom, 100)
                }
            }
        )
        .onAppear {
            updateBackgroundForTimeOfDay()
            // Always calculate consecutive days when view appears
            let streakCount = sessionManager.calculateConsecutiveDays()
            healthStore.updateConsecutiveDays(streakCount)
            print("🐛 Debug: onAppear called, isAuthorized: \(healthStore.isAuthorized), consecutiveDays: \(healthStore.consecutiveDays)")
            
            // Refresh background every 5 minutes to catch time changes
            Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                updateBackgroundForTimeOfDay()
            }
        }
        .onChange(of: healthStore.isAuthorized) { isAuthorized in
            if isAuthorized {
                let streakCount = sessionManager.calculateConsecutiveDays()
                healthStore.updateConsecutiveDays(streakCount)
                print("🐛 Debug: Authorization changed to \(isAuthorized), recalculating consecutive days")
            }
        }
    }
    
    private func formatDurationDisplay() -> String {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        
        if selectedHours == 0 {
            return "\(selectedMinutes) min"
        } else if selectedMinutes == 0 {
            return "\(selectedHours)h"
        } else {
            return "\(selectedHours)h \(selectedMinutes)m"
        }
    }
    
    private func startMeditation() {
        let totalMinutes = selectedHours * 60 + selectedMinutes
        print("🎯 Start Meditation button pressed!")
        print("📏 Selected duration: \(selectedHours)h \(selectedMinutes)m (total: \(totalMinutes) minutes)")
        print("📊 Current isSessionActive: \(sessionManager.isSessionActive)")
        
        let duration = TimeInterval(totalMinutes * 60)
        sessionManager.startSession(duration: duration)
        
        print("📊 After startSession call, isSessionActive: \(sessionManager.isSessionActive)")
    }
    
    private func updateBackgroundForTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        let weather = getSimulatedWeatherForTime()
        
        currentWeather = weather
        backgroundColors = getBackgroundColors(for: hour, weather: weather)
        
        print("🎨 Background updated for hour \(hour), weather: \(weather)")
    }
    
    private func getTimeOfDayDescription() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<8:
            return "Early Morning"
        case 8..<12:
            return "Morning"
        case 12..<14:
            return "Midday"
        case 14..<17:
            return "Afternoon"
        case 17..<20:
            return "Evening"
        default:
            return "Night"
        }
    }
    
    private func getBackgroundColors(for hour: Int, weather: WeatherCondition) -> [Color] {
        switch (hour, weather) {
        // Early Morning (5-8 AM)
        case (5..<8, .clear), (5..<8, .sunny):
            return [.orange.opacity(0.4), .yellow.opacity(0.3), .pink.opacity(0.2)] // Sunrise
        case (5..<8, .partlyCloudy):
            return [.orange.opacity(0.3), .gray.opacity(0.2), .yellow.opacity(0.2)] // Partly cloudy sunrise
        case (5..<8, .cloudy), (5..<8, .overcast):
            return [.gray.opacity(0.4), .orange.opacity(0.2), .white.opacity(0.1)] // Cloudy sunrise
        case (5..<8, .rainy), (5..<8, .drizzle):
            return [.blue.opacity(0.5), .gray.opacity(0.4), .purple.opacity(0.2)] // Rainy morning
        case (5..<8, .thunderstorm):
            return [.indigo.opacity(0.6), .gray.opacity(0.5), .purple.opacity(0.3)] // Stormy morning
        case (5..<8, .snow):
            return [.white.opacity(0.4), .gray.opacity(0.3), .blue.opacity(0.2)] // Snowy morning
        case (5..<8, .fog):
            return [.gray.opacity(0.5), .white.opacity(0.4), .blue.opacity(0.1)] // Foggy morning
        case (5..<8, .windy):
            return [.cyan.opacity(0.3), .gray.opacity(0.2), .white.opacity(0.2)] // Windy morning
            
        // Morning (8-12 PM)
        case (8..<12, .clear), (8..<12, .sunny):
            return [.blue.opacity(0.3), .cyan.opacity(0.2), .yellow.opacity(0.1)] // Bright morning
        case (8..<12, .partlyCloudy):
            return [.blue.opacity(0.2), .white.opacity(0.3), .cyan.opacity(0.2)] // Partly cloudy morning
        case (8..<12, .cloudy), (8..<12, .overcast):
            return [.gray.opacity(0.3), .blue.opacity(0.2), .white.opacity(0.2)] // Overcast morning
        case (8..<12, .rainy), (8..<12, .drizzle):
            return [.blue.opacity(0.4), .gray.opacity(0.3), .indigo.opacity(0.2)] // Rainy morning
        case (8..<12, .thunderstorm):
            return [.indigo.opacity(0.5), .gray.opacity(0.4), .black.opacity(0.2)] // Stormy morning
        case (8..<12, .snow):
            return [.white.opacity(0.5), .blue.opacity(0.2), .gray.opacity(0.2)] // Snowy morning
        case (8..<12, .fog):
            return [.gray.opacity(0.4), .white.opacity(0.5), .blue.opacity(0.1)] // Foggy morning
        case (8..<12, .windy):
            return [.cyan.opacity(0.4), .blue.opacity(0.2), .white.opacity(0.2)] // Windy morning
            
        // Midday (12-2 PM)
        case (12..<14, .clear), (12..<14, .sunny):
            return [.yellow.opacity(0.3), .cyan.opacity(0.2), .white.opacity(0.2)] // Bright midday
        case (12..<14, .partlyCloudy):
            return [.blue.opacity(0.3), .white.opacity(0.4), .yellow.opacity(0.2)] // Partly cloudy midday
        case (12..<14, .cloudy), (12..<14, .overcast):
            return [.gray.opacity(0.4), .blue.opacity(0.3), .white.opacity(0.3)] // Cloudy midday
        case (12..<14, .rainy), (12..<14, .drizzle):
            return [.blue.opacity(0.5), .indigo.opacity(0.3), .gray.opacity(0.3)] // Rainy midday
        case (12..<14, .thunderstorm):
            return [.black.opacity(0.3), .indigo.opacity(0.5), .gray.opacity(0.4)] // Stormy midday
        case (12..<14, .snow):
            return [.white.opacity(0.6), .blue.opacity(0.3), .gray.opacity(0.2)] // Snowy midday
        case (12..<14, .fog):
            return [.gray.opacity(0.5), .white.opacity(0.6), .blue.opacity(0.1)] // Foggy midday
        case (12..<14, .windy):
            return [.cyan.opacity(0.5), .blue.opacity(0.3), .white.opacity(0.3)] // Windy midday
            
        // Afternoon (2-5 PM)
        case (14..<17, .clear), (14..<17, .sunny):
            return [.blue.opacity(0.2), .cyan.opacity(0.3), .white.opacity(0.1)] // Bright afternoon
        case (14..<17, .partlyCloudy):
            return [.blue.opacity(0.2), .white.opacity(0.4), .cyan.opacity(0.3)] // Partly cloudy afternoon
        case (14..<17, .cloudy), (14..<17, .overcast):
            return [.gray.opacity(0.4), .blue.opacity(0.2), .white.opacity(0.3)] // Cloudy afternoon
        case (14..<17, .rainy), (14..<17, .drizzle):
            return [.blue.opacity(0.5), .indigo.opacity(0.3), .gray.opacity(0.3)] // Stormy afternoon
        case (14..<17, .thunderstorm):
            return [.black.opacity(0.3), .indigo.opacity(0.5), .gray.opacity(0.4)] // Thunderstorm
        case (14..<17, .snow):
            return [.white.opacity(0.6), .blue.opacity(0.3), .gray.opacity(0.2)] // Snowy afternoon
        case (14..<17, .fog):
            return [.gray.opacity(0.5), .white.opacity(0.6), .blue.opacity(0.1)] // Foggy afternoon
        case (14..<17, .windy):
            return [.cyan.opacity(0.5), .blue.opacity(0.3), .white.opacity(0.3)] // Windy afternoon
            
        // Evening (5-8 PM)
        case (17..<20, .clear), (17..<20, .sunny):
            return [.orange.opacity(0.5), .red.opacity(0.3), .yellow.opacity(0.2)] // Golden hour
        case (17..<20, .partlyCloudy):
            return [.orange.opacity(0.4), .gray.opacity(0.2), .red.opacity(0.2)] // Partly cloudy sunset
        case (17..<20, .cloudy), (17..<20, .overcast):
            return [.orange.opacity(0.3), .gray.opacity(0.4), .purple.opacity(0.2)] // Cloudy sunset
        case (17..<20, .rainy), (17..<20, .drizzle):
            return [.indigo.opacity(0.4), .purple.opacity(0.3), .blue.opacity(0.3)] // Rainy evening
        case (17..<20, .thunderstorm):
            return [.black.opacity(0.4), .indigo.opacity(0.5), .purple.opacity(0.3)] // Stormy evening
        case (17..<20, .snow):
            return [.white.opacity(0.4), .purple.opacity(0.2), .blue.opacity(0.3)] // Snowy evening
        case (17..<20, .fog):
            return [.gray.opacity(0.6), .purple.opacity(0.2), .white.opacity(0.3)] // Foggy evening
        case (17..<20, .windy):
            return [.cyan.opacity(0.3), .purple.opacity(0.2), .orange.opacity(0.2)] // Windy evening
            
        // Night (8 PM - 5 AM)
        case (20..<24, _), (0..<5, _):
            switch weather {
            case .clear, .sunny:
                return [.indigo.opacity(0.6), .purple.opacity(0.4), .black.opacity(0.2)] // Clear night
            case .partlyCloudy:
                return [.indigo.opacity(0.5), .gray.opacity(0.3), .purple.opacity(0.3)] // Partly cloudy night
            case .cloudy, .overcast:
                return [.gray.opacity(0.5), .indigo.opacity(0.3), .black.opacity(0.3)] // Cloudy night
            case .rainy, .drizzle:
                return [.black.opacity(0.4), .blue.opacity(0.4), .indigo.opacity(0.3)] // Rainy night
            case .thunderstorm:
                return [.black.opacity(0.6), .indigo.opacity(0.5), .purple.opacity(0.2)] // Stormy night
            case .snow:
                return [.white.opacity(0.3), .blue.opacity(0.4), .indigo.opacity(0.3)] // Snowy night
            case .fog:
                return [.gray.opacity(0.6), .white.opacity(0.2), .indigo.opacity(0.2)] // Foggy night
            case .windy:
                return [.indigo.opacity(0.5), .cyan.opacity(0.2), .black.opacity(0.3)] // Windy night
            }
            
        // Default fallback
        default:
            return [.blue.opacity(0.2), .purple.opacity(0.2), .white.opacity(0.1)]
        }
    }
    

    
    private func getSimulatedWeatherForTime() -> WeatherCondition {
        let hour = Calendar.current.component(.hour, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        
        // Create realistic weather patterns based on time and season
        switch (hour, month) {
        // Summer months (June, July, August)
        case (_, 6...8):
            return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
            
        // Winter months (December, January, February)
        case (_, 12), (_, 1...2):
            return [.cloudy, .overcast, .drizzle, .snow].randomElement() ?? .cloudy
            
        // Spring/Fall
        case (5..<8, _): // Early morning
            return [.clear, .fog, .partlyCloudy].randomElement() ?? .clear
        case (8..<12, _): // Morning
            return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
        case (12..<14, _): // Midday
            return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
        case (14..<17, _): // Afternoon
            return [.sunny, .partlyCloudy, .cloudy].randomElement() ?? .sunny
        case (17..<20, _): // Evening
            return [.partlyCloudy, .clear, .cloudy].randomElement() ?? .partlyCloudy
        case (20..<24, _), (0..<5, _): // Night
            return [.clear, .cloudy, .overcast].randomElement() ?? .clear
            
        default:
            return .clear
        }
    }
}

enum WeatherCondition: String, CaseIterable {
    case clear = "Clear"
    case sunny = "Sunny" 
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case overcast = "Overcast"
    case rainy = "Rainy"
    case drizzle = "Drizzle"
    case thunderstorm = "Thunderstorm"
    case snow = "Snow"
    case fog = "Fog"
    case windy = "Windy"
    
    var emoji: String {
        switch self {
        case .clear: return "☀️"
        case .sunny: return "🌞"
        case .partlyCloudy: return "⛅"
        case .cloudy: return "☁️"
        case .overcast: return "🌫️"
        case .rainy: return "🌧️"
        case .drizzle: return "🌦️"
        case .thunderstorm: return "⛈️"
        case .snow: return "❄️"
        case .fog: return "🌫️"
        case .windy: return "💨"
        }
    }
}



struct ActiveSessionView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var healthStore: HealthKitManager
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: sessionManager.progress)
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
                    .animation(.linear(duration: 1), value: sessionManager.progress)
                
                VStack {
                    Text(sessionManager.formattedTimeRemaining)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Meditation message with Liquid Glass design
            VStack(spacing: 8) {
                Image(systemName: "figure.mind.and.body")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Focus on your breath")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Let your thoughts flow naturally")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .opacity(0.9)
                    
                    // Glass reflection effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear,
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: UnitPoint(x: 0.1, y: 0.1),
                                endPoint: UnitPoint(x: 0.9, y: 0.9)
                            )
                        )
                }
            )
            
            // Stop button
            Button(action: {
                sessionManager.stopSession()
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
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Select Duration")
                    .font(.headline)
                    .padding()
                
                Text("Maximum: 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                
                // Two wheel pickers side by side
                HStack(spacing: 20) {
                    // Hours picker
                    VStack {
                        Text("Hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Hours", selection: $selectedHours) {
                            ForEach(0...24, id: \.self) { hour in
                                Text("\(hour)")
                                    .tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80, height: 150)
                    }
                    
                    // Minutes picker
                    VStack {
                        Text("Minutes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute)")
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80, height: 150)
                        .disabled(selectedHours == 24) // Disable minutes when at 24 hours
                    }
                }
                .padding()
                
                if selectedHours == 24 && selectedMinutes > 0 {
                    Text("Minutes automatically set to 0 at 24 hours")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                } else if selectedHours == 0 && selectedMinutes == 0 {
                    Text("Please select at least 1 minute")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    // Ensure minimum 1 minute duration
                    if selectedHours == 0 && selectedMinutes == 0 {
                        selectedMinutes = 1
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedHours == 0 && selectedMinutes == 0)
            )
            .onChange(of: selectedHours) { hours in
                // If hours is set to 24, reset minutes to 0
                if hours == 24 {
                    selectedMinutes = 0
                }
            }
            .onChange(of: selectedMinutes) { minutes in
                // Ensure we don't exceed 24 hours total
                if selectedHours == 24 && minutes > 0 {
                    selectedMinutes = 0
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(SessionManager())
} 