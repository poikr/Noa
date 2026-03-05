import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
class TimetableStore {
    static let shared = TimetableStore()
    static let appGroupID = "group.kr.poi.Noa"
    static let timetableKey = "timetable_data"
    static let notificationMinutesKey = "notification_minutes"

    var timetable: Timetable {
        didSet { save() }
    }

    var notificationMinutesBefore: Int {
        didSet {
            Self.sharedDefaults?.set(notificationMinutesBefore, forKey: Self.notificationMinutesKey)
        }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {
        let defaults = Self.sharedDefaults
        if let data = defaults?.data(forKey: Self.timetableKey),
           let decoded = try? JSONDecoder().decode(Timetable.self, from: data) {
            self.timetable = decoded
        } else {
            self.timetable = .default
        }
        let minutes = defaults?.integer(forKey: Self.notificationMinutesKey) ?? 0
        self.notificationMinutesBefore = minutes == 0 ? 5 : minutes
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(timetable) else { return }
        Self.sharedDefaults?.set(data, forKey: Self.timetableKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func resetTimetable() {
        timetable = .default
    }

    func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(timetable)
    }

    func importJSON(from data: Data) throws {
        let decoded = try JSONDecoder().decode(Timetable.self, from: data)
        guard decoded.periodCount >= 1,
              decoded.periodTimes.count == decoded.periodCount else {
            throw ImportError.invalidData
        }
        timetable = decoded
    }

    enum ImportError: LocalizedError {
        case invalidData
        var errorDescription: String? { "유효하지 않은 시간표 파일입니다." }
    }

    nonisolated static func loadFromDefaults() -> Timetable {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: timetableKey),
              let decoded = try? JSONDecoder().decode(Timetable.self, from: data) else {
            return .default
        }
        return decoded
    }
}
