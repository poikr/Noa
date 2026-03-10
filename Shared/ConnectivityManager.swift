import Foundation
import WatchConnectivity

@Observable
class ConnectivityManager: NSObject, @preconcurrency WCSessionDelegate {
    static let shared = ConnectivityManager()

    var isReachable = false
    var lastSyncDate: Date?

    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send

    func sendTimetable() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(TimetableStore.shared.timetable) else { return }

        var context: [String: Any] = [
            "timetable": data,
            "notification_minutes": TimetableStore.shared.notificationMinutesBefore,
        ]

        // Also sync NEIS meal settings
        let mealStore = MealStore.shared
        if !mealStore.apiKey.isEmpty {
            context["neis_api_key"] = mealStore.apiKey
        }
        if let school = mealStore.selectedSchool,
           let schoolData = try? JSONEncoder().encode(school) {
            context["neis_school"] = schoolData
        }

        try? session.updateApplicationContext(context)

        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        }

        lastSyncDate = Date()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedContext(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard let timetable = try? JSONDecoder().decode(Timetable.self, from: messageData) else { return }
        Task { @MainActor in
            TimetableStore.shared.timetable = timetable
            self.lastSyncDate = Date()
        }
    }

    nonisolated private func handleReceivedContext(_ context: [String: Any]) {
        guard let data = context["timetable"] as? Data,
              let timetable = try? JSONDecoder().decode(Timetable.self, from: data) else { return }
        let minutes = context["notification_minutes"] as? Int ?? 5

        // Extract NEIS meal settings
        let apiKey = context["neis_api_key"] as? String
        var school: SchoolInfo?
        if let schoolData = context["neis_school"] as? Data {
            school = try? JSONDecoder().decode(SchoolInfo.self, from: schoolData)
        }

        Task { @MainActor in
            TimetableStore.shared.timetable = timetable
            TimetableStore.shared.notificationMinutesBefore = minutes

            // Update meal settings if present
            if let apiKey {
                MealStore.shared.apiKey = apiKey
            }
            if let school {
                MealStore.shared.selectedSchool = school
            }

            self.lastSyncDate = Date()
        }
    }
}
