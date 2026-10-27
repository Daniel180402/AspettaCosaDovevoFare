import Foundation
import Testing
@testable import AspettaCosaDovevoFare

@Suite("Riquadro aggiornamenti")
struct CheckInTests {
    @Test(arguments: [(8, 59, false), (9, 0, true), (13, 30, true), (17, 59, true), (18, 0, false), (22, 0, false)])
    func soloTraLe9ELe18(hour: Int, minute: Int, expected: Bool) {
        #expect(CheckIn.isWithinHours(date(2026, 10, 26, hour, minute), calendar: rome) == expected)
    }

    @Test func chiedeDopoTreGiorniSenzaAggiornamenti() {
        let now = date(2026, 10, 26, 10)
        #expect(!CheckIn.isDue(record(.fare, created: date(2026, 10, 24)), now: now, days: 3, calendar: rome))
        #expect(CheckIn.isDue(record(.fare, created: date(2026, 10, 23)), now: now, days: 3, calendar: rome))
        #expect(CheckIn.isDue(record(.attesa, created: date(2026, 10, 23)), now: now, days: 3, calendar: rome))
    }

    @Test func unAggiornamentoAzzeraIlConteggio() {
        var item = record(.attesa, created: date(2026, 10, 1))
        item.lastActivityAt = date(2026, 10, 25)
        let now = date(2026, 10, 26, 10)
        #expect(!CheckIn.isDue(item, now: now, days: 3, calendar: rome))
        #expect(!isStale(item, now: now, calendar: rome))
        #expect(daysSinceActivity(item, now: now, calendar: rome) == 1)
        #expect(ageInDays(item, now: now, calendar: rome) == 25)
    }

    @Test func richiedimeloTraHaLaPrecedenza() {
        let now = date(2026, 10, 26, 10)
        var old = record(.fare, created: date(2026, 10, 1))
        old.nextCheckAt = date(2026, 10, 29, 9)
        #expect(!CheckIn.isDue(old, now: now, days: 3, calendar: rome))
        #expect(CheckIn.isDue(old, now: date(2026, 10, 29, 9), days: 3, calendar: rome))

        var recent = record(.fare, created: date(2026, 10, 26, 8))
        recent.nextCheckAt = date(2026, 10, 26, 9)
        #expect(CheckIn.isDue(recent, now: now, days: 3, calendar: rome))
    }

    @Test func chiusiMaiChiesti() {
        let item = record(.attesa, created: date(2026, 9, 1), done: true, doneAt: date(2026, 9, 2))
        #expect(!CheckIn.isDue(item, now: date(2026, 10, 26, 10), days: 3, calendar: rome))
    }

    @Test func primaIPiuFermi() {
        var a = record(.fare, created: date(2026, 10, 1), title: "A")
        a.lastActivityAt = date(2026, 10, 20)
        let b = record(.attesa, created: date(2026, 10, 10), title: "B")
        let c = record(.fare, created: date(2026, 10, 25), title: "C")
        let due = CheckIn.dueItems([a, b, c], now: date(2026, 10, 26, 10), days: 3, calendar: rome)
        #expect(due.map(\.title) == ["B", "A"])
    }

    @Test func richiedeAllInizioDellaFascia() {
        #expect(CheckIn.askAgainDate(inDays: 3, from: date(2026, 10, 26, 15), calendar: rome) == date(2026, 10, 29, 9))
        #expect(CheckIn.askAgainDate(inDays: 1, from: date(2026, 10, 26, 17, 59), calendar: rome) == date(2026, 10, 27, 9))
    }

    @Test func piuTardiRestaNellaFascia() {
        #expect(CheckIn.laterDate(from: date(2026, 10, 26, 10), calendar: rome) == date(2026, 10, 26, 11))
        #expect(CheckIn.laterDate(from: date(2026, 10, 26, 17, 30), calendar: rome) == date(2026, 10, 27, 9))
        #expect(CheckIn.laterDate(from: date(2026, 10, 26, 7), calendar: rome) == date(2026, 10, 26, 9))
    }

    @Test func domandaPerTipo() {
        let now = date(2026, 10, 26, 10)
        let fare = record(.fare, created: date(2026, 10, 22))
        #expect(CheckIn.question(for: fare, now: now, calendar: rome) == "Fermo da 4 giorni senza aggiornamenti. Ci sono novità?")
        let attesa = record(.attesa, created: date(2026, 10, 23), people: "Simo, Clark")
        #expect(CheckIn.question(for: attesa, now: now, calendar: rome)
                == "Aspetti una risposta da 3 giorni. È il caso di fare un ping a Simo e Clark?")
        let anonima = record(.attesa, created: date(2026, 10, 23))
        #expect(CheckIn.question(for: anonima, now: now, calendar: rome).hasSuffix("fare un ping al cliente o al dev?"))
    }

    @Test func aggiornamentoInTestaAllaNota() {
        let now = date(2026, 10, 26, 10)
        #expect(CheckIn.noteWithUpdate("", update: " risposto ", now: now, calendar: rome) == "26/10: risposto")
        #expect(CheckIn.noteWithUpdate("vecchia", update: "nuova", now: now, calendar: rome) == "26/10: nuova\nvecchia")
        #expect(CheckIn.noteWithUpdate("vecchia", update: "  ", now: now, calendar: rome) == "vecchia")
        let long = String(repeating: "x", count: 600)
        let result = CheckIn.noteWithUpdate(long, update: "nuova", now: now, calendar: rome)
        #expect(result.count == 600 && result.hasPrefix("26/10: nuova"))
    }

    @Test func elencoNomi() {
        #expect(italianList(["Paolo"]) == "Paolo")
        #expect(italianList(["Simo", "Clark"]) == "Simo e Clark")
        #expect(italianList(["Axel", "Seb", "Simo"]) == "Axel, Seb e Simo")
    }
}
