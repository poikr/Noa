import SwiftUI

struct TodayScheduleView: View {
    var store: TimetableStore

    struct ScheduleItem: Identifiable {
        let id: String
        let entry: ClassEntry
        let periodLabel: String
        let timeString: String
        let startMinutes: Int
        let endMinutes: Int
        let isExtra: Bool
        let isFood: Bool
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let weekday = Weekday.from(date: context.date)
            if let weekday {
                let items = buildItems(for: weekday)
                if items.isEmpty {
                    ContentUnavailableView("수업 없음", systemImage: "calendar.badge.minus", description: Text("오늘은 등록된 수업이 없습니다"))
                } else {
                    todayList(items: items, weekday: weekday, date: context.date)
                }
            } else {
                ContentUnavailableView("주말", systemImage: "moon.stars", description: Text("오늘은 수업이 없습니다"))
            }
        }
    }

    private func buildItems(for weekday: Weekday) -> [ScheduleItem] {
        var items: [ScheduleItem] = []

        let classes = store.timetable.todayClasses(for: weekday)
        for (period, entry) in classes {
            guard period < store.timetable.periodTimes.count else { continue }
            let pt = store.timetable.periodTimes[period]
            items.append(ScheduleItem(
                id: "class_\(period)",
                entry: entry,
                periodLabel: pt.name.isEmpty ? "\(period + 1)" : pt.name,
                timeString: pt.displayString,
                startMinutes: pt.startTotalMinutes,
                endMinutes: pt.endTotalMinutes,
                isExtra: false,
                isFood: entry.isFood
            ))
        }

        let extras = store.timetable.todayExtraSchedules(for: weekday)
        for extra in extras {
            let entry = ClassEntry(subject: extra.name, teacher: "", classroom: "", colorName: extra.colorName)
            items.append(ScheduleItem(
                id: "extra_\(extra.id)",
                entry: entry,
                periodLabel: "•",
                timeString: extra.displayTimeString,
                startMinutes: extra.startTotalMinutes,
                endMinutes: extra.endTotalMinutes,
                isExtra: true,
                isFood: false
            ))
        }

        items.sort { $0.startMinutes < $1.startMinutes }
        return items
    }

    private func todayList(items: [ScheduleItem], weekday: Weekday, date: Date) -> some View {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return ScrollView {
            VStack(spacing: 4) {
                Text("\(weekday.fullDisplayName) 시간표")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                ForEach(items) { item in
                    let isNow = currentMinutes >= item.startMinutes && currentMinutes < item.endMinutes
                    let isPast = currentMinutes >= item.endMinutes
                    let lastPastItem = items.last(where: { currentMinutes >= $0.endMinutes })
                    let isLastEnded = isPast && item.id == lastPastItem?.id

                    HStack(spacing: 6) {
                        Text(item.periodLabel)
                            .font(.caption2.bold())
                            .frame(width: 16)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                if item.isFood {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.orange)
                                }
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
                            Text(item.timeString)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isNow ? (item.isExtra ? Color.purple.opacity(0.2) : Color.green.opacity(0.2)) : Color.clear)
                    )
                    .opacity(isPast ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
