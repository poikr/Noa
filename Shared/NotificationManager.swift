import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleNotifications(for timetable: Timetable, minutesBefore: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard minutesBefore > 0 else { return }

        for weekday in Weekday.allCases {
            let classes = timetable.todayClasses(for: weekday)
            for (period, entry) in classes {
                guard period < timetable.periodTimes.count else { continue }
                let periodTime = timetable.periodTimes[period]

                var totalMinutes = periodTime.startHour * 60 + periodTime.startMinute - minutesBefore
                if totalMinutes < 0 { totalMinutes += 24 * 60 }

                var dateComponents = DateComponents()
                dateComponents.weekday = weekday.rawValue
                dateComponents.hour = totalMinutes / 60
                dateComponents.minute = totalMinutes % 60

                let content = UNMutableNotificationContent()
                content.title = "\(entry.subject) 수업 알림"
                content.body = "\(minutesBefore)분 후 \(period + 1)교시 \(entry.subject) 수업이 시작됩니다."
                if !entry.classroom.isEmpty {
                    content.body += " (교실: \(entry.classroom))"
                }
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let id = "class_\(weekday.rawValue)_\(period)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
