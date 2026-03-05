import SwiftUI

struct ContentView: View {
    var store = TimetableStore.shared

    var body: some View {
        TabView {
            WatchMainView(store: store)
            TodayScheduleView(store: store)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Helpers

private func entryDetail(_ entry: ClassEntry) -> String? {
    let hasClassroom = !entry.classroom.isEmpty
    let hasTeacher = !entry.teacher.isEmpty
    if hasClassroom && hasTeacher {
        return "(\(entry.classroom) / \(entry.teacher))"
    } else if hasClassroom {
        return "(\(entry.classroom))"
    } else if hasTeacher {
        return "(\(entry.teacher))"
    }
    return nil
}

// MARK: - Watch Main View

struct WatchMainView: View {
    var store: TimetableStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let state = ScheduleEngine.currentState(for: context.date, timetable: store.timetable)
            watchContent(for: state)
        }
    }

    private func nextPeriodDisplayName(period: Int) -> String {
        guard period < store.timetable.periodTimes.count else { return "\(period + 1)교시" }
        return store.timetable.periodTimes[period].displayName(period: period)
    }

    private func urgencyColor(remaining: TimeInterval, normal: Color) -> Color {
        remaining <= 180 ? .red : normal
    }

    @ViewBuilder
    private func watchContent(for state: ScheduleState) -> some View {
        switch state {
        case .inClass(let period, let entry, let remaining, let nextEntry):
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(urgencyColor(remaining: remaining, normal: .green)).frame(width: 8, height: 8)
                    Text("수업 중")
                        .font(.caption2)
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .green))
                }

                VStack(spacing: 2) {
                    Text(entry.subject)
                        .font(.title3.bold())
                        .lineLimit(1)
                    if let detail = entryDetail(entry) {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(ScheduleEngine.formatRemaining(remaining))
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(urgencyColor(remaining: remaining, normal: .green))

                if let next = nextEntry {
                    HStack(spacing: 4) {
                        Text("다음")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(next.subject)
                            .font(.caption2.bold())
                    }
                }

                Text(nextPeriodDisplayName(period: period))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .breakTime(let nextPeriod, let nextEntry, let remaining):
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(urgencyColor(remaining: remaining, normal: .orange)).frame(width: 8, height: 8)
                    Text("쉬는 시간")
                        .font(.caption2)
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))
                }

                VStack(spacing: 2) {
                    Text(nextEntry.subject)
                        .font(.title3.bold())
                        .lineLimit(1)
                    if let detail = entryDetail(nextEntry) {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(ScheduleEngine.formatRemaining(remaining))
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))

                HStack(spacing: 4) {
                    Text(nextPeriodDisplayName(period: nextPeriod))
                        .font(.caption2)
                    if nextPeriod < store.timetable.periodTimes.count {
                        Text(store.timetable.periodTimes[nextPeriod].startString)
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding()

        case .beforeSchool(_, let firstEntry, let remaining):
            VStack(spacing: 8) {
                Image(systemName: "sunrise")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text("등교 전")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(spacing: 2) {
                    Text(firstEntry.subject)
                        .font(.headline)
                    if let detail = entryDetail(firstEntry) {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text("\(ScheduleEngine.formatRemainingMinutes(remaining))분 후 시작")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .afterSchool:
            VStack(spacing: 8) {
                Image(systemName: "house")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("하교")
                    .font(.headline)
                Text("오늘 수업이 끝났습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .weekend:
            VStack(spacing: 8) {
                Image(systemName: "moon.stars")
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text("주말")
                    .font(.headline)
                Text("오늘은 수업이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

        case .noClass:
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.minus")
                    .font(.title3)
                    .foregroundStyle(.gray)
                Text("수업 없음")
                    .font(.headline)
                Text("오늘은 등록된 수업이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
