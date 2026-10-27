import Foundation
import Testing
@testable import AspettaCosaDovevoFare

let rome: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Rome")!
    return c
}()

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    rome.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func record(_ kind: Kind, created: Date, title: String = "Punto", project: String = "", people: String = "",
            note: String = "", done: Bool = false, doneAt: Date? = nil) -> ItemRecord {
    ItemRecord(title: title, kind: kind, project: project, people: people, note: note,
               isDone: done, createdAt: created, doneAt: doneAt)
}

@Suite("Età e staleness")
struct AgeTests {
    @Test func stessoGiornoEZero() {
        let item = record(.fare, created: date(2026, 10, 26, 9))
        #expect(ageInDays(item, now: date(2026, 10, 26, 23, 59), calendar: rome) == 0)
    }

    @Test func contaGiorniDiCalendarioNonOre() {
        let item = record(.fare, created: date(2026, 10, 25, 23, 30))
        #expect(ageInDays(item, now: date(2026, 10, 26, 0, 10), calendar: rome) == 1)
    }

    @Test func attraversaIlCambioOra() {
        // In Italia l'ora legale finisce il 25 ottobre 2026.
        let item = record(.fare, created: date(2026, 10, 24, 12))
        #expect(ageInDays(item, now: date(2026, 10, 27, 12), calendar: rome) == 3)
    }

    @Test func maiNegativa() {
        let item = record(.fare, created: date(2026, 10, 28))
        #expect(ageInDays(item, now: date(2026, 10, 26), calendar: rome) == 0)
    }

    @Test(arguments: [(Kind.attesa, 2, false), (.attesa, 3, true), (.fare, 4, false), (.fare, 5, true)])
    func soglieDefault(kind: Kind, days: Int, expected: Bool) {
        let now = date(2026, 10, 26)
        let item = record(kind, created: rome.date(byAdding: .day, value: -days, to: now)!)
        #expect(isStale(item, now: now, calendar: rome) == expected)
    }

    @Test func chiusoNonEMaiFermo() {
        let item = record(.attesa, created: date(2026, 9, 1), done: true, doneAt: date(2026, 9, 2))
        #expect(!isStale(item, now: date(2026, 10, 26), calendar: rome))
    }

    @Test func soglieModificabili() {
        let item = record(.attesa, created: date(2026, 10, 25))
        let thresholds = StaleThresholds(waiting: 1, doing: 2)
        #expect(isStale(item, now: date(2026, 10, 26), thresholds: thresholds, calendar: rome))
    }

    @Test func etichetteEta() {
        #expect(ageLabel(days: 0) == "aperto oggi")
        #expect(ageLabel(days: 1) == "da 1 giorno")
        #expect(ageLabel(days: 2) == "da 2 giorni")
        #expect(ageLabel(days: 31) == "da 31 giorni")
    }

    @Test func dataInItaliano() {
        #expect(italianDayLabel(date(2026, 10, 26), calendar: rome) == "lunedì 26 ottobre")
    }
}

@Suite("Ordinamento")
struct SortTests {
    @Test func apertiPrimaIPiuVecchi() {
        let a = record(.fare, created: date(2026, 10, 20), title: "A")
        let b = record(.fare, created: date(2026, 10, 10), title: "B")
        let c = record(.fare, created: date(2026, 10, 15), title: "C")
        #expect(sortedOpen([a, b, c]).map(\.title) == ["B", "C", "A"])
    }

    @Test func aParitaDiDataPerTitolo() {
        let d = date(2026, 10, 20)
        let items = [record(.fare, created: d, title: "zeta"), record(.fare, created: d, title: "Alfa")]
        #expect(sortedOpen(items).map(\.title) == ["Alfa", "zeta"])
    }

    @Test func chiusiPerDataDiChiusuraDecrescente() {
        let a = record(.fare, created: date(2026, 10, 1), title: "A", done: true, doneAt: date(2026, 10, 3))
        let b = record(.fare, created: date(2026, 10, 1), title: "B", done: true, doneAt: date(2026, 10, 5))
        #expect(sortedClosed([a, b]).map(\.title) == ["B", "A"])
    }
}

@Suite("Persone, progetti, filtri")
struct FilterTests {
    let items = [
        record(.fare, created: date(2026, 10, 1), title: "Sentire Fabio per Maia Canada", project: "Maia", people: "Fabio"),
        record(.attesa, created: date(2026, 10, 1), title: "Guardrail", project: "Maia", people: "Simo, Clark", note: "stima di fattibilità"),
        record(.fare, created: date(2026, 10, 1), title: "ASM", project: "ASM", people: "Simo, Fabio"),
        record(.fare, created: date(2026, 10, 1), title: "Chiuso", project: "ASM", people: "Fabio", done: true, doneAt: date(2026, 10, 2)),
    ]

