import SwiftUI
import Charts

struct SessionHistoryView: View {
    @EnvironmentObject var meditationManager: MeditationManager
    @EnvironmentObject var healthStore: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSession: MeditationSession?
    
    var body: some View {
        NavigationView {
            VStack {
                if meditationManager.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        ForEach(meditationManager.sessions.reversed()) { session in
                            SessionRowView(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No sessions yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start your first meditation session to see your progress here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct SessionRowView: View {
    let session: MeditationSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.formattedDate)
                        .font(.headline)
                    
                    Text(session.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    if let avgHeartRate = session.averageHeartRate {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("\(Int(avgHeartRate))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    Text("\(Int(session.completionPercentage * 100))% complete")
                        .font(.caption)
                        .foregroundColor(session.completionPercentage >= 1.0 ? .green : .orange)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.green, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * session.completionPercentage, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

struct SessionDetailView: View {
    let session: MeditationSession
    @Environment(\.presentationMode) var presentationMode
    
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
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
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