import SwiftUI

struct PeriodTimeEditSheet: View {
    var store: TimetableStore
    let period: Int
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date

    init(store: TimetableStore, period: Int) {
        self.store = store
        self.period = period
        let periodTime = store.timetable.periodTimes[period]
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        _startDate = State(initialValue: calendar.date(bySettingHour: periodTime.startHour, minute: periodTime.startMinute, second: 0, of: base)!)
        _endDate = State(initialValue: calendar.date(bySettingHour: periodTime.endHour, minute: periodTime.endMinute, second: 0, of: base)!)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(period + 1)교시 시간 설정") {
                    DatePicker("시작 시각", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("종료 시각", selection: $endDate, displayedComponents: .hourAndMinute)
                }

                Section {
                    HStack {
                        Text("현재 설정")
                        Spacer()
                        Text(store.timetable.periodTimes[period].displayString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(period + 1)교시 시간")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let calendar = Calendar.current
                        let startComps = calendar.dateComponents([.hour, .minute], from: startDate)
                        let endComps = calendar.dateComponents([.hour, .minute], from: endDate)
                        store.timetable.periodTimes[period] = PeriodTime(
                            startHour: startComps.hour ?? 0,
                            startMinute: startComps.minute ?? 0,
                            endHour: endComps.hour ?? 0,
                            endMinute: endComps.minute ?? 0
                        )
                        ConnectivityManager.shared.sendTimetable()
                        dismiss()
                    }
                }
            }
        }
    }
}
