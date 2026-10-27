import Foundation
import UserNotifications

/// Pianifica la notifica locale giornaliera tramite UserNotifications.
enum NotificationScheduler {
    static let identifierPrefix = "daily-digest-"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Sostituisce le notifiche pianificate con quelle del piano.
    static func replace(with plan: [PlannedNotification], calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        )
        guard await authorizationStatus() == .authorized else { return }

        for planned in plan {
            let content = UNMutableNotificationContent()
            content.title = "Buongiorno"
            content.body = planned.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: planned.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = identifierPrefix + String(Int(planned.fireDate.timeIntervalSince1970))
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
