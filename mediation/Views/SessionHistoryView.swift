import SwiftUI
import Charts

struct SessionHistoryView: View {
    @EnvironmentObject var meditationManager: MeditationManager
    @EnvironmentObject var healthStore: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSession: MeditationSession?
    @State private var showingDeleteAllAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if meditationManager.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        // Summary section
                        Section {
                            SessionSummaryStatsView(sessions: meditationManager.sessions)
                        }
                        
                        // Sessions list
                        Section("Recent Sessions") {
                            ForEach(meditationManager.sessions.reversed()) { session in
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
                leading: meditationManager.sessions.isEmpty ? nil : Button("Delete All") {
                    showingDeleteAllAlert = true
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert("Delete All Sessions", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    meditationManager.deleteAllSessions()
                }
            } message: {
                Text("Are you sure you want to delete all meditation sessions? This action cannot be undone and will also remove sessions from your Health app.")
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }
    
    private func deleteSession(at offsets: IndexSet) {
        let reversedSessions = meditationManager.sessions.reversed()
        for index in offsets {
            let sessionIndex = Array(reversedSessions).indices[index]
            let session = Array(reversedSessions)[sessionIndex]
            meditationManager.deleteSession(session)
        }
    }
}

struct SessionSummaryStatsView: View {
    let sessions: [MeditationSession]
    
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
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
        .padding(.vertical, 8)
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
    let session: MeditationSession
    
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
                    
                    // Health data indicator
                    if !session.heartRateData.isEmpty || !session.breathingRateData.isEmpty {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("Health Data")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct SessionDetailView: View {
    let session: MeditationSession
    @EnvironmentObject var meditationManager: MeditationManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Session Summary
                    SessionSummaryCard(session: session)
                    
                    // Heart Rate Chart
                    if !session.heartRateData.isEmpty {
                        HeartRateChartView(session: session)
                    }
                    
                    // Breathing Rate Chart  
                    if !session.breathingRateData.isEmpty {
                        BreathingRateChartView(session: session)
                    }
                    
                    // Additional metrics
                    MetricsCardView(session: session)
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
                    meditationManager.deleteSession(session)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this meditation session? This action cannot be undone and will also remove the session from your Health app.")
            }
        }
    }
}

struct SessionSummaryCard: View {
    let session: MeditationSession
    
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
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HeartRateChartView: View {
    let session: MeditationSession
    
    private var chartData: [ChartDataPoint] {
        session.heartRateData.map { dataPoint in
            ChartDataPoint(
                time: dataPoint.timestamp.timeIntervalSince(session.startDate),
                value: dataPoint.value
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Heart Rate")
                    .font(.headline)
                Spacer()
                if let avgHeartRate = session.averageHeartRate {
                    Text("Avg: \(Int(avgHeartRate)) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if #available(iOS 16.0, *) {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.time),
                        y: .value("Heart Rate", dataPoint.value)
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes/60))m")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let bpm = value.as(Double.self) {
                                Text("\(Int(bpm))")
                            }
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                SimpleLineChart(data: chartData, color: .red)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BreathingRateChartView: View {
    let session: MeditationSession
    
    private var chartData: [ChartDataPoint] {
        session.breathingRateData.map { dataPoint in
            ChartDataPoint(
                time: dataPoint.timestamp.timeIntervalSince(session.startDate),
                value: dataPoint.value
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Breathing Rate")
                    .font(.headline)
                Spacer()
                if let avgBreathingRate = session.averageBreathingRate {
                    Text("Avg: \(Int(avgBreathingRate)) RPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if #available(iOS 16.0, *) {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.time),
                        y: .value("Breathing Rate", dataPoint.value)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes/60))m")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let rpm = value.as(Double.self) {
                                Text("\(Int(rpm))")
                            }
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                SimpleLineChart(data: chartData, color: .blue)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricsCardView: View {
    let session: MeditationSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(session.heartRateData.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Heart Rate\nReadings")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(session.breathingRateData.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Breathing\nReadings")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(session.isCompleted ? "✓" : "○")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(session.isCompleted ? .green : .gray)
                    Text("Session\nCompleted")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Types

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let value: Double
}

// Simple fallback chart for iOS < 16
struct SimpleLineChart: View {
    let data: [ChartDataPoint]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxTime = data.map(\.time).max() ?? 1
                let maxValue = data.map(\.value).max() ?? 1
                let minValue = data.map(\.value).min() ?? 0
                
                let xScale = geometry.size.width / maxTime
                let yScale = geometry.size.height / (maxValue - minValue)
                
                for (index, point) in data.enumerated() {
                    let x = point.time * xScale
                    let y = geometry.size.height - ((point.value - minValue) * yScale)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(MeditationManager())
        .environmentObject(HealthKitManager())
} 