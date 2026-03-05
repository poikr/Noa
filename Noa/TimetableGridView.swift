import SwiftUI

private struct EditingSlot: Identifiable {
    let weekday: Weekday
    let period: Int
    var id: String { "\(weekday.rawValue)_\(period)" }
}

private struct EditingPeriod: Identifiable {
    let value: Int
    var id: Int { value }
}

struct TimetableGridView: View {
    var store = TimetableStore.shared
    @State private var editingSlot: EditingSlot?
    @State private var editingPeriod: EditingPeriod?

    var body: some View {
        NavigationStack {
            ScrollView {
                Grid(alignment: .center, horizontalSpacing: 2, verticalSpacing: 2) {
                    // Header
                    GridRow {
                        Color.clear
                            .frame(width: 44)
                            .gridCellUnsizedAxes(.vertical)
                        ForEach(Weekday.allCases) { day in
                            Text(day.displayName)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    // Period rows
                    ForEach(0..<store.timetable.periodCount, id: \.self) { period in
                        GridRow {
                            // Period label - tap to edit time
                            Button {
                                editingPeriod = EditingPeriod(value: period)
                            } label: {
                                VStack(spacing: 1) {
                                    if period < store.timetable.periodTimes.count && !store.timetable.periodTimes[period].name.isEmpty {
                                        Text(store.timetable.periodTimes[period].name)
                                            .font(.system(size: 10, weight: .bold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    } else {
                                        Text("\(period + 1)")
                                            .font(.caption.bold())
                                    }
                                    if period < store.timetable.periodTimes.count {
                                        Text(store.timetable.periodTimes[period].startString)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 44, height: 56)
                            }
                            .buttonStyle(.plain)

                            // Class cells
                            ForEach(Weekday.allCases) { day in
                                let entry = store.timetable.classEntry(for: day, period: period)
                                Button {
                                    editingSlot = EditingSlot(weekday: day, period: period)
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(entry.isEmpty ? " " : entry.subject)
                                            .font(.caption)
                                            .fontWeight(entry.isEmpty ? .regular : .medium)
                                            .lineLimit(1)
                                        if !entry.classroom.isEmpty {
                                            Text(entry.classroom)
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(entry.isEmpty ? Color(.systemGray6) : entry.color.opacity(0.2))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(entry.isEmpty ? Color.clear : entry.color.opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .navigationTitle("시간표")
            .sheet(item: $editingSlot) { slot in
                ClassEditSheet(
                    store: store,
                    weekday: slot.weekday,
                    period: slot.period
                )
            }
            .sheet(item: $editingPeriod) { period in
                PeriodTimeEditSheet(
                    store: store,
                    period: period.value
                )
            }
        }
    }
}
