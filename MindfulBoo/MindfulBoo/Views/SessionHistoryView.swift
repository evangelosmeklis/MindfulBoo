import SwiftUI

struct SessionHistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var healthStore: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSession: Session?
    @State private var showingDeleteAllAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if sessionManager.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        // Summary section
                        Section {
                            SessionSummaryStatsView(sessions: sessionManager.sessions)
                        }
                        
                        // Sessions list
                        Section("Recent Sessions") {
                            ForEach(sessionManager.sessions.reversed()) { session in
                                SessionRowView(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                    }
                            }
                            .onDelete(perform: deleteSession)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Session History")
            .navigationBarItems(
                leading: sessionManager.sessions.isEmpty ? nil : Button("Delete All") {
                    showingDeleteAllAlert = true
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Delete All Sessions", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    sessionManager.deleteAllSessions()
                }
            } message: {
                Text("Are you sure you want to delete all meditation sessions from MindfulBoo? This action cannot be undone. Your mindful minutes will remain safely stored in your Health app.")
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }
    
    private func deleteSession(at offsets: IndexSet) {
        let reversedSessions = sessionManager.sessions.reversed()
        for index in offsets {
            let sessionIndex = Array(reversedSessions).indices[index]
            let session = Array(reversedSessions)[sessionIndex]
            sessionManager.deleteSession(session)
        }
    }
}

struct SessionSummaryStatsView: View {
    let sessions: [Session]
    
    private var totalSessions: Int {
        sessions.count
    }
    
    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.effectiveDuration }
    }
    
    private var completedSessions: Int {
        sessions.filter { $0.isCompleted }.count
    }
    
    private var averageSessionLength: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalDuration / Double(sessions.count)
    }
    
    private var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var formattedAverageLength: String {
        let minutes = Int(averageSessionLength) / 60
        return "\(minutes)m"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Your Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatsCard(
                    title: "Total Time",
                    value: formattedTotalDuration,
                    icon: "clock.fill",
                    color: .green
                )
                
                StatsCard(
                    title: "Sessions",
                    value: "\(totalSessions)",
                    icon: "leaf.fill",
                    color: .blue
                )
                
                StatsCard(
                    title: "Average",
                    value: formattedAverageLength,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
            
            if totalSessions > 0 {
                HStack {
                    Text("Completion Rate:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(Double(completedSessions) / Double(totalSessions) * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                // Liquid Glass base
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .opacity(0.9)
                
                // Glass shine effect
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
                
                // Subtle border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                // Liquid Glass card background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .opacity(0.8)
                
                // Specular highlight
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.clear,
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("No sessions yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start your first meditation session to see your progress here. Your sessions will be saved locally and synced to the Health app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Image(systemName: "arrow.down.circle")
                .font(.title)
                .foregroundColor(.blue)
                .padding(.top)
        }
        .padding()
    }
}

struct SessionRowView: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.formattedDate)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.formattedDuration)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Completion status
                    HStack {
                        Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                            .foregroundColor(session.isCompleted ? .green : .orange)
                            .font(.caption)
                        Text("\(Int(session.completionPercentage * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(session.completionPercentage >= 1.0 ? .green : .orange)
                    }
                    
                    // Health app sync indicator
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text("Health Sync")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * session.completionPercentage, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                // Liquid Glass row background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.9)
                
                // Glass reflection
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle glass border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session Summary
                    SessionSummaryCard(session: session)
                    
                    // Session insights
                    SessionInsightsCard(session: session)
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarItems(
                leading: Button("Delete") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red),
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Delete Session", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    sessionManager.deleteSession(session)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this meditation session from MindfulBoo? This action cannot be undone. Your mindful minutes will remain safely stored in your Health app.")
            }
        }
    }
}

struct SessionSummaryCard: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Summary")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Label("Date", systemImage: "calendar")
                    Spacer()
                    Text(session.formattedDate)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Duration", systemImage: "clock")
                    Spacer()
                    Text(session.formattedDuration)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Completion", systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(Int(session.completionPercentage * 100))%")
                        .foregroundColor(session.completionPercentage >= 1.0 ? .green : .orange)
                }
                
                HStack {
                    Label("Health Sync", systemImage: "heart.fill")
                    Spacer()
                    Text("Synced")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                // Liquid Glass card
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .opacity(0.9)
                
                // Glass highlight
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

struct SessionInsightsCard: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Insights")
                .font(.headline)
            
            VStack(spacing: 12) {
                if session.isCompleted {
                    InsightRow(
                        icon: "checkmark.circle.fill",
                        title: "Session Completed",
                        description: "Great job finishing your full meditation session!",
                        color: .green
                    )
                } else {
                    InsightRow(
                        icon: "clock.badge.exclamationmark",
                        title: "Session Ended Early",
                        description: "You completed \(Int(session.completionPercentage * 100))% of your planned session.",
                        color: .orange
                    )
                }
                
                let durationMinutes = Int(session.effectiveDuration) / 60
                if durationMinutes >= 20 {
                    InsightRow(
                        icon: "star.fill",
                        title: "Extended Practice",
                        description: "Longer sessions can deepen your meditation practice.",
                        color: .blue
                    )
                } else if durationMinutes >= 10 {
                    InsightRow(
                        icon: "leaf.fill",
                        title: "Good Practice",
                        description: "Regular 10+ minute sessions build mindfulness habits.",
                        color: .green
                    )
                } else {
                    InsightRow(
                        icon: "seedling",
                        title: "Getting Started",
                        description: "Even short sessions are beneficial for building consistency.",
                        color: .mint
                    )
                }
            }
        }
        .padding()
        .background(
            ZStack {
                // Liquid Glass insights card
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .opacity(0.9)
                
                // Glass highlight with green tint
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.green.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Glass border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(SessionManager())
        .environmentObject(HealthKitManager())
} 