# Mindful - Meditation App with Apple Watch Integration

A comprehensive meditation app for iPhone with Apple Watch companion that tracks heart rate and breathing patterns during meditation sessions.

## Features

### 📱 iOS App
- **Meditation Timer**: Customizable session durations (5-60 minutes)
- **Beautiful UI**: Modern, calming interface with gradient animations
- **Session History**: Track all your meditation sessions with detailed metrics
- **Health Integration**: Automatic saving to Apple Health (Mindfulness category)
- **Real-time Metrics**: Live heart rate and breathing rate display during sessions
- **Charts & Analytics**: Detailed post-session analysis with interactive charts

### ⌚ Apple Watch App
- **Workout Integration**: Uses HealthKit workout sessions for accurate tracking
- **Continuous Heart Rate**: Monitors heart rate throughout meditation
- **Breathing Rate Tracking**: Estimates breathing rate using Respiratory Sinus Arrhythmia (RSA)
- **Independent Operation**: Can function without iPhone connection
- **Auto-sync**: Data syncs seamlessly with iPhone when connected

### 🏥 Health Data Integration
- **HealthKit Permissions**: Reads heart rate, respiratory rate, writes mindfulness sessions
- **Privacy First**: All data stays on device and syncs through HealthKit
- **Medical Grade**: Uses Apple Watch's medical-grade sensors

## Technical Implementation

### Breathing Rate Monitoring
The app uses **Respiratory Sinus Arrhythmia (RSA)** to estimate breathing rate:

- **How it works**: Heart rate naturally varies with breathing (increases on inhale, decreases on exhale)
- **Data Source**: Analyzes heart rate variability patterns from Apple Watch
- **Accuracy**: Most reliable during sleep/rest, may be less accurate during active meditation
- **Availability**: Breathing rate data available when sufficient RSA signal is detected

**Note**: While the Apple Watch excels at heart rate monitoring, breathing rate is estimated and may not always be available during meditation sessions. The app gracefully handles this by focusing primarily on heart rate data.

### Architecture

```
MeditationApp/
├── iOS App (iPhone)
│   ├── MeditationAppApp.swift       # Main app entry point
│   ├── ContentView.swift            # Primary UI
│   ├── Managers/
│   │   ├── HealthKitManager.swift   # HealthKit integration
│   │   └── MeditationManager.swift  # Session management
│   ├── Views/
│   │   └── SessionHistoryView.swift # History & analytics
│   └── Models/
│       └── MeditationSession.swift  # Data models
├── WatchKit App (Apple Watch)
│   ├── WatchAppApp.swift           # Watch app entry
│   ├── WatchContentView.swift      # Watch UI
│   └── Managers/
│       ├── WatchHealthManager.swift    # Watch HealthKit
│       └── WatchWorkoutManager.swift   # Workout sessions
└── Shared/
    └── WatchConnectivityManager.swift # iPhone ↔ Watch sync
```

## Health Data Permissions

The app requests the following HealthKit permissions:

### Read Access
- **Heart Rate**: Monitor during meditation sessions
- **Respiratory Rate**: Track breathing patterns when available
- **Mindful Sessions**: View existing meditation history

### Write Access
- **Mindful Sessions**: Save completed meditation sessions to Health app

## Installation & Setup

### Requirements
- iOS 17.0 or later
- watchOS 10.0 or later
- iPhone paired with Apple Watch
- HealthKit availability

### Setup Steps
1. **Install**: Deploy app to iPhone and Apple Watch
2. **Health Permissions**: Grant HealthKit permissions on first launch
3. **Watch Pairing**: Ensure Apple Watch is properly paired
4. **Start Meditating**: Choose duration and begin your first session

## Usage

### Starting a Session
1. **Choose Duration**: Select from 5-60 minutes
2. **Health Check**: Ensure HealthKit permissions are granted
3. **Start**: Tap "Start Meditation" button
4. **Watch Sync**: Watch automatically begins workout session

### During Meditation
- **Progress Circle**: Visual progress indicator
- **Live Metrics**: Current heart rate and breathing rate (when available)
- **Time Remaining**: Countdown timer
- **Apple Watch**: Independent tracking with pause/stop controls

### After Session
- **Automatic Save**: Session saved to local storage and HealthKit
- **Completion Sound**: Gentle alert when session ends
- **View Details**: Tap session in history for detailed analytics
- **Charts**: Heart rate and breathing rate trends over time

## Data & Privacy

- **Local Storage**: All data stored locally on device
- **HealthKit Integration**: Optional sync with Apple Health app
- **No Cloud Sync**: Data never leaves your devices
- **User Control**: Full control over data sharing and permissions

## Limitations & Considerations

### Breathing Rate Monitoring
- **Best During**: Sleep, rest, minimal movement
- **Limited During**: Active meditation, movement, talking
- **Fallback**: App focuses on heart rate when breathing data unavailable
- **Research Based**: Uses established RSA methodology from medical literature

### Apple Watch Requirements
- **Workout Permission**: Requires HealthKit workout permissions
- **Placement**: Proper watch fit essential for accurate readings
- **Battery**: Extended sessions may impact watch battery life

## Future Enhancements

- **Guided Meditations**: Audio guidance during sessions
- **Breathing Exercises**: Structured breathing pattern training
- **Sleep Integration**: Pre-sleep meditation recommendations
- **Advanced Analytics**: Weekly/monthly trend analysis
- **Mindfulness Reminders**: Intelligent notification system

## Contributing

This app demonstrates best practices for:
- HealthKit integration
- Apple Watch workout sessions
- Watch Connectivity framework
- SwiftUI health apps
- Real-time biometric monitoring

## Health Disclaimer

This app is for wellness and meditation purposes only. It is not intended for medical diagnosis or treatment. Consult healthcare professionals for medical advice.

## Technical Notes

### Respiratory Rate Research
Based on extensive research including:
- Apple's official HealthKit documentation
- Medical research on Respiratory Sinus Arrhythmia
- Apple Watch capabilities and limitations
- Clinical studies on breathing rate monitoring

The implementation provides breathing rate data when technically feasible while maintaining transparency about limitations.

---

*Built with ❤️ for mindfulness and wellness* 