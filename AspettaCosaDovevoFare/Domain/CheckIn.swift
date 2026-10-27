import Foundation

/// Riquadro che chiede aggiornamenti sui punti fermi: quando compare e per quali punti.
enum CheckIn {
    /// Il riquadro compare solo in questa fascia oraria (dalle 9:00 alle 17:59).
    static let startHour = 9
    static let endHour = 18
    static let defaultDays = 3

    static func isWithinHours(_ now: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: now)
        return hour >= startHour && hour < endHour
    }

    /// Vero se il punto è aperto e va chiesto adesso: dopo `nextCheckAt` se c'è,
    /// altrimenti quando è senza aggiornamenti da almeno `days` giorni.
    static func isDue(_ item: some ItemFields, now: Date, days: Int, calendar: Calendar = .current) -> Bool {
        guard !item.isDone else { return false }
        if let next = item.nextCheckAt { return now >= next }
        return daysSinceActivity(item, now: now, calendar: calendar) >= days
    }

    /// Punti da chiedere, prima quelli fermi da più tempo.
    static func dueItems<I: ItemFields>(_ items: [I], now: Date, days: Int, calendar: Calendar = .current) -> [I] {
        items
            .filter { isDue($0, now: now, days: days, calendar: calendar) }
            .sorted { lastActivity($0) < lastActivity($1) }
    }

    /// Inizio della fascia oraria tra `days` giorni: è lì che il riquadro richiede del punto.
    static func askAgainDate(inDays days: Int, from now: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.date(byAdding: .day, value: max(1, days), to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day) ?? day
    }

    /// "Più tardi": fra un'ora, oppure domattina se l'ora cade fuori fascia.
    static func laterDate(from now: Date, calendar: Calendar = .current) -> Date {
        let inOneHour = now.addingTimeInterval(3600)
        return isWithinHours(inOneHour, calendar: calendar) ? inOneHour : nextWindowStart(after: inOneHour, calendar: calendar)
    }

    private static func nextWindowStart(after date: Date, calendar: Calendar) -> Date {
        let today = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date
        return today > date ? today : askAgainDate(inDays: 1, from: date, calendar: calendar)
    }

    /// Domanda mostrata nel riquadro.
    static func question(for item: some ItemFields, now: Date, calendar: Calendar = .current) -> String {
        let days = daysSinceActivity(item, now: now, calendar: calendar)
        let since = days == 1 ? "da 1 giorno" : "da \(days) giorni"
        switch item.kind {
        case .fare:
            return "Fermo \(since) senza aggiornamenti. Ci sono novità?"
        case .attesa:
            let people = parsePeople(item.people)
            let who = people.isEmpty ? "al cliente o al dev" : "a " + italianList(people)
            return "Aspetti una risposta \(since). È il caso di fare un ping \(who)?"
        }
    }

    /// Riga aggiunta in testa alla nota quando si registra un aggiornamento, es. "26/10: risposto Paolo".
    static func noteWithUpdate(_ note: String, update: String, now: Date, calendar: Calendar = .current) -> String {
        let text = update.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return note }
        let c = calendar.dateComponents([.day, .month], from: now)
        let stamp = String(format: "%02d/%02d", c.day ?? 0, c.month ?? 0)
        let line = "\(stamp): \(text)"
        let combined = note.isEmpty ? line : line + "\n" + note
        return String(combined.prefix(PendingItem.noteLimit))
    }
}

/// Intervalli proposti in "Richiedimelo tra".
enum AskAgainInterval: Int, CaseIterable, Identifiable, Sendable {
    case oneDay = 1
    case twoDays = 2
    case threeDays = 3
    case oneWeek = 7
    case twoWeeks = 14

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneDay: "domani"
        case .twoDays: "2 giorni"
        case .threeDays: "3 giorni"
        case .oneWeek: "1 settimana"
        case .twoWeeks: "2 settimane"
        }
    }
}

/// "Paolo", "Simo e Clark", "Axel, Seb e Simo".
func italianList(_ names: [String]) -> String {
    guard names.count > 1, let last = names.last else { return names.first ?? "" }
    return names.dropLast().joined(separator: ", ") + " e " + last
}
