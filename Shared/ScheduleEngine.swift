import Foundation

enum ScheduleState: Equatable, Sendable {
    case inClass(period: Int, entry: ClassEntry, remaining: TimeInterval, nextEntry: ClassEntry?, isFood: Bool)
    case breakTime(nextPeriod: Int, nextEntry: ClassEntry, remaining: TimeInterval)
    case goingToSchool(firstEntry: ClassEntry, arrivalRemaining: TimeInterval, classRemaining: TimeInterval)
    case beforeSchool(firstPeriod: Int, firstEntry: ClassEntry, remaining: TimeInterval)
    case afterSchool
    case weekend
    case noClass
}

enum ScheduleEngine {
    struct ScheduleSlot: Sendable {
        let startSeconds: Int
        let endSeconds: Int
        let entry: ClassEntry
        let period: Int // -1 for extra schedules
        let isFood: Bool
        let isExtra: Bool
    }

    static func buildSlots(timetable: Timetable, weekday: Weekday) -> [ScheduleSlot] {
        var slots: [ScheduleSlot] = []

        let todayClasses = timetable.todayClasses(for: weekday)
        for (period, entry) in todayClasses {
            guard period < timetable.periodTimes.count else { continue }
            let pt = timetable.periodTimes[period]
            slots.append(ScheduleSlot(
                startSeconds: pt.startHour * 3600 + pt.startMinute * 60,
                endSeconds: pt.endHour * 3600 + pt.endMinute * 60,
                entry: entry,
                period: period,
                isFood: entry.isFood,
                isExtra: false
            ))
        }

        let todayExtras = timetable.todayExtraSchedules(for: weekday)
        for extra in todayExtras {
            let entry = ClassEntry(subject: extra.name, teacher: "", classroom: "", colorName: extra.colorName)
            if extra.spansNextDay {
                // Starting day portion: startTime → midnight (24:00)
                slots.append(ScheduleSlot(
                    startSeconds: extra.startHour * 3600 + extra.startMinute * 60,
                    endSeconds: 24 * 3600,
                    entry: entry,
                    period: -1,
                    isFood: false,
                    isExtra: true
                ))
            } else {
                slots.append(ScheduleSlot(
                    startSeconds: extra.startHour * 3600 + extra.startMinute * 60,
                    endSeconds: extra.endHour * 3600 + extra.endMinute * 60,
                    entry: entry,
                    period: -1,
                    isFood: false,
                    isExtra: true
                ))
            }
        }

        // Add overnight extras from previous day (midnight → endTime)
        let previousDay = weekday.previousDay
        let overnightExtras = timetable.todayExtraSchedules(for: previousDay).filter { $0.spansNextDay }
        for extra in overnightExtras {
            let entry = ClassEntry(subject: extra.name, teacher: "", classroom: "", colorName: extra.colorName)
            slots.append(ScheduleSlot(
                startSeconds: 0,
                endSeconds: extra.endHour * 3600 + extra.endMinute * 60,
                entry: entry,
                period: -1,
                isFood: false,
                isExtra: true
            ))
        }

        // Filter out invalid slots (end <= start)
        slots = slots.filter { $0.endSeconds > $0.startSeconds }

        // Sort by start time (earlier start = higher priority)
        slots.sort { $0.startSeconds < $1.startSeconds }

        // Resolve overlaps: earlier-starting slot wins, trim or remove later ones
        var resolved: [ScheduleSlot] = []
        for slot in slots {
            if let last = resolved.last, slot.startSeconds < last.endSeconds {
                // Overlapping: trim this slot's start to after the previous slot ends
                if last.endSeconds < slot.endSeconds {
                    resolved.append(ScheduleSlot(
                        startSeconds: last.endSeconds,
                        endSeconds: slot.endSeconds,
                        entry: slot.entry,
                        period: slot.period,
                        isFood: slot.isFood,
                        isExtra: slot.isExtra
                    ))
                }
                // Otherwise this slot is fully covered → skip
            } else {
                resolved.append(slot)
            }
        }
        return resolved
    }

    static func currentState(for date: Date, timetable: Timetable) -> ScheduleState {
        guard let weekday = Weekday.from(date: date) else {
            return .weekend
        }

        let slots = buildSlots(timetable: timetable, weekday: weekday)
        guard !slots.isEmpty else {
            if weekday == .saturday || weekday == .sunday {
                return .weekend
            }
            return .noClass
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentSeconds = (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
        let hour = components.hour ?? 0

        // Before 4AM → afterSchool, unless there's an overnight slot active
        if hour < 4 {
            // Check if any slot covers the current time (overnight from previous day)
            for (index, slot) in slots.enumerated() {
                if currentSeconds >= slot.startSeconds && currentSeconds < slot.endSeconds {
                    let remaining = TimeInterval(slot.endSeconds - currentSeconds)
                    let nextEntry: ClassEntry? = if index + 1 < slots.count {
                        slots[index + 1].entry
                    } else {
                        nil
                    }
                    return .inClass(period: slot.period, entry: slot.entry, remaining: remaining, nextEntry: nextEntry, isFood: slot.isFood)
                }
            }
            return .afterSchool
        }

        let firstSlot = slots[0]

        // Before first slot
        if currentSeconds < firstSlot.startSeconds {
            let arrivalSeconds = timetable.arrivalHour * 3600 + timetable.arrivalMinute * 60
            let arrivalRemaining = TimeInterval(arrivalSeconds - currentSeconds)
            let classRemaining = TimeInterval(firstSlot.startSeconds - currentSeconds)

            if currentSeconds < arrivalSeconds {
                return .goingToSchool(firstEntry: firstSlot.entry, arrivalRemaining: arrivalRemaining, classRemaining: classRemaining)
            } else {
                return .beforeSchool(firstPeriod: firstSlot.period, firstEntry: firstSlot.entry, remaining: classRemaining)
            }
        }

        // Check each slot
        for (index, slot) in slots.enumerated() {
            if currentSeconds < slot.startSeconds {
                // Between previous slot and this one → break time
                let remaining = TimeInterval(slot.startSeconds - currentSeconds)
                return .breakTime(nextPeriod: slot.period, nextEntry: slot.entry, remaining: remaining)
            } else if currentSeconds < slot.endSeconds {
                // Inside this slot
                let remaining = TimeInterval(slot.endSeconds - currentSeconds)
                let nextEntry: ClassEntry? = if index + 1 < slots.count {
                    slots[index + 1].entry
                } else {
                    nil
                }
                return .inClass(period: slot.period, entry: slot.entry, remaining: remaining, nextEntry: nextEntry, isFood: slot.isFood)
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
