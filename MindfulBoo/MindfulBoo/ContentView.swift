import SwiftUI
import HealthKit
import UIKit

// MARK: - Design Tokens  (adaptive: dark / light)
extension Color {
    /// Deep warm charcoal (dark) / Warm linen (light)
    static let mbBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.051, green: 0.047, blue: 0.043, alpha: 1)
            : UIColor(red: 0.961, green: 0.949, blue: 0.929, alpha: 1)
    })
    /// Slightly lighter surface
    static let mbSurface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.096, green: 0.086, blue: 0.078, alpha: 1)
            : UIColor(red: 0.918, green: 0.902, blue: 0.878, alpha: 1)
    })
    /// High-contrast text
    static let mbPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.945, green: 0.922, blue: 0.890, alpha: 1)
            : UIColor(red: 0.110, green: 0.090, blue: 0.075, alpha: 1)
    })
    /// Visible secondary text
    static let mbSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.600, green: 0.565, blue: 0.535, alpha: 1)
            : UIColor(red: 0.430, green: 0.396, blue: 0.373, alpha: 1)
    })
    /// Warm amber accent
    static let mbAccent = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.830, green: 0.698, blue: 0.510, alpha: 1)
            : UIColor(red: 0.580, green: 0.392, blue: 0.145, alpha: 1)
    })
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var healthStore: HealthKitManager
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedMinutes: Int = 5
    @State private var selectedHours: Int = 0
    @State private var isTimerPickerPresented = false
    @State private var showingSettings = false
    @State private var showingStateOfMind = false
    @State private var currentWeather: WeatherCondition = .clear
    @State private var breatheScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 0.25

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    private var orbSize: CGFloat { isIPad ? 210 : 165 }

    var body: some View {
        NavigationView {
            ZStack {
                Color.mbBackground.ignoresSafeArea()

                // Subtle atmospheric centre glow
                RadialGradient(
                    colors: [Color.mbAccent.opacity(0.04), Color.clear],
                    center: .center,
                    startRadius: 60,
                    endRadius: 360
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                    Spacer()

                    if sessionManager.isSessionActive {
                        ActiveSessionView()
                    } else {
                        idleContent
                    }

                    Spacer()

                    bottomBar
                        .padding(.horizontal, 28)
                        .padding(.bottom, 44)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isTimerPickerPresented) {
            DurationPickerView(selectedHours: $selectedHours, selectedMinutes: $selectedMinutes)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStateOfMind) {
            StateOfMindLoggingView()
        }
        .overlay(savedBanner)
        .onAppear {
            currentWeather = getSimulatedWeatherForTime()
            let streakCount = sessionManager.calculateConsecutiveDays()
            healthStore.updateConsecutiveDays(streakCount)

            Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
                currentWeather = getSimulatedWeatherForTime()
            }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                breatheScale   = 1.07
                breatheOpacity = 0.65
            }
        }
        .onChange(of: healthStore.isAuthorized) { _, newValue in
            if newValue {
                let streakCount = sessionManager.calculateConsecutiveDays()
                healthStore.updateConsecutiveDays(streakCount)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top) {
            Button(action: {
                let streakCount = sessionManager.calculateConsecutiveDays()
                healthStore.updateConsecutiveDays(streakCount)
            }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(healthStore.consecutiveDays)")
                        .font(.custom("Georgia", size: 24))
                        .foregroundColor(.mbPrimary)
                    Text("day streak")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(currentWeather.emoji)
                    .font(.system(size: 14))
                Text(getTimeOfDayDescription())
                    .font(.system(size: 8, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)
            }
        }
    }

    // MARK: - Idle Content

    private var idleContent: some View {
        VStack(spacing: 44) {
            Button(action: startMeditation) {
                orbButton
            }
            .buttonStyle(.plain)

            durationSelector

            healthStatusRow
        }
    }

    private var orbButton: some View {
        ZStack {
            // Outermost halo — breathes slowly
            Circle()
                .stroke(Color.mbAccent.opacity(0.06), lineWidth: 1)
                .frame(width: orbSize + 68, height: orbSize + 68)
                .scaleEffect(breatheScale)
                .opacity(breatheOpacity * 0.55)

            // Mid halo
            Circle()
                .stroke(Color.mbAccent.opacity(0.10), lineWidth: 0.7)
                .frame(width: orbSize + 32, height: orbSize + 32)
                .scaleEffect(breatheScale * 0.965)

            // Primary ring — the visual anchor
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.mbAccent.opacity(0.60), Color.mbAccent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
                .frame(width: orbSize, height: orbSize)

            // Inner fill
            Circle()
                .fill(Color.mbSurface)
                .frame(width: orbSize - 2, height: orbSize - 2)

            // Label
            VStack(spacing: 9) {
                Text("begin")
                    .font(.custom("Georgia-Italic", size: isIPad ? 20 : 17))
                    .foregroundColor(Color.mbPrimary.opacity(0.60))

                Circle()
                    .fill(Color.mbAccent.opacity(0.40))
                    .frame(width: 3, height: 3)
            }
        }
    }

    private var durationSelector: some View {
        Button(action: { isTimerPickerPresented = true }) {
            VStack(spacing: 7) {
                Text(formatDurationDisplay())
                    .font(.custom("Georgia", size: isIPad ? 42 : 36))
                    .foregroundColor(.mbPrimary)

                HStack(spacing: 5) {
                    Text("duration")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .light))
                        .foregroundColor(.mbSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var healthStatusRow: some View {
        HStack(spacing: 20) {
            if healthStore.isAuthorized {
                miniLabel(icon: "heart.fill", text: "health")
            } else {
                Button(action: { healthStore.requestPermissions() }) {
                    miniLabel(icon: "heart", text: "enable health", tint: .red.opacity(0.65))
                }
                .buttonStyle(.plain)
            }

            if healthStore.canLogStateOfMind {
                miniLabel(icon: "circle.dotted", text: "mood")
            } else {
                Button(action: { healthStore.requestPermissions() }) {
                    miniLabel(icon: "brain.head.profile", text: "enable mood", tint: .orange.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func miniLabel(icon: String, text: String, tint: Color = Color.mbAccent.opacity(0.70)) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(.mbSecondary)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            iconButton(icon: "heart", label: "mood") { showingStateOfMind = true }
            Spacer()
            iconButton(icon: "gearshape", label: "settings") { showingSettings = true }
        }
    }

    private func iconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Circle()
                    .stroke(Color.mbSecondary.opacity(0.22), lineWidth: 0.7)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .ultraLight))
                            .foregroundColor(.mbSecondary)
                    )
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.mbSecondary.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Saved Banner

    private var savedBanner: some View {
        VStack {
            Spacer()
            if sessionManager.showSessionSavedMessage {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.mbAccent.opacity(0.80))
                        .frame(width: 5, height: 5)
                    Text("session saved")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.mbSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.mbSecondary.opacity(0.12), lineWidth: 0.5))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: sessionManager.showSessionSavedMessage)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Helpers

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
        let duration = TimeInterval(totalMinutes * 60)
        sessionManager.startSession(duration: duration)
    }

    private func getTimeOfDayDescription() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<8:  return "early morning"
        case 8..<12: return "morning"
        case 12..<14: return "midday"
        case 14..<17: return "afternoon"
        case 17..<20: return "evening"
        default:     return "night"
        }
    }

    private func getSimulatedWeatherForTime() -> WeatherCondition {
        let hour  = Calendar.current.component(.hour, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        switch (hour, month) {
        case (_, 6...8):       return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
        case (_, 12), (_, 1...2): return [.cloudy, .overcast, .drizzle, .snow].randomElement() ?? .cloudy
        case (5..<8, _):       return [.clear, .fog, .partlyCloudy].randomElement() ?? .clear
        case (8..<12, _):      return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
        case (12..<14, _):     return [.sunny, .clear, .partlyCloudy].randomElement() ?? .sunny
        case (14..<17, _):     return [.sunny, .partlyCloudy, .cloudy].randomElement() ?? .sunny
        case (17..<20, _):     return [.partlyCloudy, .clear, .cloudy].randomElement() ?? .partlyCloudy
        default:               return [.clear, .cloudy, .overcast].randomElement() ?? .clear
        }
    }
}

// MARK: - Active Session View

struct ActiveSessionView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var healthStore: HealthKitManager
    @State private var breatheScale: CGFloat = 1.0
    @State private var breatheOpacity: Double = 0.18

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    private var ringSize: CGFloat { isIPad ? 250 : 196 }

    var body: some View {
        VStack(spacing: 0) {
            // Large serif countdown
            VStack(spacing: 10) {
                Text(sessionManager.formattedTimeRemaining)
                    .font(.custom("Georgia", size: isIPad ? 78 : 62))
                    .monospacedDigit()
                    .foregroundColor(.mbPrimary)

                Text("remaining")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(3.5)
                    .textCase(.uppercase)
                    .foregroundColor(.mbSecondary)
            }

            Spacer().frame(height: 52)

            // Elegant progress ring
            ZStack {
                // Breathing atmospheric halo (fades when paused)
                Circle()
                    .stroke(Color.mbAccent.opacity(0.06), lineWidth: 1)
                    .frame(width: ringSize + 48, height: ringSize + 48)
                    .scaleEffect(breatheScale)
                    .opacity(sessionManager.isPaused ? 0 : breatheOpacity)

                // Track
                Circle()
                    .stroke(Color.mbSecondary.opacity(0.10), lineWidth: 0.7)
                    .frame(width: ringSize, height: ringSize)

                // Progress arc
                Circle()
                    .trim(from: 0, to: sessionManager.progress)
                    .stroke(
                        Color.mbAccent.opacity(0.68),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.9), value: sessionManager.progress)

                // Centre label
                Text(sessionManager.isPaused ? "paused" : "breathe")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundColor(
                        sessionManager.isPaused
                            ? Color.mbAccent.opacity(0.70)
                            : Color.mbSecondary.opacity(0.60)
                    )
            }

            Spacer().frame(height: 62)

            // Action buttons row
            HStack(spacing: 20) {
                // Pause / Resume
                Button(action: {
                    if sessionManager.isPaused {
                        sessionManager.resumeSession()
                    } else {
                        sessionManager.pauseSession()
                    }
                }) {
                    Text(sessionManager.isPaused ? "resume" : "pause")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(sessionManager.isPaused ? Color.mbAccent : .mbSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    sessionManager.isPaused ? Color.mbAccent.opacity(0.45) : Color.mbSecondary.opacity(0.20),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)

                // End Session
                Button(action: { sessionManager.stopSession() }) {
                    Text("end")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundColor(.mbSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.mbSecondary.opacity(0.20), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                breatheScale   = 1.10
                breatheOpacity = 0.58
            }
        }
    }
}

// MARK: - Duration Picker View

struct DurationPickerView: View {
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int
    @Environment(\.presentationMode) var presentationMode

    private var totalMinutes: Int { selectedHours * 60 + selectedMinutes }

    private var formattedDuration: String {
        if selectedHours == 0      { return "\(selectedMinutes) min" }
        else if selectedMinutes == 0 { return "\(selectedHours)h" }
        else                         { return "\(selectedHours)h \(selectedMinutes)m" }
    }

    var body: some View {
        ZStack {
            Color.mbBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("duration")
                            .font(.custom("Georgia-Italic", size: 30))
                            .foregroundColor(.mbPrimary)
                        Text("set your intention")
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
                .padding(.bottom, 36)

                // Current selection display
                VStack(alignment: .leading, spacing: 6) {
                    Text(formattedDuration)
                        .font(.custom("Georgia", size: 52))
                        .foregroundColor(.mbPrimary)
                        .padding(.horizontal, 28)

                    if totalMinutes > 0 {
                        Text("\(totalMinutes) minutes total")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                            .padding(.horizontal, 28)
                    }
                }
                .padding(.bottom, 44)

                // Wheel pickers
                HStack(alignment: .center, spacing: 0) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text("hours")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                        Picker("Hours", selection: $selectedHours) {
                            ForEach(0...24, id: \.self) { h in
                                Text("\(h)")
                                    .font(.custom("Georgia", size: 24))
                                    .foregroundColor(.mbPrimary)
                                    .tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 180)
                        .colorScheme(.dark)
                    }

                    Text("·")
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(Color.mbSecondary.opacity(0.35))
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    VStack(spacing: 10) {
                        Text("minutes")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundColor(.mbSecondary)
                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(0...59, id: \.self) { m in
                                Text("\(m)")
                                    .font(.custom("Georgia", size: 24))
                                    .foregroundColor(.mbPrimary)
                                    .tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 180)
                        .colorScheme(.dark)
                        .disabled(selectedHours == 24)
                        .opacity(selectedHours == 24 ? 0.35 : 1.0)
                    }

                    Spacer()
                }

                if selectedHours == 0 && selectedMinutes == 0 {
                    Text("select at least 1 minute")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.red.opacity(0.60))
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                }

                Spacer()

                // Confirm button — full-width minimal line
                Button(action: {
                    if selectedHours == 0 && selectedMinutes == 0 { selectedMinutes = 1 }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Spacer()
                        Text("confirm")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(3)
                            .textCase(.uppercase)
                            .foregroundColor(totalMinutes == 0 ? .mbSecondary : .mbPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 18)
                    .overlay(
                        Rectangle()
                            .stroke(Color.mbSecondary.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .disabled(totalMinutes == 0)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onChange(of: selectedHours) { _, newValue in
            if newValue == 24 { selectedMinutes = 0 }
        }
        .onChange(of: selectedMinutes) { _, newValue in
            if selectedHours == 24 && newValue > 0 { selectedMinutes = 0 }
        }
    }
}

// MARK: - Weather Condition

enum WeatherCondition: String, CaseIterable {
    case clear        = "Clear"
    case sunny        = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case cloudy       = "Cloudy"
    case overcast     = "Overcast"
    case rainy        = "Rainy"
    case drizzle      = "Drizzle"
    case thunderstorm = "Thunderstorm"
    case snow         = "Snow"
    case fog          = "Fog"
    case windy        = "Windy"

    var emoji: String {
        switch self {
        case .clear:        return "☀️"
        case .sunny:        return "🌞"
        case .partlyCloudy: return "⛅"
        case .cloudy:       return "☁️"
        case .overcast:     return "🌫️"
        case .rainy:        return "🌧️"
        case .drizzle:      return "🌦️"
        case .thunderstorm: return "⛈️"
        case .snow:         return "❄️"
        case .fog:          return "🌫️"
        case .windy:        return "💨"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(SessionManager())
}
