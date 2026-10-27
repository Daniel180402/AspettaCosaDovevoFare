import Foundation
import Testing
@testable import AspettaCosaDovevoFare

@Suite("Notifica giornaliera")
struct NotificationPlanTests {
    let weekdays: Set<Int> = [2, 3, 4, 5, 6]

    @Test func soloGiorniFerialiEFuturi() {
        // Lunedì 26 ottobre 2026 alle 10: le 9 di oggi sono già passate.
        let dates = upcomingFireDates(after: date(2026, 10, 26, 10), hour: 9, minute: 0, weekdays: weekdays, count: 5, calendar: rome)
        let days = dates.map { rome.component(.day, from: $0) }
        #expect(days == [27, 28, 29, 30, 2])
        #expect(dates.allSatisfy { rome.component(.hour, from: $0) == 9 })
    }

    @Test func oggiSeNonEAncoraOra() {
        let dates = upcomingFireDates(after: date(2026, 10, 26, 8), hour: 9, minute: 30, weekdays: weekdays, count: 1, calendar: rome)
        #expect(dates == [date(2026, 10, 26, 9, 30)])
    }

    @Test func nessunGiornoAttivo() {
        #expect(upcomingFireDates(after: .now, hour: 9, minute: 0, weekdays: [], count: 3, calendar: rome).isEmpty)
    }

    @Test func conteggiCalcolatiAlMomentoDellInvio() {
        // Attesa creata lunedì 26: diventa ferma (3 giorni) giovedì 29.
        let items = [
            record(.fare, created: date(2026, 10, 26, 8)),
            record(.attesa, created: date(2026, 10, 26, 8)),
        ]
        let plan = planDailyNotifications(items, now: date(2026, 10, 26, 10), hour: 9, minute: 0,
                                          weekdays: weekdays, thresholds: .standard, count: 3, calendar: rome)
        #expect(plan.map(\.body) == ["1 cosa tocca a te", "1 cosa tocca a te", "1 cosa tocca a te, 1 attesa da sollecitare"])
    }

    @Test func stessiConteggiDelBadgeEDellaFinestra() {
        let now = date(2026, 10, 29, 9)
        let items = SeedData.records.map { var r = $0; r.createdAt = date(2026, 10, 26, 8); return r }
        let summary = summarize(items, now: now, calendar: rome)
        #expect(dailyNotificationBody(summary) == "8 cose toccano a te, 5 attese da sollecitare")
        #expect(summary.stale == 5)
    }

    @Test func giorniSettimanaDaStringa() {
        #expect(parseWeekdays("2,3, 4,9,x") == [2, 3, 4])
        #expect(formatWeekdays([6, 2, 1]) == "1,2,6")
    }
}
