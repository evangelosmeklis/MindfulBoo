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
    @State private var headerAnimation = false
    @State private var buttonScale = false

    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top section with streak and weather
                HStack {
                    // Enhanced Consecutive days streak
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            .orange.opacity(0.3),
                                            .clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 20
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .scaleEffect(headerAnimation ? 1.2 : 1.0)

                            Text("⚡")
                                .font(.title2)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(healthStore.consecutiveDays)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text(healthStore.consecutiveDays == 1 ? "DAY STREAK" : "DAY STREAK")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .tracking(1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .orange.opacity(0.15),
                                                    .red.opacity(0.1),
                                                    .clear
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )

                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.clear,
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .orange.opacity(0.5),
                                            .orange.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .shadow(color: .orange.opacity(0.2), radius: 15, x: 0, y: 8)
                    .onTapGesture {
                        print("🐛 DEBUG TAP: Forcing streak recalculation...")
                        print("📊 Current sessions count: \(sessionManager.sessions.count)")

                        let recentSessions = sessionManager.sessions.suffix(5)
                        for session in recentSessions {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            print("   - Session: \(formatter.string(from: session.startDate))")
                        }

                        let streakCount = sessionManager.calculateConsecutiveDays()
                        healthStore.updateConsecutiveDays(streakCount)
                        healthStore.debugPermissions()
                    }

                    Spacer()

                    // Weather indicator
                    HStack(spacing: 6) {
                        Text(currentWeather.emoji)
                            .font(.body)
                        Text(getTimeOfDayDescription())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(.ultraThinMaterial)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Current session or timer setup
                if sessionManager.isSessionActive {
                    ActiveSessionView()
                } else {
                    // Circular start button centered
                    VStack(spacing: 40) {
                        // Large circular start button
                        Button(action: startMeditation) {
                            ZStack {
                                // Outer pulsing glow
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                .green.opacity(0.4),
                                                .blue.opacity(0.3),
                                                .clear
                                            ]),
                                            center: .center,
                                            startRadius: 60,
                                            endRadius: 110
                                        )
                                    )
                                    .frame(width: 220, height: 220)
                                    .scaleEffect(buttonScale ? 1.1 : 1.0)
                                    .opacity(buttonScale ? 0.8 : 0.5)

                                // Main circular button
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.85, blue: 0.4),
                                                Color(red: 0.1, green: 0.7, blue: 0.95),
                                                Color(red: 0.3, green: 0.55, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 160, height: 160)
                                    .overlay(
                                        Circle()
                                            .fill(.thinMaterial)
                                            .opacity(0.2)
                                    )
                                    .overlay(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.6),
                                                        Color.clear,
                                                        Color.white.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .blendMode(.overlay)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.6),
                                                        .cyan.opacity(0.4)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 3
                                            )
                                    )
                                    .shadow(color: .green.opacity(0.5), radius: 30, x: 0, y: 15)
                                    .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)

                                // Play icon
                                Image(systemName: "play.fill")
                                    .font(.system(size: 52, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .scaleEffect(buttonScale ? 1.05 : 1.0)

                        // Duration selector below button
                        VStack(spacing: 12) {
                            Text("DURATION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .tracking(2)

                            Button(action: {
                                isTimerPickerPresented = true
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.fill")
                                        .font(.title3)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )

                                    Text(formatDurationDisplay())
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)

                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                .blue.opacity(0.08),
                                                                .cyan.opacity(0.04),
                                                                .clear
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            )

                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.4),
                                                        Color.clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )

                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        .blue.opacity(0.3),
                                                        .cyan.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    }
                                )
                                .shadow(color: .blue.opacity(0.15), radius: 10, x: 0, y: 5)
                            }
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

                // Bottom actions with enhanced minimal design
                HStack(spacing: 24) {
                    Spacer()

                    // Mood Log Button
                    Button(action: { showingStateOfMind = true }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                .pink.opacity(0.2),
                                                .clear
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 30
                                        )
                                    )
                                    .frame(width: 60, height: 60)

                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        .pink.opacity(0.1),
                                                        .clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        .pink.opacity(0.4),
                                                        .pink.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 56, height: 56)

                                Image(systemName: "heart.fill")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.pink, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("Mood")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .shadow(color: .pink.opacity(0.15), radius: 8, x: 0, y: 4)

                    // Settings Button
                    Button(action: { showingSettings = true }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                .gray.opacity(0.15),
                                                .clear
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 30
                                        )
                                    )
                                    .frame(width: 60, height: 60)

                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        .gray.opacity(0.3),
                                                        .gray.opacity(0.15)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 56, height: 56)

                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.gray, .secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("Settings")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Spacer()
                }
                .padding(.bottom, 40)
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

            // Start animations
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                headerAnimation = true
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                buttonScale = true
            }
        }
        .onChange(of: healthStore.isAuthorized) { oldValue, newValue in
            if newValue {
                let streakCount = sessionManager.calculateConsecutiveDays()
                healthStore.updateConsecutiveDays(streakCount)
                print("🐛 Debug: Authorization changed to \(newValue), recalculating consecutive days")
            }
        }
    }
    
    private func formatDurationDisplay() -> String {
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
    @State private var pulseAnimation = false
    @State private var breatheAnimation = false
    @State private var rotationDegrees = 0.0

    var body: some View {
        VStack(spacing: 40) {
            // Enhanced progress circle with animations
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.green.opacity(0.3), .blue.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 20
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 10)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .opacity(pulseAnimation ? 0.6 : 0.3)

                // Background track
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 12
                    )
                    .frame(width: 220, height: 220)

                // Progress arc with gradient
                Circle()
                    .trim(from: 0, to: sessionManager.progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .green,
                                .cyan,
                                .blue,
                                .purple,
                                sessionManager.progress > 0.8 ? .pink : .purple
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: sessionManager.progress)
                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 0)

                // Inner breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                .green.opacity(0.15),
                                .blue.opacity(0.1),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(breatheAnimation ? 1.1 : 0.95)
                    .opacity(breatheAnimation ? 0.8 : 0.4)

                // Time display with enhanced styling
                VStack(spacing: 4) {
                    Text(sessionManager.formattedTimeRemaining)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 2)

                    Text("remaining")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(2)
                }

                // Spinning meditation icon overlay
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: -130)
                    .rotationEffect(.degrees(rotationDegrees))
                    .opacity(0.6)
            }

            // Enhanced meditation message
            VStack(spacing: 12) {
                ZStack {
                    // Animated background orb
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    .green.opacity(0.2),
                                    .clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)

                    Image(systemName: "figure.mind.and.body")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
                }

                Text("Focus on your breath")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Let your thoughts flow naturally")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 32)
            .background(
                ZStack {
                    // Animated glass background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .green.opacity(0.1),
                                            .blue.opacity(0.05),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    // Shimmering highlight
                    RoundedRectangle(cornerRadius: 24)
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

                    // Subtle border
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

            // Enhanced stop button
            Button(action: {
                sessionManager.stopSession()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                    Text("End Session")
                        .fontWeight(.semibold)
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(
                    ZStack {
                        // Gradient background
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        // Glass overlay
                        Capsule()
                            .fill(.thinMaterial)
                            .opacity(0.2)

                        // Highlight
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.4),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(pulseAnimation ? 1.02 : 1.0)
        }
        .onAppear {
            // Continuous breathing animation
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breatheAnimation = true
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }

            // Rotation animation for sparkles
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }
        }
    }
}