    @Test func parsingPersone() {
        #expect(parsePeople(" Simo,  Fabio ,,simo, ") == ["Simo", "Fabio"])
        #expect(parsePeople("") == [])
    }

    @Test func conteggiProgettiEPersone() {
        #expect(projectCounts(items) == [NamedCount(name: "ASM", openCount: 1), NamedCount(name: "Maia", openCount: 2)])
        #expect(peopleCounts(items).map(\.name) == ["Clark", "Fabio", "Simo"])
        #expect(peopleCounts(items).first { $0.name == "Fabio" }?.openCount == 2)
    }

    @Test func filtroPersona() {
        let result = applyFilter(items, ItemFilter(person: "fabio"))
        #expect(result.map(\.title) == ["Sentire Fabio per Maia Canada", "ASM", "Chiuso"])
    }

    @Test func progettoPersonaERicercaSiCombinano() {
        #expect(applyFilter(items, ItemFilter(project: "Maia", person: "Simo")).map(\.title) == ["Guardrail"])
        #expect(applyFilter(items, ItemFilter(project: "Maia", query: "FATTIBILITA")).map(\.title) == ["Guardrail"])
        #expect(applyFilter(items, ItemFilter(person: "Fabio", query: "maia canada")).count == 1)
        #expect(applyFilter(items, ItemFilter(project: "ASM", person: "Clark")).isEmpty)
    }

    @Test func vistaChiusi() {
        #expect(applyFilter(items, ItemFilter(scope: .closed)).map(\.title) == ["Chiuso"])
    }

    @Test func scopeDellaSidebar() {
        #expect(ItemFilter(scope: .project("Maia")).scope == .project("Maia"))
        #expect(ItemFilter(project: "Maia", person: "Simo").scope == nil)
    }

    @Test func riepilogo() {
        let now = date(2026, 10, 26)
        let s = summarize(items, now: now, calendar: rome)
        #expect(s == ItemSummary(fare: 2, attesa: 1, stale: 3, staleAttesa: 1))
        #expect(dailyNotificationBody(s) == "2 cose toccano a te, 1 attesa da sollecitare")
        #expect(dailyNotificationBody(ItemSummary(fare: 3, staleAttesa: 2)) == "3 cose toccano a te, 2 attese da sollecitare")
        #expect(dailyNotificationBody(ItemSummary()) == nil)
    }
}

@Suite("Link e sollecito")
struct ReminderTests {
    @Test func linkValidi() {
        #expect(validatedLink(" https://upkeep.beatdata.it/cards/x ") != nil)
        #expect(validatedLink("http://example.com") != nil)
        #expect(validatedLink("ftp://example.com") == nil)
        #expect(validatedLink("javascript:alert(1)") == nil)
        #expect(validatedLink("") == nil)
    }

    @Test func etichettaLink() {
        #expect(linkLabel(for: URL(string: "https://upkeep.beatdata.it/cards/a")!) == "Apri su Upkeep")
        #expect(linkLabel(for: URL(string: "https://example.com")!) == "Apri link")
    }

    @Test func sollecitoEsempioDelleSpecifiche() {
        let item = record(.attesa, created: .now, title: "Risposta di Paolo sul deploy Telethon Financial", people: "Paolo")
        #expect(reminderText(for: item) == "Ciao Paolo, ti scrivo per il deploy Telethon Financial: hai novità?")
    }

    @Test func sollecitoConPreposizioneAlla() {
        let item = record(.attesa, created: .now, title: "Risposta di Seb alla domanda sulla webapp", people: "Seb")
        #expect(reminderText(for: item) == "Ciao Seb, ti scrivo per la domanda sulla webapp: hai novità?")
    }

    @Test func sollecitoGenericoUsaPrimoNome() {
        let item = record(.attesa, created: .now, title: "Sviluppo MFA di Axel", people: "Axel, Seb")
        #expect(reminderText(for: item) == "Ciao Axel, ti scrivo per «Sviluppo MFA di Axel»: hai novità?")
    }

    @Test func sollecitoSenzaPersone() {
        let item = record(.attesa, created: .now, title: "Documento test")
        #expect(reminderText(for: item) == "Ciao, ti scrivo per «Documento test»: hai novità?")
    }
}

@Suite("Seed")
struct SeedTests {
    @Test func trediciPuntiDivisiNeiDueGruppi() {
        let s = summarize(SeedData.records, now: SeedData.createdAt)
        #expect(SeedData.records.count == 13)
        #expect((s.fare, s.attesa) == (8, 5))
        #expect(Set(SeedData.records.map(\.id)).count == 13)
    }
}
