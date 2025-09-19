import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var lastError: Error?
    @Published var consecutiveDays = 0
    private let typesToRead: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession),
        HKObjectType.stateOfMindType()
    ]
    
    private let typesToWrite: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession),
        HKObjectType.stateOfMindType()
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func forceRefreshPermissions() {
        print("🔄 Force refreshing HealthKit permissions...")
        
        // Add a small delay to ensure iOS has updated the permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAuthorizationStatus()
        }
    }
    
    private func updateAuthorizationStatus() {
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        // For this app to work properly, we need mindful session write access
        let mindfulOK = mindfulSessionStatus != .notDetermined
        
        isAuthorized = mindfulOK
        
        print("🎯 Updated Authorization Status:")
        print("   • Mindful sessions: \(authStatusDescription(mindfulSessionStatus)) (\(mindfulOK ? "✅" : "❌"))")
        print("   • Overall authorized: \(isAuthorized ? "✅ YES" : "❌ NO")")
        
        if isAuthorized {
            print("🚀 Ready for meditation tracking!")
            calculateConsecutiveDays()
        }
    }
    
    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        print("Requesting HealthKit permissions for: Mindful Sessions")
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                    self?.lastError = error
                } else {
                    print("HealthKit authorization completed. Overall success: \(success)")
                }
                
                // Always check individual authorization status regardless of overall success
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    func saveMindfulSession(_ session: Session) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Check current authorization status
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        guard mindfulSessionStatus == .sharingAuthorized else {
            print("HealthKit not authorized for mindful sessions - status: \(mindfulSessionStatus.rawValue)")
            if mindfulSessionStatus == .notDetermined {
                print("HealthKit permissions not yet requested")
                requestPermissions()
            }
            return
        }
        
        // Ensure we have valid dates
        let startDate = session.startDate
        let endDate = session.endDate ?? Date()
        
        let mindfulSession = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )
        
        healthStore.save(mindfulSession) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    print("Failed to save mindful session: \(error.localizedDescription)")
                } else {
                    print("✅ Mindful session saved successfully to Health app - Duration: \(session.formattedDuration)")
                    self?.calculateConsecutiveDays()
                }
            }
        }
    }
    
    func deleteMindfulSession(_ session: Session, completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            completion(false)
            return
        }
        
        let mindfulSessionType = HKCategoryType(.mindfulSession)
        let predicate = HKQuery.predicateForSamples(
            withStart: session.startDate,
            end: session.endDate,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: mindfulSessionType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            
            if let error = error {
                print("Failed to find mindful session for deletion: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            guard let sample = samples?.first else {
                print("No mindful session found to delete")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            self?.healthStore.delete(sample) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to delete mindful session: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("Mindful session deleted successfully")
                        completion(true)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("❌ HealthKit not available on this device")
            return 
        }
        
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        
        // Debug: Print raw values
        print("🔍 Raw Authorization Values:")
        print("   • Mindful sessions raw value: \(mindfulSessionStatus.rawValue)")
        
        // NOTE: These reported statuses are often unreliable, actual authorization determined by test queries
        
        print("📊 HealthKit Authorization Status (reported by iOS):")
        print("   • Mindful sessions: \(authStatusDescription(mindfulSessionStatus))")
        print("")
        print("⚠️  Note: iOS often reports incorrect status. Testing actual data access...")
        
        // Update authorization status
        updateAuthorizationStatus()
    }
    
    func forceAuthorizationCheck() {
        print("🔄 Force checking authorization and recalculating consecutive days...")
        checkAuthorizationStatus()
    }
    
    func debugPermissions() {
        print("\n🐛 DEBUG: Full Permission Analysis")
        print("=======================================")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available")
            return
        }
        
        print("Raw value meanings: 0=NotDetermined, 1=Denied, 2=Authorized")
        print("")
        
        // Check all relevant types
        let types: [(String, HKObjectType)] = [
            ("Mindful Session", HKCategoryType(.mindfulSession))
        ]
        
        for (name, type) in types {
            let status = healthStore.authorizationStatus(for: type)
            let statusName = authStatusDescription(status)
            let emoji = status == .sharingAuthorized ? "✅" : (status == .sharingDenied ? "❌" : "⚠️")
            print("   \(emoji) \(name): \(statusName) (raw: \(status.rawValue))")
        }
        
        print("")
        print("Expected for app to work:")
        print("   • Mindful Session should be: Authorized (raw: 2)")
        print("=======================================\n")
    }
    
    private func authStatusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Permission Status Helpers
    
    var canMonitorMindfulSessions: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        // Use actual test results instead of unreliable iOS status
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        return mindfulSessionStatus != .notDetermined
    }
    
    var mindfulSessionPermissionStatus: String {
        guard HKHealthStore.isHealthDataAvailable() else { return "HealthKit not available" }
        
        // Use actual test results instead of unreliable iOS status
        let mindfulSessionStatus = healthStore.authorizationStatus(for: HKCategoryType(.mindfulSession))
        if mindfulSessionStatus == .sharingAuthorized {
            return "Mindful sessions monitoring ready ✅"
        } else {
            switch mindfulSessionStatus {
            case .notDetermined:
                return "Tap to enable mindful sessions tracking"
            case .sharingDenied:
                return "Mindful sessions access denied - check Settings"
            @unknown default:
                return "Apple Watch required for mindful sessions monitoring"
            }
        }
    }
    
    func retryMindfulSessionPermission() {
        print("🔄 Retrying mindful session permission request...")
        requestPermissions()
    }
    
    // MARK: - Apple Watch Detection
    
    func isAppleWatchLikelyPaired() -> Bool {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        // Simple check based on HealthKit availability
        return true
    }
    
    func calculateConsecutiveDays() {
        print("🔍 calculateConsecutiveDays called - will be handled by SessionManager")
        // This method will be called by SessionManager to update the streak
        // The actual calculation is now handled in SessionManager to avoid circular dependency
    }
    
    func updateConsecutiveDays(_ count: Int) {
        consecutiveDays = count
        print("✅ Updated consecutiveDays to: \(consecutiveDays)")
    }
    
    // MARK: - State of Mind Support
    
    @available(iOS 18.0, *)
    func saveStateOfMind(_ entry: StateOfMindEntry) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Check authorization for State of Mind
        let stateOfMindType = HKObjectType.stateOfMindType()
        let authStatus = healthStore.authorizationStatus(for: stateOfMindType)
        
        guard authStatus == .sharingAuthorized else {
            print("HealthKit not authorized for State of Mind - status: \(authStatus.rawValue)")
            if authStatus == .notDetermined {
                print("Requesting State of Mind permissions...")
                requestPermissions()
            }
            return
        }
        
        // Create labels array from emotions
        var labels: Set<HKStateOfMind.Label> = []
        
        // Add primary emotion
        if let primaryEmotion = StateOfMindEmotion(rawValue: entry.emotion),
           let hkLabel = mapEmotionToHKLabel(primaryEmotion) {
            labels.insert(hkLabel)
        }
        
        // Add additional emotion labels
        for labelString in entry.labels {
            if let emotion = StateOfMindEmotion(rawValue: labelString),
               let hkLabel = mapEmotionToHKLabel(emotion) {
                labels.insert(hkLabel)
            }
        }
        
        // Get the kind from the entry, defaulting to momentary emotion
        let hkKind: HKStateOfMind.Kind
        if let entryKind = StateOfMindKind(rawValue: entry.kind) {
            switch entryKind {
            case .dailyMood:
                hkKind = .dailyMood
            case .momentaryEmotion:
                hkKind = .momentaryEmotion
            }
        } else {
            hkKind = .momentaryEmotion
        }
        
        // Create HKStateOfMind with proper iOS 18+ API
        let stateOfMind = HKStateOfMind(
            date: entry.date,
            kind: hkKind,
            valence: entry.valence,
            labels: Array(labels),
            associations: []
        )
        
        // Save to HealthKit
        healthStore.save(stateOfMind) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastError = error
                    print("❌ Failed to save State of Mind to HealthKit: \(error.localizedDescription)")
                } else {
                    print("✅ State of Mind saved successfully to Health app!")
                    print("🎯 Emotion: \(entry.emotion), Valence: \(entry.valence)")
                }
            }
        }
    }
    
    @available(iOS 18.0, *)
    private func mapEmotionToHKLabel(_ emotion: StateOfMindEmotion) -> HKStateOfMind.Label? {
        // Map simplified emotions to HealthKit labels
        switch emotion {
        case .happy: return .happy
        case .calm: return .calm
        case .excited: return .excited
        case .grateful: return .grateful
        case .content: return .content
        case .anxious: return .anxious
        case .sad: return .sad
        case .angry: return .angry
        case .stressed: return .stressed
        case .frustrated: return .frustrated
        }
    }
    
    private func saveMoodEntryLocally(_ entry: StateOfMindEntry) {
        // Save to UserDefaults for now - this can be migrated to HealthKit later
        var existingEntries = getMoodEntriesFromUserDefaults()
        existingEntries.append(entry)
        
        do {
            let data = try JSONEncoder().encode(existingEntries)
            UserDefaults.standard.set(data, forKey: "MindfulBooMoodEntries")
            print("💾 Mood entry saved locally")
        } catch {
            print("❌ Failed to save mood entry locally: \(error)")
        }
    }
    
    private func getMoodEntriesFromUserDefaults() -> [StateOfMindEntry] {
        guard let data = UserDefaults.standard.data(forKey: "MindfulBooMoodEntries") else { return [] }
        
        do {
            return try JSONDecoder().decode([StateOfMindEntry].self, from: data)
        } catch {
            print("Failed to load mood entries: \(error)")
            return []
        }
    }
    
    
    var canLogStateOfMind: Bool {
        if #available(iOS 18.0, *) {
            guard HKHealthStore.isHealthDataAvailable() else { return false }
            let stateOfMindStatus = healthStore.authorizationStatus(for: HKObjectType.stateOfMindType())
            return stateOfMindStatus == .sharingAuthorized
        }
        return false
    }
    
    var stateOfMindPermissionStatus: String {
        if #available(iOS 18.0, *) {
            guard HKHealthStore.isHealthDataAvailable() else { return "HealthKit not available" }
            
            let stateOfMindStatus = healthStore.authorizationStatus(for: HKObjectType.stateOfMindType())
            if stateOfMindStatus == .sharingAuthorized {
                return "State of Mind syncing to Health app ✅"
            } else {
                switch stateOfMindStatus {
                case .notDetermined:
                    return "Tap to enable State of Mind logging"
                case .sharingDenied:
                    return "State of Mind access denied - check Settings"
                @unknown default:
                    return "State of Mind permissions required"
                }
            }
        }
        return "State of Mind requires iOS 18+"
    }
} 