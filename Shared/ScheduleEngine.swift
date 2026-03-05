import Foundation

enum ScheduleState: Equatable, Sendable {
    case inClass(period: Int, entry: ClassEntry, remaining: TimeInterval, nextEntry: ClassEntry?)
    case breakTime(nextPeriod: Int, nextEntry: ClassEntry, remaining: TimeInterval)
    case beforeSchool(firstPeriod: Int, firstEntry: ClassEntry, remaining: TimeInterval)
    case afterSchool
    case weekend
    case noClass
}

enum ScheduleEngine {
    static func currentState(for date: Date, timetable: Timetable) -> ScheduleState {
        guard let weekday = Weekday.from(date: date) else {
            return .weekend
        }

        let todayClasses = timetable.todayClasses(for: weekday)
        guard !todayClasses.isEmpty else {
            return .noClass
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentSeconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)

        for (index, (period, entry)) in todayClasses.enumerated() {
            guard period < timetable.periodTimes.count else { continue }
            let periodTime = timetable.periodTimes[period]
            let startSeconds = periodTime.startHour * 3600 + periodTime.startMinute * 60
            let endSeconds = periodTime.endHour * 3600 + periodTime.endMinute * 60

            if currentSeconds < startSeconds {
                let remaining = TimeInterval(startSeconds - currentSeconds)
                if index == 0 {
                    return .beforeSchool(firstPeriod: period, firstEntry: entry, remaining: remaining)
                } else {
                    return .breakTime(nextPeriod: period, nextEntry: entry, remaining: remaining)
                }
            } else if currentSeconds < endSeconds {
                let remaining = TimeInterval(endSeconds - currentSeconds)
                let nextEntry: ClassEntry? = if index + 1 < todayClasses.count {
                    todayClasses[index + 1].entry
                } else {
                    nil
                }
                return .inClass(period: period, entry: entry, remaining: remaining, nextEntry: nextEntry)
            }
        }

        return .afterSchool
    }

    static func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func formatRemainingMinutes(_ interval: TimeInterval) -> Int {
        max(0, Int(ceil(interval / 60)))
    }
}
