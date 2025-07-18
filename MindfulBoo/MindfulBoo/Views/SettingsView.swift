import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom tab picker
                HStack(spacing: 0) {
                    TabButton(
                        title: "Session",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: "Daily Reminders",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Tab content
                TabView(selection: $selectedTab) {
                    SessionNotificationSettingsView()
                        .tag(0)
                    
                    DailyReminderSettingsView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Session Notification Settings

struct SessionNotificationSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Notifications")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configure how often you receive notifications during your meditation sessions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Enable/Disable toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session Notifications")
                                .font(.headline)
                            Text("Enable notifications during meditation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsManager.settings.sessionNotifications.isEnabled },
                            set: { _ in settingsManager.toggleSessionNotifications() }
                        ))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if settingsManager.settings.sessionNotifications.isEnabled {
                    // Interval notifications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Interval Notifications")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(SessionNotificationSettings.NotificationInterval.allCases, id: \.self) { interval in
                                IntervalOptionRow(
                                    interval: interval,
                                    isSelected: settingsManager.settings.sessionNotifications.intervalType == interval
                                ) {
                                    settingsManager.updateSessionNotificationInterval(interval)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Progress notifications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Progress Notifications")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Get notified at specific points during your session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(SessionNotificationSettings.ProgressNotification.allCases, id: \.self) { notification in
                                ProgressNotificationRow(
                                    notification: notification,
                                    isEnabled: settingsManager.settings.sessionNotifications.progressNotifications.contains(notification)
                                ) {
                                    settingsManager.toggleProgressNotification(notification)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
}

struct IntervalOptionRow: View {
    let interval: SessionNotificationSettings.NotificationInterval
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(interval.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if interval != .none {
                        Text("Every \(Int(interval.intervalSeconds / 60)) minute\(interval.intervalSeconds == 60 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No interval notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressNotificationRow: View {
    let notification: SessionNotificationSettings.ProgressNotification
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(notification.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Daily Reminder Settings

struct DailyReminderSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAddReminder = false
    @State private var newReminderTime = Date()
    @State private var newReminderMessage = "Time for your daily meditation 🧘‍♀️"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Reminders")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Set up to 10 daily reminders to help you maintain your meditation practice.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Enable/Disable toggle
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Reminders")
                                .font(.headline)
                            Text("Enable daily meditation reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { settingsManager.settings.dailyReminders.isEnabled },
                            set: { _ in settingsManager.toggleDailyReminders() }
                        ))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if settingsManager.settings.dailyReminders.isEnabled {
                    // Add reminder button
                    if settingsManager.settings.dailyReminders.reminders.count < 10 {
                        Button(action: { showingAddReminder = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Reminder")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Reminders list
                    if !settingsManager.settings.dailyReminders.reminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Reminders")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(settingsManager.settings.dailyReminders.reminders.enumerated()), id: \.element.id) { index, reminder in
                                DailyReminderRow(
                                    reminder: reminder,
                                    isEnabled: reminder.isEnabled,
                                    onToggle: { settingsManager.toggleDailyReminder(at: index) },
                                    onDelete: { settingsManager.removeDailyReminder(at: index) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No reminders set")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add your first reminder to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(
                time: $newReminderTime,
                message: $newReminderMessage,
                onSave: {
                    settingsManager.addDailyReminder(time: newReminderTime, message: newReminderMessage)
                    showingAddReminder = false
                    // Reset for next time
                    newReminderTime = Date()
                    newReminderMessage = "Time for your daily meditation 🧘‍♀️"
                }
            )
        }
    }
}

struct DailyReminderRow: View {
    let reminder: DailyReminderSettings.DailyReminder
    let isEnabled: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.formattedTime)
                    .font(.headline)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Text(reminder.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                ))
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? Color(.systemGray6) : Color(.systemGray5))
        )
    }
}

struct AddReminderView: View {
    @Binding var time: Date
    @Binding var message: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    private let defaultMessages = [
        "Time for your daily meditation 🧘‍♀️",
        "Take a moment to breathe and center yourself 🌸",
        "Your mindfulness practice awaits ✨",
        "Time to find your inner peace 🕯️",
        "A few minutes of meditation can transform your day 🌅",
        "Your mental wellness matters - take a meditation break 💚",
        "Pause, breathe, and reconnect with yourself 🍃"
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Time picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reminder Time")
                        .font(.headline)
                    
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                
                // Message input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message")
                        .font(.headline)
                    
                    TextField("Reminder message", text: $message, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3)
                    
                    Text("Suggested messages:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(defaultMessages, id: \.self) { defaultMessage in
                                Button(defaultMessage) {
                                    message = defaultMessage
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(16)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Reminder")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}