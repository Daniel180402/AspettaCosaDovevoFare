import Foundation

/// Una notifica giornaliera da pianificare.
struct PlannedNotification: Equatable, Sendable {
    var fireDate: Date
    var body: String
}

/// Prossimi `count` istanti futuri all'ora indicata nei giorni attivi (numeri `Calendar`: 1 = domenica).
func upcomingFireDates(
    after now: Date,
    hour: Int,
    minute: Int,
    weekdays: Set<Int>,
    count: Int,
    calendar: Calendar = .current
) -> [Date] {
    guard !weekdays.isEmpty, count > 0 else { return [] }
    var dates: [Date] = []
    var day = calendar.startOfDay(for: now)
    // Al massimo poche settimane in avanti: con almeno un giorno attivo bastano sempre.
    for _ in 0..<(count * 7 + 7) where dates.count < count {
        if weekdays.contains(calendar.component(.weekday, from: day)),
           let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
           fire > now {
            dates.append(fire)
        }
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
    }
    return dates
}

/// Notifiche dei prossimi giorni, ognuna con i conteggi che varranno in quel momento
/// (se nel frattempo non cambia niente; a ogni modifica il piano si ricalcola).
func planDailyNotifications(
    _ items: [some ItemFields],
    now: Date,
    hour: Int,
    minute: Int,
    weekdays: Set<Int>,
    thresholds: StaleThresholds,
    count: Int = 14,
    calendar: Calendar = .current
) -> [PlannedNotification] {
    upcomingFireDates(after: now, hour: hour, minute: minute, weekdays: weekdays, count: count, calendar: calendar)
        .compactMap { date in
            let summary = summarize(items, now: date, thresholds: thresholds, calendar: calendar)
            return dailyNotificationBody(summary).map { PlannedNotification(fireDate: date, body: $0) }
        }
}
