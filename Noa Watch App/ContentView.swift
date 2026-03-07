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

    private func periodDisplayName(period: Int, entry: ClassEntry? = nil) -> String {
        if period < 0 {
            return entry?.subject ?? ""
        }
        guard period < store.timetable.periodTimes.count else { return "\(period + 1)교시" }
        return store.timetable.periodTimes[period].displayName(period: period)
    }

    private func urgencyColor(remaining: TimeInterval, normal: Color) -> Color {
        remaining <= 180 ? .red : normal
    }

    @ViewBuilder
    private func watchContent(for state: ScheduleState) -> some View {
        switch state {
        case .inClass(let period, let entry, let remaining, let nextEntry, let isFood):
            if isFood {
                // Food flag: render like break time (show next class info)
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(urgencyColor(remaining: remaining, normal: .orange)).frame(width: 8, height: 8)
                        Text(entry.subject)
                            .font(.caption2)
                            .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))
                    }

                    if let next = nextEntry {
                        VStack(spacing: 2) {
                            Text(next.subject)
                                .font(.title3.bold())
                                .lineLimit(1)
                            if let detail = entryDetail(next) {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("마지막 수업")
                            .font(.title3.bold())
                    }

                    Text(ScheduleEngine.formatRemaining(remaining))
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(urgencyColor(remaining: remaining, normal: .orange))

                    Text(periodDisplayName(period: period, entry: entry))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                // Normal in-class
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

                    Text(periodDisplayName(period: period, entry: entry))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

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
                    Text(periodDisplayName(period: nextPeriod, entry: nextEntry))
                        .font(.caption2)
                    if nextPeriod >= 0, nextPeriod < store.timetable.periodTimes.count {
                        Text(store.timetable.periodTimes[nextPeriod].startString)
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding()

        case .goingToSchool(let firstEntry, let arrivalRemaining, let classRemaining):
            if arrivalRemaining > 1800 {
                // More than 30 min before arrival
                VStack(spacing: 8) {
                    Image(systemName: "sunrise")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                    Text("등교")
                        .font(.headline)
                    VStack(spacing: 2) {
                        Text(firstEntry.subject)
                            .font(.caption)
                        Text("\(ScheduleEngine.formatRemainingMinutes(classRemaining))분 후 첫 수업")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else if arrivalRemaining > 180 {
                // 30 min to 3 min before arrival
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("등교")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text("지각 전까지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ScheduleEngine.formatRemainingMinutes(arrivalRemaining))분")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(.orange)
                    Text(firstEntry.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                // 3 min or less before arrival
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("등교")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    Text("지각 전까지")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ScheduleEngine.formatRemaining(arrivalRemaining))
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundStyle(.red)
                    Text(firstEntry.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

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