struct DurationPickerView: View {
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var glowAnimation = false

    private var totalMinutes: Int {
        selectedHours * 60 + selectedMinutes
    }

    private var formattedDuration: String {
        if selectedHours == 0 {
            return "\(selectedMinutes) min"
        } else if selectedMinutes == 0 {
            return "\(selectedHours)h"
        } else {
            return "\(selectedHours)h \(selectedMinutes)m"
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.15, blue: 0.3),
                        Color(red: 0.15, green: 0.25, blue: 0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header with icon
                    VStack(spacing: 16) {
                        ZStack {
                            // Pulsing glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            .blue.opacity(0.4),
                                            .clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 50
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .scaleEffect(glowAnimation ? 1.2 : 1.0)
                                .opacity(glowAnimation ? 0.6 : 0.3)

                            // Icon
                            Image(systemName: "clock.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                        }

                        Text("Session Duration")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Maximum: 24 hours")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1.5)
                    }
                    .padding(.top, 40)

                    // Current selection display
                    VStack(spacing: 8) {
                        Text(formattedDuration)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)

                        if totalMinutes > 0 {
                            Text("\(totalMinutes) total minutes")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.1),
                                                    .clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )

                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .padding(.horizontal, 32)

                    // Pickers container
                    HStack(spacing: 24) {
                        // Hours picker
                        VStack(spacing: 12) {
                            Text("HOURS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)

                            Picker("Hours", selection: $selectedHours) {
                                ForEach(0...24, id: \.self) { hour in
                                    Text("\(hour)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 100, height: 180)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }

                        // Colon separator
                        Text(":")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                            .offset(y: 20)

                        // Minutes picker
                        VStack(spacing: 12) {
                            Text("MINUTES")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(2)

                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach(0...59, id: \.self) { minute in
                                    Text("\(minute)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .tag(minute)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 100, height: 180)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .disabled(selectedHours == 24)
                            .opacity(selectedHours == 24 ? 0.5 : 1.0)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Warning messages
                    Group {
                        if selectedHours == 24 && selectedMinutes > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Minutes automatically set to 0 at 24 hours")
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .fill(.orange.opacity(0.2))
                                    )
                            )
                        } else if selectedHours == 0 && selectedMinutes == 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text("Please select at least 1 minute")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .fill(.red.opacity(0.2))
                                    )
                            )
                        }
                    }

                    Spacer()

                    // Done button
                    Button(action: {
                        if selectedHours == 0 && selectedMinutes == 0 {
                            selectedMinutes = 1
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("Set Duration")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.85, blue: 0.4),
                                                Color(red: 0.1, green: 0.7, blue: 0.95)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                Capsule()
                                    .fill(.thinMaterial)
                                    .opacity(0.2)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.5),
                                                .clear,
                                                .white.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blendMode(.overlay)

                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.5), .cyan.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            }
                        )
                        .shadow(color: .green.opacity(0.4), radius: 20, x: 0, y: 10)
                    }
                    .disabled(selectedHours == 0 && selectedMinutes == 0)
                    .opacity((selectedHours == 0 && selectedMinutes == 0) ? 0.5 : 1.0)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .frame(width: 32, height: 32)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
            .onChange(of: selectedHours) { oldValue, newValue in
                if newValue == 24 {
                    selectedMinutes = 0
                }
            }
            .onChange(of: selectedMinutes) { oldValue, newValue in
                if selectedHours == 24 && newValue > 0 {
                    selectedMinutes = 0
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowAnimation = true
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