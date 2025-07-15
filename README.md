# 🧘‍♀️ MindfulBoo - iOS Meditation App

A comprehensive meditation app for iOS that integrates with Apple Watch for real-time health monitoring during meditation sessions.

## ✨ Features

### 🎯 Core Meditation
- **Customizable meditation timer** with audio feedback
- **Progress tracking** with visual countdown
- **Session history** with detailed statistics
- **Completion streaks** and performance metrics

### 💓 Health Integration
- **Real-time heart rate monitoring** from Apple Watch
- **Respiratory rate tracking** during sessions
- **HealthKit integration** for mindfulness session logging
- **Health app synchronization** for comprehensive wellness tracking

### 📊 Session Management
- **Session history view** with statistics dashboard
- **Individual session deletion** with swipe gestures
- **Bulk deletion** with confirmation dialogs
- **Session completion rates** and average duration tracking

### 🎨 User Experience
- **Modern SwiftUI interface** with smooth animations
- **Custom app icon** (MindfulBoo branding)
- **Intelligent permission handling** with robust HealthKit access
- **Real-time monitoring display** with live health metrics

## 🛠️ Technical Details

### Requirements
- **iOS 15.0+**
- **Xcode 14.0+**
- **Apple Watch** (for heart rate monitoring)
- **HealthKit permissions** for heart rate and mindfulness data

### Architecture
- **SwiftUI** for modern, declarative UI
- **HealthKit** for health data integration
- **Combine** for reactive data binding
- **UserDefaults** for local session storage
- **AVFoundation** for audio session management

### Key Components
- `MeditationManager` - Core session logic and health data coordination
- `HealthKitManager` - HealthKit integration and Apple Watch monitoring
- `MeditationSession` - Data model for session tracking
- `SessionHistoryView` - Comprehensive session history with analytics

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/evangelosmeklis/mindfulboo.git
   cd mindfulboo
   ```

2. **Open in Xcode**
   ```bash
   open mediation.xcodeproj
   ```

3. **Configure permissions**
   - The app will automatically request HealthKit permissions
   - Grant access to Heart Rate and Mindfulness data
   - Ensure Apple Watch is paired for monitoring features

4. **Build and run**
   - Select your target device
   - Build and install the app
   - Start your first meditation session!

## 📱 Usage

### Starting a Session
1. Set your desired meditation duration
2. Tap "Start Meditation" 
3. Apple Watch will automatically begin monitoring
4. Follow the timer and focus on your breathing

### Viewing History
1. Navigate to "Session History"
2. View your meditation statistics
3. Review individual sessions
4. Delete sessions as needed

### Health Integration
- Sessions automatically sync to Health app
- Heart rate data appears in real-time during sessions
- Respiratory rate is tracked when available
- All data respects your privacy settings

## 🔧 Development

### Project Structure
```
mediation/
├── mediation/
│   ├── ContentView.swift          # Main meditation interface
│   ├── MeditationAppApp.swift     # App entry point
│   ├── Managers/
│   │   ├── HealthKitManager.swift     # Health integration
│   │   └── MeditationManager.swift    # Session management
│   ├── Models/
│   │   └── MeditationSession.swift    # Session data model
│   ├── Views/
│   │   └── SessionHistoryView.swift   # History interface
│   └── Assets.xcassets/           # App icons and assets
├── mediationTests/               # Unit tests
└── mediationUITests/            # UI tests
```

### Key Features Implementation
- **Robust permission handling** - Works even when iOS reports incorrect HealthKit status
- **Real-time monitoring** - Uses HKAnchoredObjectQuery for live health data
- **Smart authorization** - Tests actual data access beyond reported permissions
- **Modern UI patterns** - SwiftUI with Combine for reactive updates

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is available for personal and educational use.

---

**MindfulBoo** - Mindful meditation with intelligent health monitoring 🧘‍♀️💓 