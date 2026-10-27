import Foundation

// Logica di dominio pura: nessuna dipendenza da SwiftUI o SwiftData, tutto testabile.

/// Giorni oltre i quali un punto aperto è considerato fermo.
struct StaleThresholds: Equatable, Sendable {
    /// Soglia per `.attesa`.
    var waiting: Int
    /// Soglia per `.fare`.
    var doing: Int

    static let standard = StaleThresholds(waiting: 3, doing: 5)
}

/// Giorni di calendario interi trascorsi da `createdAt` a `now` (mai negativi).
func ageInDays(_ item: some ItemFields, now: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: item.createdAt)
    let end = calendar.startOfDay(for: now)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
}

/// Data dell'ultimo aggiornamento, o della creazione se non ce ne sono stati.
func lastActivity(_ item: some ItemFields) -> Date {
    max(item.lastActivityAt ?? item.createdAt, item.createdAt)
}

/// Giorni di calendario trascorsi dall'ultimo aggiornamento (mai negativi).
func daysSinceActivity(_ item: some ItemFields, now: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: lastActivity(item))
    let end = calendar.startOfDay(for: now)
    return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
}

/// Vero se il punto è senza aggiornamenti da almeno la soglia prevista per il suo tipo.
func isStale(
    _ item: some ItemFields,
    now: Date,
    thresholds: StaleThresholds = .standard,
    calendar: Calendar = .current
) -> Bool {
    guard !item.isDone else { return false }
    let age = daysSinceActivity(item, now: now, calendar: calendar)
    switch item.kind {
    case .attesa: return age >= thresholds.waiting
    case .fare: return age >= thresholds.doing
    }
}

/// "aperto oggi", "da 1 giorno", "da N giorni".
func ageLabel(days: Int) -> String {
    switch days {
    case ..<1: "aperto oggi"
    case 1: "da 1 giorno"
    default: "da \(days) giorni"
    }
}

/// Punti aperti: prima i più vecchi; a parità di data, per titolo.
func sortedOpen<I: ItemFields>(_ items: [I]) -> [I] {
    items.sorted { a, b in
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }
}

/// Punti chiusi: prima gli ultimi chiusi.
func sortedClosed<I: ItemFields>(_ items: [I]) -> [I] {
    items.sorted { a, b in
        let da = a.doneAt ?? .distantPast, db = b.doneAt ?? .distantPast
        if da != db { return da > db }
        return a.title.localizedStandardCompare(b.title) == .orderedAscending
    }
}

/// Nomi dal campo `people`, separati da virgola, ripuliti e senza doppioni.
func parsePeople(_ people: String) -> [String] {
    var seen = Set<String>()
    return people
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
}

/// Accetta solo URL http/https completi; stringa vuota → nil.
func validatedLink(_ text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
          let host = url.host, !host.isEmpty
    else { return nil }
    return url
}

/// Testo del pulsante che apre il link.
func linkLabel(for url: URL) -> String {
    url.absoluteString.localizedCaseInsensitiveContains("upkeep") ? "Apri su Upkeep" : "Apri link"
}

/// Conteggi mostrati nella riga di riepilogo, nel badge e nella notifica.
struct ItemSummary: Equatable, Sendable {
    var fare = 0
    var attesa = 0
    /// Punti aperti fermi oltre la soglia, di qualsiasi tipo (badge della menu bar).
    var stale = 0
    /// Punti `.attesa` fermi: le attese da sollecitare.
    var staleAttesa = 0

    func count(for kind: Kind) -> Int {
        switch kind {
        case .fare: fare
        case .attesa: attesa
        }
    }
}

func summarize(
    _ items: [some ItemFields],
    now: Date,
    thresholds: StaleThresholds = .standard,
    calendar: Calendar = .current
) -> ItemSummary {
    var s = ItemSummary()
    for item in items where !item.isDone {
        switch item.kind {
        case .fare: s.fare += 1
        case .attesa: s.attesa += 1
        }
        if isStale(item, now: now, thresholds: thresholds, calendar: calendar) {
            s.stale += 1
            if item.kind == .attesa { s.staleAttesa += 1 }
        }
    }
    return s
}

/// Testo della notifica giornaliera, o nil se non c'è niente da segnalare.
func dailyNotificationBody(_ summary: ItemSummary) -> String? {
    var parts: [String] = []
    if summary.fare > 0 {
        parts.append(summary.fare == 1 ? "1 cosa tocca a te" : "\(summary.fare) cose toccano a te")
    }
    if summary.staleAttesa > 0 {
        parts.append(summary.staleAttesa == 1 ? "1 attesa da sollecitare" : "\(summary.staleAttesa) attese da sollecitare")
    }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
}

/// Data della riga di riepilogo, es. "lunedì 26 ottobre".
func italianDayLabel(_ date: Date, calendar: Calendar = .current) -> String {
    var style = Date.FormatStyle(locale: Locale(identifier: "it_IT"), calendar: calendar, timeZone: calendar.timeZone)
    style = style.weekday(.wide).day().month(.wide)
    return date.formatted(style)
}
