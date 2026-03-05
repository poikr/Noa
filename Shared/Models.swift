import Foundation
import SwiftUI

// MARK: - Weekday

enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6

    nonisolated var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .monday: "월"
        case .tuesday: "화"
        case .wednesday: "수"
        case .thursday: "목"
        case .friday: "금"
        }
    }

    var fullDisplayName: String {
        switch self {
        case .monday: "월요일"
        case .tuesday: "화요일"
        case .wednesday: "수요일"
        case .thursday: "목요일"
        case .friday: "금요일"
        }
    }

    static func from(date: Date) -> Weekday? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return Weekday(rawValue: weekday)
    }
}

// MARK: - PeriodTime

struct PeriodTime: Codable, Equatable, Sendable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var name: String

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, name: String = "") {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.name = name
    }

    func displayName(period: Int) -> String {
        name.isEmpty ? "\(period + 1)교시" : name
    }

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }

    var startString: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    var endString: String {
        String(format: "%02d:%02d", endHour, endMinute)
    }

    var displayString: String {
        "\(startString)~\(endString)"
    }
}

// MARK: - ClassEntry

struct ClassEntry: Codable, Equatable, Sendable {
    var subject: String
    var teacher: String
    var classroom: String
    var colorName: String

    static let empty = ClassEntry(subject: "", teacher: "", classroom: "", colorName: "blue")

    var isEmpty: Bool { subject.trimmingCharacters(in: .whitespaces).isEmpty }

    static let availableColors: [(name: String, display: String)] = [
        ("blue", "파랑"), ("red", "빨강"), ("green", "초록"),
        ("orange", "주황"), ("purple", "보라"), ("pink", "분홍"),
        ("yellow", "노랑"), ("cyan", "청록"), ("mint", "민트"),
        ("teal", "틸"), ("indigo", "인디고"), ("brown", "갈색"),
    ]

    var color: Color {
        switch colorName {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "cyan": .cyan
        case "mint": .mint
        case "teal": .teal
        case "indigo": .indigo
        case "brown": .brown
        default: .blue
        }
    }
}

// MARK: - Timetable

struct Timetable: Codable, Equatable, Sendable {
    var periodCount: Int
    var periodTimes: [PeriodTime]
    var slots: [String: ClassEntry]

    static func slotKey(weekday: Weekday, period: Int) -> String {
        "\(weekday.rawValue)_\(period)"
    }

    func classEntry(for weekday: Weekday, period: Int) -> ClassEntry {
        slots[Self.slotKey(weekday: weekday, period: period)] ?? .empty
    }

    mutating func setClassEntry(_ entry: ClassEntry, for weekday: Weekday, period: Int) {
        if entry.isEmpty {
            slots.removeValue(forKey: Self.slotKey(weekday: weekday, period: period))
        } else {
            slots[Self.slotKey(weekday: weekday, period: period)] = entry
        }
    }

    func todayClasses(for weekday: Weekday) -> [(period: Int, entry: ClassEntry)] {
        (0..<periodCount).compactMap { period in
            let entry = classEntry(for: weekday, period: period)
            return entry.isEmpty ? nil : (period, entry)
        }
    }

    mutating func addPeriod() {
        let lastTime = periodTimes.last ?? PeriodTime(startHour: 8, startMinute: 50, endHour: 9, endMinute: 40)
        let newStart = lastTime.endTotalMinutes + 10
        let newEnd = newStart + 50
        periodTimes.append(PeriodTime(
            startHour: newStart / 60, startMinute: newStart % 60,
            endHour: newEnd / 60, endMinute: newEnd % 60
        ))
        periodCount += 1
    }

    mutating func removePeriod() {
        guard periodCount > 1 else { return }
        periodCount -= 1
        periodTimes = Array(periodTimes.prefix(periodCount))
        for weekday in Weekday.allCases {
            slots.removeValue(forKey: Self.slotKey(weekday: weekday, period: periodCount))
        }
    }

    static let `default`: Timetable = {
        let defaultTimes: [PeriodTime] = [
            PeriodTime(startHour: 8, startMinute: 50, endHour: 9, endMinute: 40),
            PeriodTime(startHour: 9, startMinute: 50, endHour: 10, endMinute: 40),
            PeriodTime(startHour: 10, startMinute: 50, endHour: 11, endMinute: 40),
            PeriodTime(startHour: 11, startMinute: 50, endHour: 12, endMinute: 40),
            PeriodTime(startHour: 13, startMinute: 30, endHour: 14, endMinute: 20),
            PeriodTime(startHour: 14, startMinute: 30, endHour: 15, endMinute: 20),
            PeriodTime(startHour: 15, startMinute: 30, endHour: 16, endMinute: 20),
        ]
        return Timetable(periodCount: 7, periodTimes: defaultTimes, slots: [:])
    }()
}
