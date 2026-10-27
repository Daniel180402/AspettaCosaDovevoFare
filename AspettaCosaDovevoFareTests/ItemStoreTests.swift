import Foundation
import SwiftData
import Testing
@testable import AspettaCosaDovevoFare

@MainActor
@Suite("Store e undo")
struct ItemStoreTests {
    let container: ModelContainer
    let store: ItemStore
    let undo = UndoManager()

    init() throws {
        container = try ModelContainer(for: PendingItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = ItemStore(context: container.mainContext)
        undo.groupsByEvent = false
        store.undoManager = undo
    }

    private func step(_ action: () -> Void) {
        undo.beginUndoGrouping()
        action()
        undo.endUndoGrouping()
    }

    @Test func seedSoloSeVuotoEUnaVolta() throws {
        let defaults = try #require(UserDefaults(suiteName: "test-\(UUID())"))
        store.seedIfNeeded(defaults: defaults)
        #expect(store.allItems().count == 13)
        store.seedIfNeeded(defaults: defaults)
        #expect(store.allItems().count == 13)
    }

    @Test func chiusuraConUndoERedo() {
        let r = ItemRecord(title: "Punto", kind: .fare)
        step { store.insert(r) }
        let closedAt = Date(millisecondsSince1970: 1_800_000_000_000)
        step { store.toggleDone(id: r.id, now: closedAt) }
        #expect(store.item(id: r.id)?.isDone == true)
        #expect(store.item(id: r.id)?.doneAt == closedAt)
        #expect(undo.undoActionName == "Chiudi punto")

        undo.undo()
        #expect(store.item(id: r.id)?.isDone == false)
        #expect(store.item(id: r.id)?.doneAt == nil)
        undo.redo()
        #expect(store.item(id: r.id)?.isDone == true)
    }

    @Test func modificaESpostamentoAnnullabili() {
        let r = ItemRecord(title: "Prima", kind: .attesa)
        step { store.insert(r) }
        var edited = r
        edited.title = "Dopo"
        step { store.update(edited) }
        step { store.move(id: r.id, to: .fare) }
        #expect(store.item(id: r.id)?.kind == .fare)
        undo.undo()
        #expect(store.item(id: r.id)?.kind == .attesa)
        undo.undo()
        #expect(store.item(id: r.id)?.title == "Prima")
    }

    @Test func eliminazioneAnnullabileConStessoID() {
        let r = ItemRecord(title: "Da eliminare", kind: .fare, people: "Fabio", note: "nota")
        step { store.insert(r) }
        step { store.delete(id: r.id) }
        #expect(store.item(id: r.id) == nil)
        undo.undo()
        #expect(store.item(id: r.id).map(ItemRecord.init) == r)
        undo.redo()
        #expect(store.item(id: r.id) == nil)
    }

    @Test func mergePerID() {
        let a = ItemRecord(title: "A", kind: .fare)
        step { store.insert(a) }
        var changed = a
        changed.title = "A modificato"
        let b = ItemRecord(title: "B", kind: .attesa)
        let result = store.merge([changed, b])
        #expect(result.inserted == 1 && result.updated == 1)
        #expect(store.allItems().count == 2)
        #expect(store.item(id: a.id)?.title == "A modificato")
    }

    @Test func rispostaAlRiquadroAnnullabile() {
        let r = ItemRecord(title: "Attesa", kind: .attesa, note: "nota vecchia", createdAt: date(2026, 10, 20))
        step { store.insert(r) }
        let now = date(2026, 10, 26, 10)
        let next = date(2026, 10, 29, 9)
        step { store.recordCheckIn(id: r.id, update: "ping a Paolo", activity: true, nextCheckAt: next, now: now) }
        let item = store.item(id: r.id)
        #expect(item?.lastActivityAt == now)
        #expect(item?.nextCheckAt == next)
        #expect(item?.note.hasPrefix("26/10: ping a Paolo\n") == true)
        #expect(undo.undoActionName == "Aggiorna punto")
        undo.undo()
        #expect(store.item(id: r.id).map(ItemRecord.init) == r)
    }

    @Test func oraToccaAMeSpostaERegistraAttivita() {
        let r = ItemRecord(title: "Attesa", kind: .attesa, createdAt: date(2026, 10, 20))
        step { store.insert(r) }
        let now = date(2026, 10, 26, 10)
        step { store.recordCheckIn(id: r.id, activity: true, moveTo: .fare, nextCheckAt: nil, now: now) }
        #expect(store.item(id: r.id)?.kind == .fare)
        #expect(store.item(id: r.id)?.lastActivityAt == now)
        #expect(store.item(id: r.id)?.note == "")
    }

    @Test func nessunaNovitaNonRegistraAttivita() {
        let r = ItemRecord(title: "Fare", kind: .fare, createdAt: date(2026, 10, 20))
        step { store.insert(r) }
        step { store.recordCheckIn(id: r.id, activity: false, nextCheckAt: date(2026, 10, 27, 9), now: date(2026, 10, 26, 10)) }
        #expect(store.item(id: r.id)?.lastActivityAt == nil)
        #expect(store.item(id: r.id)?.nextCheckAt == date(2026, 10, 27, 9))
    }

    @Test func riaprireAzzeraIGiorniFermi() {
        let r = ItemRecord(title: "Fare", kind: .fare, isDone: true, createdAt: date(2026, 10, 1), doneAt: date(2026, 10, 2),
                           nextCheckAt: date(2026, 10, 3, 9))
        step { store.insert(r) }
        let now = date(2026, 10, 26, 10)
        step { store.setDone(id: r.id, false, now: now) }
        #expect(store.item(id: r.id)?.lastActivityAt == now)
        #expect(store.item(id: r.id)?.nextCheckAt == nil)
    }

    @Test func piuTardiRimandaSenzaAttivita() {
        let a = ItemRecord(title: "A", kind: .fare), b = ItemRecord(title: "B", kind: .attesa)
        step { store.insert(a); store.insert(b) }
        let later = date(2026, 10, 26, 11)
        store.postponeCheckIn(ids: [a.id, b.id], until: later)
        #expect(store.allItems().allSatisfy { $0.nextCheckAt == later && $0.lastActivityAt == nil })
    }

    @Test func migrazioneCoordinareInFare() {
        let legacy = PendingItem(title: "Vecchio", kind: .attesa)
        legacy.kindRaw = "coordinare"
        container.mainContext.insert(legacy)
        #expect(legacy.kind == .fare)
        store.migrateLegacyKinds()
        #expect(store.item(id: legacy.id)?.kindRaw == "fare")
    }
}
