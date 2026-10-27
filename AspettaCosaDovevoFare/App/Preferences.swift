import Foundation

/// Chiavi delle Impostazioni salvate in `UserDefaults` (usate anche da `@AppStorage`).
enum PrefKey {
    static let staleWaitingDays = "staleWaitingDays"
    static let staleDoingDays = "staleDoingDays"
    static let notificationHour = "notificationHour"
    static let notificationMinute = "notificationMinute"
    /// Giorni attivi come numeri `Calendar` (1 = domenica … 7 = sabato) separati da virgola.
    static let notificationWeekdays = "notificationWeekdays"
    static let didShowNotificationPrimer = "didShowNotificationPrimer"
    static let checkInEnabled = "checkInEnabled"
    static let checkInDays = "checkInDays"
}

enum PrefDefault {
    static let staleWaitingDays = StaleThresholds.standard.waiting
    static let staleDoingDays = StaleThresholds.standard.doing
    static let notificationHour = 9
    static let notificationMinute = 0
    /// Lunedì–venerdì.
    static let notificationWeekdays = "2,3,4,5,6"
    static let checkInEnabled = true
    static let checkInDays = CheckIn.defaultDays
}

extension StaleThresholds {
    /// Soglie correnti salvate nelle Impostazioni.
    static func current(_ defaults: UserDefaults = .standard) -> StaleThresholds {
        StaleThresholds(
            waiting: defaults.object(forKey: PrefKey.staleWaitingDays) as? Int ?? PrefDefault.staleWaitingDays,
            doing: defaults.object(forKey: PrefKey.staleDoingDays) as? Int ?? PrefDefault.staleDoingDays
        )
    }
}

/// Giorni attivi della notifica, da e verso la stringa salvata.
func parseWeekdays(_ text: String) -> Set<Int> {
    Set(text.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (1...7).contains($0) })
}

func formatWeekdays(_ days: Set<Int>) -> String {
    days.sorted().map(String.init).joined(separator: ",")
}
