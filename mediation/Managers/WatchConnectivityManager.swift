import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - iOS Methods
    
    func startMeditationSession(duration: TimeInterval) {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        let message = [
            "action": "startMeditation",
            "duration": duration
        ] as [String: Any]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send start meditation message: \(error.localizedDescription)")
        }
    }
    
    func stopMeditationSession() {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        let message = ["action": "stopMeditation"]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send stop meditation message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Watch Methods
    
    func sendHealthData(_ data: [String: Any]) {
        guard WCSession.default.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        var message = data
        message["type"] = "healthData"
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send health data: \(error.localizedDescription)")
        }
    }
    
    func sendSessionUpdate(_ data: [String: Any]) {
        guard WCSession.default.isReachable else {
            print("iPhone is not reachable")
            return
        }
        
        var message = data
        message["type"] = "sessionUpdate"
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send session update: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WC session activation failed: \(error.localizedDescription)")
        } else {
            print("WC session activated with state: \(activationState.rawValue)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WC session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WC session deactivated")
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        #if os(iOS)
        // Handle messages from watch
        if let type = message["type"] as? String {
            switch type {
            case "healthData":
                NotificationCenter.default.post(
                    name: .watchConnectivityDidReceiveData,
                    object: nil,
                    userInfo: ["data": message]
                )
            case "sessionUpdate":
                NotificationCenter.default.post(
                    name: .watchConnectivityDidReceiveSessionUpdate,
                    object: nil,
                    userInfo: ["data": message]
                )
            default:
                break
            }
        }
        #else
        // Handle messages from iPhone (watchOS)
        if let action = message["action"] as? String {
            switch action {
            case "startMeditation":
                if let duration = message["duration"] as? TimeInterval {
                    NotificationCenter.default.post(
                        name: .watchShouldStartMeditation,
                        object: nil,
                        userInfo: ["duration": duration]
                    )
                }
            case "stopMeditation":
                NotificationCenter.default.post(
                    name: .watchShouldStopMeditation,
                    object: nil
                )
            default:
                break
            }
        }
        #endif
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let watchConnectivityDidReceiveSessionUpdate = Notification.Name("watchConnectivityDidReceiveSessionUpdate")
    static let watchShouldStartMeditation = Notification.Name("watchShouldStartMeditation")
    static let watchShouldStopMeditation = Notification.Name("watchShouldStopMeditation")
} 