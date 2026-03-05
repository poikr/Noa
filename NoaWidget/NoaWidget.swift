import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ScheduleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), state: .noClass)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let timetable = TimetableStore.loadFromDefaults()
        let state = ScheduleEngine.currentState(for: Date(), timetable: timetable)
        completion(ScheduleEntry(date: Date(), state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let timetable = TimetableStore.loadFromDefaults()
        let now = Date()
        let calendar = Calendar.current

        // Collect important time points: period starts, ends, and 3min-before-end
        var keyDates: Set<Date> = []

        if let weekday = Weekday.from(date: now) {
            let todayStart = calendar.startOfDay(for: now)
            for period in 0..<timetable.periodCount where period < timetable.periodTimes.count {
                let pt = timetable.periodTimes[period]
                let start = calendar.date(bySettingHour: pt.startHour, minute: pt.startMinute, second: 0, of: todayStart)!
                let end = calendar.date(bySettingHour: pt.endHour, minute: pt.endMinute, second: 0, of: todayStart)!
                let warn = calendar.date(byAdding: .minute, value: -3, to: end)!
                let warnStart = calendar.date(byAdding: .minute, value: -3, to: start)!
                keyDates.formUnion([start, end, warn, warnStart])
            }
        }

        // Generate entries every minute for 60 minutes + key transition dates
        var allDates: Set<Date> = keyDates.filter { $0 >= now }
        for minuteOffset in 0..<60 {
            let d = calendar.date(byAdding: .minute, value: minuteOffset, to: now)!
            allDates.insert(d)
        }

        let entries = allDates.sorted().map { date in
            ScheduleEntry(date: date, state: ScheduleEngine.currentState(for: date, timetable: timetable))
        }

        let refreshDate = calendar.date(byAdding: .minute, value: 15, to: now)!
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

// MARK: - Timeline Entry

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let state: ScheduleState
}

// MARK: - Helpers

private func urgencyColor(remaining: TimeInterval, normal: Color) -> Color {
    remaining <= 180 ? .red : normal
}

private func periodDisplayName(_ period: Int) -> String {
    let timetable = TimetableStore.loadFromDefaults()
    guard period < timetable.periodTimes.count else { return "\(period + 1)교시" }
    return timetable.periodTimes[period].displayName(period: period)
}


/// Returns a live countdown Text when ≤ 3 min, otherwise static "N분" text
private func countdownText(remaining: TimeInterval, entryDate: Date) -> Text {
    if remaining <= 180 {
        let endDate = entryDate.addingTimeInterval(remaining)
        return Text(timerInterval: entryDate...endDate, countsDown: true)
    } else {
        return Text("\(ScheduleEngine.formatRemainingMinutes(remaining))분")
    }
}

// MARK: - Circular Complication

struct CircularView: View {
    let state: ScheduleState
    let entryDate: Date

    var body: some View {
        switch state {
        case .inClass(_, let entry, let remaining, _):
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(entry.subject)
                        .font(.system(.caption2, design: .rounded).bold())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .green))
                    countdownText(remaining: remaining, entryDate: entryDate)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .primary))
                }
            }

        case .breakTime(_, let nextEntry, let remaining):
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(nextEntry.subject)
                        .font(.system(.caption2, design: .rounded).bold())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    countdownText(remaining: remaining, entryDate: entryDate)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))
                }
            }

        case .beforeSchool(_, let firstEntry, let remaining):
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(firstEntry.subject)
                        .font(.system(.caption2, design: .rounded).bold())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    countdownText(remaining: remaining, entryDate: entryDate)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(.secondary)
                }
            }

        case .afterSchool:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "house")
                        .font(.body)
                    Text("하교")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

        case .weekend:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "moon.stars")
                        .font(.body)
                    Text("주말")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

        case .noClass:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "calendar.badge.minus")
                        .font(.body)
                    Text("없음")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Rectangular Complication

