import Foundation
import SwiftData

/// Tutte le modifiche ai punti passano da qui, così ognuna registra la propria operazione inversa per l'undo.
@MainActor
final class ItemStore {
    let context: ModelContext
    /// Undo manager della finestra principale (lo imposta la finestra quando compare).
    var undoManager: UndoManager?
    /// Chiamato dopo ogni modifica salvata (per esempio per ripianificare le notifiche).
    var onChange: (() -> Void)?

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Lettura

    func item(id: UUID) -> PendingItem? {
        var descriptor = FetchDescriptor<PendingItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func allItems() -> [PendingItem] {
        (try? context.fetch(FetchDescriptor<PendingItem>())) ?? []
    }

    func allRecords() -> [ItemRecord] {
        allItems().map(ItemRecord.init)
    }

    // MARK: Modifiche annullabili

    func insert(_ record: ItemRecord, actionName: String = "Aggiungi punto") {
        context.insert(PendingItem(record: record))
        save()
        registerUndo(actionName) { $0.delete(id: record.id, actionName: actionName) }
    }

    /// Sostituisce tutti i campi del punto con lo stesso id.
    func update(_ record: ItemRecord, actionName: String = "Modifica punto") {
        guard let item = item(id: record.id) else { return }
        let old = ItemRecord(item)
        guard old != record else { return }
        item.apply(record)
        save()
        registerUndo(actionName) { $0.update(old, actionName: actionName) }
    }

    func setDone(id: UUID, _ done: Bool, now: Date = .nowMillis) {
        guard let item = item(id: id), item.isDone != done else { return }
        var record = ItemRecord(item)
        record.isDone = done
        record.doneAt = done ? now : nil
        if !done {
            // Riaprire un punto conta come aggiornamento: riparte il conteggio dei giorni fermi.
            record.lastActivityAt = now
            record.nextCheckAt = nil
        }
        update(record, actionName: done ? "Chiudi punto" : "Riapri punto")
    }

    func toggleDone(id: UUID, now: Date = .nowMillis) {
        guard let item = item(id: id) else { return }
        setDone(id: id, !item.isDone, now: now)
    }

    func move(id: UUID, to kind: Kind) {
        guard let item = item(id: id), item.kind != kind else { return }
        var record = ItemRecord(item)
        record.kind = kind
        update(record, actionName: "Sposta punto")
    }

    /// Risposta al riquadro degli aggiornamenti: aggiunge l'eventuale testo in testa alla nota,
    /// registra l'attività se c'è stata e fissa quando richiedere del punto.
    func recordCheckIn(
        id: UUID,
        update text: String = "",
        activity: Bool,
        moveTo kind: Kind? = nil,
        nextCheckAt: Date?,
        now: Date = .nowMillis
    ) {
        guard let item = item(id: id) else { return }
        var record = ItemRecord(item)
        record.note = CheckIn.noteWithUpdate(record.note, update: text, now: now)
        if activity || record.note != item.note {
            record.lastActivityAt = now
        }
        if let kind { record.kind = kind }
        record.nextCheckAt = nextCheckAt
        update(record, actionName: "Aggiorna punto")
    }

    /// "Più tardi" sul riquadro: rimanda i punti indicati senza registrare attività. Non annullabile.
    func postponeCheckIn(ids: [UUID], until date: Date) {
        for id in ids {
            item(id: id)?.nextCheckAt = date
        }
        save()
    }

    func delete(id: UUID, actionName: String = "Elimina punto") {
        guard let item = item(id: id) else { return }
        let snapshot = ItemRecord(item)
        context.delete(item)
        save()
        registerUndo(actionName) { $0.insert(snapshot, actionName: actionName) }
    }

    // MARK: Seed, migrazione e import

    /// I punti "coordinare" delle versioni precedenti diventano "fare".
    func migrateLegacyKinds() {
        let legacy = "coordinare"
        let descriptor = FetchDescriptor<PendingItem>(predicate: #Predicate { $0.kindRaw == legacy })
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        for item in items {
            item.kind = .fare
        }
        save()
    }

    /// Inserisce i punti iniziali solo al primo avvio e solo se il database è vuoto.
    func seedIfNeeded(defaults: UserDefaults = .standard) {
        let key = "didSeed"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        let count = (try? context.fetchCount(FetchDescriptor<PendingItem>())) ?? 0
        guard count == 0 else { return }
        for record in SeedData.records {
            context.insert(PendingItem(record: record))
        }
        save()
    }

    /// Merge per id: aggiorna i punti esistenti e inserisce i nuovi. Non annullabile.
    @discardableResult
    func merge(_ records: [ItemRecord]) -> (inserted: Int, updated: Int) {
        var inserted = 0, updated = 0
        for record in records {
            if let existing = item(id: record.id) {
                if ItemRecord(existing) != record {
                    existing.apply(record)
                    updated += 1
                }
            } else {
                context.insert(PendingItem(record: record))
                inserted += 1
            }
        }
        save()
        undoManager?.removeAllActions()
        return (inserted, updated)
    }

    // MARK: Interni

    private func save() {
        try? context.save()
        onChange?()
    }

    private func registerUndo(_ name: String, _ action: @escaping @MainActor @Sendable (ItemStore) -> Void) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated { action(store) }
        }
        undoManager.setActionName(name)
    }
}
