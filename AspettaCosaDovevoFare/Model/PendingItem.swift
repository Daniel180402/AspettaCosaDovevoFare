import Foundation
import SwiftData

/// Campi comuni al modello persistito e alle sue copie per valore,
/// così la logica di dominio funziona su entrambi.
protocol ItemFields {
    var id: UUID { get }
    var title: String { get }
    var kind: Kind { get }
    var project: String { get }
    var people: String { get }
    var link: URL? { get }
    var note: String { get }
    var isDone: Bool { get }
    var createdAt: Date { get }
    var doneAt: Date? { get }
    /// Ultimo aggiornamento registrato (modifica, risposta al riquadro, sollecito); nil = mai, vale `createdAt`.
    var lastActivityAt: Date? { get }
    /// Prima di questa data il riquadro degli aggiornamenti non chiede di nuovo del punto.
    var nextCheckAt: Date? { get }
}

@Model
final class PendingItem {
    static let titleLimit = 200
    static let noteLimit = 600

    @Attribute(.unique) var id: UUID
    var title: String
    /// Valore grezzo di `Kind`: SwiftData su macOS 14 gestisce meglio le stringhe degli enum.
    var kindRaw: String
    var project: String
    var people: String
    var link: URL?
    var note: String
    var isDone: Bool
    var createdAt: Date
    var doneAt: Date?
    var lastActivityAt: Date?
    var nextCheckAt: Date?

    var kind: Kind {
        get { Kind(storedValue: kindRaw) ?? .fare }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        kind: Kind,
        project: String = "",
        people: String = "",
        link: URL? = nil,
        note: String = "",
        isDone: Bool = false,
        createdAt: Date = .nowMillis,
        doneAt: Date? = nil,
        lastActivityAt: Date? = nil,
        nextCheckAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.project = project
        self.people = people
        self.link = link
        self.note = note
        self.isDone = isDone
        self.createdAt = createdAt
        self.doneAt = doneAt
        self.lastActivityAt = lastActivityAt
        self.nextCheckAt = nextCheckAt
    }
}

extension PendingItem: ItemFields {}

extension Date {
    /// Data corrente troncata al millisecondo, così export e import JSON restituiscono la stessa data.
    static var nowMillis: Date { Date(millisecondsSince1970: Date().millisecondsSince1970) }

    init(millisecondsSince1970 ms: Int64) {
        self.init(timeIntervalSince1970: Double(ms) / 1000)
    }

    var millisecondsSince1970: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
