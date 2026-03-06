import SwiftUI
import UniformTypeIdentifiers

struct TimetableDocument: Transferable {
    let data: Data

    var utf8String: String {
        String(data: data, encoding: .utf8) ?? ""
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { doc in
            doc.data
        }
        DataRepresentation(exportedContentType: .utf8PlainText) { doc in
            doc.data
        }
    }
}

struct SettingsView: View {
    var store = TimetableStore.shared
    var connectivity = ConnectivityManager.shared
    @State private var showResetAlert = false
    @State private var showImporter = false
    @State private var showExportError = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportSuccess = false
    @State private var showPasteImport = false
    @State private var pasteText = ""

    private let minuteOptions = [1, 3, 5, 10, 15]

    var body: some View {
        NavigationStack {
            Form {
                Section("등교 시간") {
                    HStack {
                        Text("등교 시간")
                        Spacer()
                        Picker("시", selection: Binding(
                            get: { store.timetable.arrivalHour },
                            set: {
                                store.timetable.arrivalHour = $0
                                ConnectivityManager.shared.sendTimetable()
                            }
                        )) {
                            ForEach(4..<13, id: \.self) { h in
                                Text("\(h)시").tag(h)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Picker("분", selection: Binding(
                            get: { store.timetable.arrivalMinute },
                            set: {
                                store.timetable.arrivalMinute = $0
                                ConnectivityManager.shared.sendTimetable()
                            }
                        )) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                                Text(String(format: "%02d분", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("기타 일정") {
                    NavigationLink("기타 일정 (학원 등)") {
                        ExtraScheduleListView(store: store)
                    }
                }

                Section("교시 수") {
                    Stepper(
                        "\(store.timetable.periodCount)교시",
                        value: Binding(
                            get: { store.timetable.periodCount },
                            set: { newValue in
                                if newValue > store.timetable.periodCount {
                                    store.timetable.addPeriod()
                                } else if newValue < store.timetable.periodCount {
                                    store.timetable.removePeriod()
                                }
                                ConnectivityManager.shared.sendTimetable()
                            }
                        ),
                        in: 1...99
                    )
                }

                Section("수업 알림") {
                    Picker("수업 시작 전 알림", selection: Binding(
                        get: { store.notificationMinutesBefore },
                        set: { store.notificationMinutesBefore = $0 }
                    )) {
                        ForEach(minuteOptions, id: \.self) { minutes in
                            Text("\(minutes)분 전").tag(minutes)
                        }
                    }

                    Button("알림 재등록") {
                        NotificationManager.shared.scheduleNotifications(
                            for: store.timetable,
                            minutesBefore: store.notificationMinutesBefore
                        )
                    }
                }

                Section("Watch 연결") {
                    HStack {
                        Text("연결 상태")
                        Spacer()
                        Image(systemName: connectivity.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                            .foregroundStyle(connectivity.isReachable ? .green : .secondary)
                        Text(connectivity.isReachable ? "연결됨" : "연결 안 됨")
                            .foregroundStyle(.secondary)
                    }

                    if let lastSync = connectivity.lastSyncDate {
                        HStack {
                            Text("마지막 동기화")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("수동 동기화") {
                        connectivity.sendTimetable()
                    }
                }

                Section("시간표 내보내기 / 불러오기") {
                    if let data = store.exportJSON() {
                        ShareLink(
                            item: TimetableDocument(data: data),
                            preview: SharePreview("Noa 시간표", image: Image(systemName: "calendar"))
                        ) {
                            Label("시간표 내보내기", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            if let str = String(data: data, encoding: .utf8) {
                                UIPasteboard.general.string = str
                            }
                        } label: {
                            Label("클립보드에 복사", systemImage: "doc.on.doc")
                        }
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label("파일에서 불러오기", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        pasteText = UIPasteboard.general.string ?? ""
                        showPasteImport = true
                    } label: {
                        Label("클립보드에서 불러오기", systemImage: "doc.on.clipboard")
                    }
                }

                Section {
                    Button("시간표 초기화", role: .destructive) {
                        showResetAlert = true
                    }
                }
            }
            .navigationTitle("설정")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else {
                        importErrorMessage = "파일에 접근할 수 없습니다."
                        showImportError = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        try store.importJSON(from: data)
                        ConnectivityManager.shared.sendTimetable()
                        NotificationManager.shared.scheduleNotifications(
                            for: store.timetable,
                            minutesBefore: store.notificationMinutesBefore
                        )
                        showImportSuccess = true
                    } catch {
                        importErrorMessage = error.localizedDescription
                        showImportError = true
                    }
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showImportError = true
                }
            }
            .alert("시간표 초기화", isPresented: $showResetAlert) {
                Button("초기화", role: .destructive) {
                    store.resetTimetable()
                    ConnectivityManager.shared.sendTimetable()
                    NotificationManager.shared.scheduleNotifications(
                        for: store.timetable,
                        minutesBefore: store.notificationMinutesBefore
                    )
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("모든 시간표 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("불러오기 실패", isPresented: $showImportError) {
                Button("확인") {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("클립보드에서 불러오기", isPresented: $showPasteImport) {
                Button("불러오기") {
                    guard let data = pasteText.data(using: .utf8) else {
                        importErrorMessage = "클립보드 내용을 읽을 수 없습니다."
                        showImportError = true
                        return
                    }
                    do {
                        try store.importJSON(from: data)
                        ConnectivityManager.shared.sendTimetable()
                        NotificationManager.shared.scheduleNotifications(
                            for: store.timetable,
                            minutesBefore: store.notificationMinutesBefore
                        )
                        showImportSuccess = true
                    } catch {
                        importErrorMessage = error.localizedDescription
                        showImportError = true
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("클립보드의 내용으로 시간표를 불러올까요?")
            }
            .alert("불러오기 완료", isPresented: $showImportSuccess) {
                Button("확인") {}
            } message: {
                Text("시간표를 성공적으로 불러왔습니다.")
            }
        }
    }
}
