import Foundation

struct Session: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval // Planned duration
    var endDate: Date?
    var actualDuration: TimeInterval? // Actual duration if ended early
    
    init(id: UUID = UUID(), 
         startDate: Date, 
         duration: TimeInterval, 
         endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.endDate = endDate
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
}

// MARK: - Extensions for Display

extension Session {
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
} 