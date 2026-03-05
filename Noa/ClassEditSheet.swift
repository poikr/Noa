import SwiftUI

struct ClassEditSheet: View {
    var store: TimetableStore
    let weekday: Weekday
    let period: Int
    @Environment(\.dismiss) private var dismiss

    @State private var subject: String
    @State private var teacher: String
    @State private var classroom: String
    @State private var colorName: String

    init(store: TimetableStore, weekday: Weekday, period: Int) {
        self.store = store
        self.weekday = weekday
        self.period = period
        let entry = store.timetable.classEntry(for: weekday, period: period)
        _subject = State(initialValue: entry.subject)
        _teacher = State(initialValue: entry.teacher)
        _classroom = State(initialValue: entry.classroom)
        _colorName = State(initialValue: entry.colorName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("과목명", text: $subject)
                    TextField("선생님", text: $teacher)
                    TextField("교실", text: $classroom)
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

                if !store.timetable.classEntry(for: weekday, period: period).isEmpty {
                    Section {
                        Button("수업 삭제", role: .destructive) {
                            store.timetable.setClassEntry(.empty, for: weekday, period: period)
                            ConnectivityManager.shared.sendTimetable()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("\(weekday.displayName) \(period + 1)교시")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let entry = ClassEntry(
                            subject: subject.trimmingCharacters(in: .whitespaces),
                            teacher: teacher.trimmingCharacters(in: .whitespaces),
                            classroom: classroom.trimmingCharacters(in: .whitespaces),
                            colorName: colorName
                        )
                        store.timetable.setClassEntry(entry, for: weekday, period: period)
                        ConnectivityManager.shared.sendTimetable()
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
