import Foundation

struct MeditationSession: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval // Planned duration
    var endDate: Date?
    var actualDuration: TimeInterval? // Actual duration if ended early
    var heartRateData: [HealthDataPoint]
    var breathingRateData: [HealthDataPoint]
    var averageHeartRate: Double?
    var averageBreathingRate: Double?
    
    init(id: UUID = UUID(), 
         startDate: Date, 
         duration: TimeInterval, 
         endDate: Date? = nil,
         heartRateData: [HealthDataPoint] = [],
         breathingRateData: [HealthDataPoint] = [],
         averageHeartRate: Double? = nil,
         averageBreathingRate: Double? = nil) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.endDate = endDate
        self.heartRateData = heartRateData
        self.breathingRateData = breathingRateData
        self.averageHeartRate = averageHeartRate
        self.averageBreathingRate = averageBreathingRate
    }
    
    var isCompleted: Bool {
        endDate != nil
    }
    
    var effectiveDuration: TimeInterval {
        if let actualDuration = actualDuration {
            return actualDuration
        } else if let endDate = endDate {
            return endDate.timeIntervalSince(startDate)
        } else {
            return duration
        }
    }
    
    var completionPercentage: Double {
        return min(1.0, effectiveDuration / duration)
    }
    
    mutating func calculateAverages() {
        if !heartRateData.isEmpty {
            averageHeartRate = heartRateData.map(\.value).reduce(0, +) / Double(heartRateData.count)
        }
        
        if !breathingRateData.isEmpty {
            averageBreathingRate = breathingRateData.map(\.value).reduce(0, +) / Double(breathingRateData.count)
        }
    }
}

struct HealthDataPoint: Codable {
    let timestamp: Date
    let value: Double
    
    init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - Extensions for Display

extension MeditationSession {
    var formattedDuration: String {
        let minutes = Int(effectiveDuration) / 60
        let seconds = Int(effectiveDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    var formattedAverageHeartRate: String {
        guard let averageHeartRate = averageHeartRate else { return "N/A" }
        return "\(Int(averageHeartRate)) BPM"
    }
    
    var formattedAverageBreathingRate: String {
        guard let averageBreathingRate = averageBreathingRate else { return "N/A" }
        return "\(Int(averageBreathingRate)) RPM"
    }
} 