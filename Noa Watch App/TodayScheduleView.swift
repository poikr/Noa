import SwiftUI

struct TodayScheduleView: View {
    var store: TimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let weekday = Weekday.from(date: context.date)
            if let weekday {
                let classes = store.timetable.todayClasses(for: weekday)
                if classes.isEmpty {
                    ContentUnavailableView("수업 없음", systemImage: "calendar.badge.minus", description: Text("오늘은 등록된 수업이 없습니다"))
                } else {
                    todayList(classes: classes, weekday: weekday, date: context.date)
                }
            } else {
                ContentUnavailableView("주말", systemImage: "moon.stars", description: Text("오늘은 수업이 없습니다"))
            }
        }
    }

    private func todayList(classes: [(period: Int, entry: ClassEntry)], weekday: Weekday, date: Date) -> some View {
        ScrollView {
            VStack(spacing: 4) {
                Text("\(weekday.fullDisplayName) 시간표")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(classes, id: \.period) { item in
                    let isNow = isCurrentPeriod(period: item.period, date: date)
                    let isPast = isPastPeriod(period: item.period, date: date)
                    let lastPastPeriod = classes.last(where: { isPastPeriod(period: $0.period, date: date) })?.period
                    let isLastEnded = isPast && item.period == lastPastPeriod

                    HStack(spacing: 6) {
                        Text(periodLabel(item.period))
                            .font(.caption2.bold())
                            .frame(width: 16)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(item.entry.subject)
                                    .font(.caption.bold())
                                if isNow {
                                    Text("NOW")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.green)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                } else if isLastEnded {
                                    Text("END")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.red)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            if item.period < store.timetable.periodTimes.count {
                                Text(store.timetable.periodTimes[item.period].displayString)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isNow ? Color.green.opacity(0.2) : Color.clear)
                    )
                    .opacity(isPast ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func periodLabel(_ period: Int) -> String {
        guard period < store.timetable.periodTimes.count,
              !store.timetable.periodTimes[period].name.isEmpty else {
            return "\(period + 1)"
        }
        return store.timetable.periodTimes[period].name
    }

    private func isCurrentPeriod(period: Int, date: Date) -> Bool {
        guard period < store.timetable.periodTimes.count else { return false }
        let periodTime = store.timetable.periodTimes[period]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return currentMinutes >= periodTime.startTotalMinutes && currentMinutes < periodTime.endTotalMinutes
    }

    private func isPastPeriod(period: Int, date: Date) -> Bool {
        guard period < store.timetable.periodTimes.count else { return false }
        let periodTime = store.timetable.periodTimes[period]
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return currentMinutes >= periodTime.endTotalMinutes
    }
}