struct RectangularView: View {
    let state: ScheduleState
    let entryDate: Date

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .inClass(let period, let entry, let remaining, let nextEntry):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .green))
                    Text("\(periodDisplayName(period)) 수업 중")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    Text(entry.subject)
                        .font(.headline)
                    if let next = nextEntry {
                        Text(" / \(next.subject)")
                            .font(.headline)
                            .fontWeight(.light)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                if remaining <= 180 {
                    (countdownText(remaining: remaining, entryDate: entryDate) + Text(" 남음"))
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("\(ScheduleEngine.formatRemainingMinutes(remaining))분 남음")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

        case .breakTime(let nextPeriod, let nextEntry, let remaining):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))
                    Text("쉬는 시간")
                        .font(.caption2)
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))
                }
                Text(nextEntry.subject)
                    .font(.headline)
                    .lineLimit(1)
                if remaining <= 180 {
                    (Text("\(periodDisplayName(nextPeriod)) ") + countdownText(remaining: remaining, entryDate: entryDate).foregroundColor(.red) + Text(" 후").foregroundColor(.red))
                        .font(.caption)
                } else {
                    (Text("\(periodDisplayName(nextPeriod)) ") + Text("\(ScheduleEngine.formatRemainingMinutes(remaining))분 후").foregroundColor(.orange))
                        .font(.caption)
                }
            }

        case .beforeSchool(_, let firstEntry, let remaining):
            VStack(alignment: .leading, spacing: 2) {
                Text("등교 전")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(firstEntry.subject)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    countdownText(remaining: remaining, entryDate: entryDate)
                        .font(.caption)
                    Text("후 시작")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

        case .afterSchool:
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "house")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("하교")
                    .font(.headline)
                Text("오늘 수업이 끝났습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .weekend:
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "moon.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("주말")
                    .font(.headline)
                Text("오늘은 수업이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .noClass:
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "calendar.badge.minus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("수업 없음")
                    .font(.headline)
                Text("오늘은 등록된 수업이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Inline Complication

struct InlineView: View {
    let state: ScheduleState
    let entryDate: Date

    var body: some View {
        switch state {
        case .inClass(_, let entry, let remaining, _):
            if remaining <= 180 {
                Text("\(entry.subject) \(timerInterval: entryDate...entryDate.addingTimeInterval(remaining), countsDown: true)")
            } else {
                Text("\(entry.subject) \(ScheduleEngine.formatRemainingMinutes(remaining))분")
            }

        case .breakTime(_, let nextEntry, let remaining):
            if remaining <= 180 {
                Text("\(nextEntry.subject) \(timerInterval: entryDate...entryDate.addingTimeInterval(remaining), countsDown: true)")
            } else {
                Text("\(nextEntry.subject) \(ScheduleEngine.formatRemainingMinutes(remaining))분후")
            }

        case .beforeSchool(_, let firstEntry, let remaining):
            if remaining <= 180 {
                Text("\(firstEntry.subject) \(timerInterval: entryDate...entryDate.addingTimeInterval(remaining), countsDown: true)")
            } else {
                Text("\(firstEntry.subject) \(ScheduleEngine.formatRemainingMinutes(remaining))분후")
            }

        case .afterSchool:
            Text("하교")

        case .weekend:
            Text("주말")

        case .noClass:
            Text("수업 없음")
        }
    }
}

// MARK: - Corner Complication

struct CornerView: View {
    let state: ScheduleState
    let entryDate: Date

    var body: some View {
        switch state {
        case .inClass(_, let entry, let remaining, _):
            VStack {
                countdownText(remaining: remaining, entryDate: entryDate)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(urgencyColor(remaining: remaining, normal: .primary))
                Text(entry.subject)
                    .font(.system(size: 10))
            }

        case .breakTime(_, let nextEntry, let remaining):
            VStack {
                countdownText(remaining: remaining, entryDate: entryDate)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(urgencyColor(remaining: remaining, normal: .primary))
                Text(nextEntry.subject)
                    .font(.system(size: 10))
            }

        case .beforeSchool(_, let firstEntry, let remaining):
            VStack {
                countdownText(remaining: remaining, entryDate: entryDate)
                    .font(.system(.title, design: .rounded).bold())
                Text(firstEntry.subject)
                    .font(.system(size: 10))
            }

        case .afterSchool:
            VStack {
                Image(systemName: "house")
                    .font(.title3)
                Text("하교")
                    .font(.system(size: 10))
            }

        case .weekend:
            VStack {
                Image(systemName: "moon.stars")
                    .font(.title3)
                Text("주말")
                    .font(.system(size: 10))
            }

        case .noClass:
            VStack {
                Image(systemName: "calendar.badge.minus")
                    .font(.title3)
                Text("없음")
                    .font(.system(size: 10))
            }
        }
    }
}

// MARK: - Entry View

struct NoaWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ScheduleEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            CircularView(state: entry.state, entryDate: entry.date)
        case .accessoryRectangular:
            RectangularView(state: entry.state, entryDate: entry.date)
        case .accessoryInline:
            InlineView(state: entry.state, entryDate: entry.date)
        case .accessoryCorner:
            CornerView(state: entry.state, entryDate: entry.date)
        default:
            RectangularView(state: entry.state, entryDate: entry.date)
        }
    }
}

// MARK: - Widget Definition

struct NoaWidget: Widget {
    let kind: String = "NoaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
            NoaWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("시간표")
        .description("현재 수업 정보를 워치페이스에 표시합니다")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}
