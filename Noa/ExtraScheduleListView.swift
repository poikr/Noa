import SwiftUI

struct ExtraScheduleListView: View {
    var store: TimetableStore
    @State private var editingSchedule: ExtraSchedule?
    @State private var showAddSheet = false

    var body: some View {
        List {
            ForEach(Weekday.allCases) { weekday in
                let schedules = store.timetable.todayExtraSchedules(for: weekday)
                if !schedules.isEmpty {
                    Section(weekday.fullDisplayName) {
                        ForEach(schedules) { schedule in
                            Button {
                                editingSchedule = schedule
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(schedule.color)
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading) {
                                        Text(schedule.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(schedule.displayTimeString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            deleteSchedules(weekday: weekday, at: offsets)
                        }
                    }
                }
            }

            if store.timetable.extraSchedules.isEmpty {
                ContentUnavailableView("기타 일정 없음", systemImage: "calendar.badge.plus", description: Text("학원 등 기타 일정을 추가해보세요"))
            }
        }
        .navigationTitle("기타 일정")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            ExtraScheduleEditSheet(store: store, schedule: nil)
        }
        .sheet(item: $editingSchedule) { schedule in
            ExtraScheduleEditSheet(store: store, schedule: schedule)
        }
    }

    private func deleteSchedules(weekday: Weekday, at offsets: IndexSet) {
        let schedules = store.timetable.todayExtraSchedules(for: weekday)
        for offset in offsets {
            let schedule = schedules[offset]
            store.timetable.extraSchedules.removeAll { $0.id == schedule.id }
        }
        ConnectivityManager.shared.sendTimetable()
    }
}

struct ExtraScheduleEditSheet: View {
    var store: TimetableStore
    let schedule: ExtraSchedule?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var weekday: Weekday
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var colorName: String

    init(store: TimetableStore, schedule: ExtraSchedule?) {
        self.store = store
        self.schedule = schedule
        _name = State(initialValue: schedule?.name ?? "")
        _weekday = State(initialValue: schedule?.weekday ?? .monday)
        _startHour = State(initialValue: schedule?.startHour ?? 16)
        _startMinute = State(initialValue: schedule?.startMinute ?? 0)
        _endHour = State(initialValue: schedule?.endHour ?? 18)
        _endMinute = State(initialValue: schedule?.endMinute ?? 0)
        _colorName = State(initialValue: schedule?.colorName ?? "purple")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름", text: $name)
                    Picker("요일", selection: $weekday) {
                        ForEach(Weekday.allCases) { day in
                            Text(day.fullDisplayName).tag(day)
                        }
                    }
                }

                Section("시작 시간") {
                    HStack {
                        Picker("시", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)시").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        Picker("분", selection: $startMinute) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                                Text(String(format: "%02d분", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 120)
                }

                Section("종료 시간") {
                    HStack {
                        Picker("시", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)시").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        Picker("분", selection: $endMinute) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                                Text(String(format: "%02d분", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 120)
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(ClassEntry.availableColors, id: \.name) { color in
                            Circle()
                                .fill(ClassEntry(subject: "", teacher: "", classroom: "", colorName: color.name).color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if colorName == color.name {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 2.5)
                                    }
                                }
                                .onTapGesture {
                                    colorName = color.name
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if schedule != nil {
                    Section {
                        Button("삭제", role: .destructive) {
                            if let id = schedule?.id {
                                store.timetable.extraSchedules.removeAll { $0.id == id }
                                ConnectivityManager.shared.sendTimetable()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(schedule == nil ? "일정 추가" : "일정 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let newSchedule = ExtraSchedule(
                            id: schedule?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            startHour: startHour,
                            startMinute: startMinute,
                            endHour: endHour,
                            endMinute: endMinute,
                            weekday: weekday,
                            colorName: colorName
                        )
                        if let existingId = schedule?.id {
                            if let idx = store.timetable.extraSchedules.firstIndex(where: { $0.id == existingId }) {
                                store.timetable.extraSchedules[idx] = newSchedule
                            }
                        } else {
                            store.timetable.extraSchedules.append(newSchedule)
                        }
                        ConnectivityManager.shared.sendTimetable()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
