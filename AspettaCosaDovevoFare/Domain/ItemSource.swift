import Foundation

/// Segnale arrivato da una fonte esterna su un punto, per esempio una risposta a un punto in attesa.
struct ItemSignal: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case replyReceived
    }

    var itemID: UUID
    var kind: Kind
    var summary: String
    var receivedAt: Date
    var url: URL?
}

/// Fonte di punti e di segnali.
///
/// Oggi esiste solo la fonte locale (SwiftData). Più avanti un'implementazione basata su
/// Microsoft Graph (Outlook e Teams) potrà segnalare le risposte arrivate ai punti in attesa,
/// cercando per esempio i messaggi delle persone indicate in `people`.
@MainActor
protocol ItemSource {
    var name: String { get }
    /// Punti gestiti da questa fonte.
    func items() throws -> [ItemRecord]
    /// Novità sui punti indicati (per esempio risposte ricevute dopo `createdAt`).
    func signals(for items: [ItemRecord]) async throws -> [ItemSignal]
}

/// Fonte locale: i punti salvati nel database dell'app, nessun segnale esterno.
struct LocalItemSource: ItemSource {
    let store: ItemStore

    var name: String { "Locale" }

    func items() throws -> [ItemRecord] {
        store.allRecords()
    }

    func signals(for items: [ItemRecord]) async throws -> [ItemSignal] {
        []
    }
}
