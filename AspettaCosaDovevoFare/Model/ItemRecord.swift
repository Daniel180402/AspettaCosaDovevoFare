import Foundation

/// Copia per valore di un `PendingItem`: serve per undo, import/export, seed e notifiche.
struct ItemRecord: ItemFields, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var kind: Kind
    var project: String
    var people: String
    var link: URL?
    var note: String
    var isDone: Bool
    var createdAt: Date
    var doneAt: Date?
    var lastActivityAt: Date?
    var nextCheckAt: Date?

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
        self.kind = kind
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

    init(_ item: some ItemFields) {
        self.init(
            id: item.id, title: item.title, kind: item.kind, project: item.project,
            people: item.people, link: item.link, note: item.note, isDone: item.isDone,
            createdAt: item.createdAt, doneAt: item.doneAt,
            lastActivityAt: item.lastActivityAt, nextCheckAt: item.nextCheckAt
        )
    }
}

extension PendingItem {
    convenience init(record: ItemRecord) {
        self.init(
            id: record.id, title: record.title, kind: record.kind, project: record.project,
            people: record.people, link: record.link, note: record.note, isDone: record.isDone,
            createdAt: record.createdAt, doneAt: record.doneAt,
            lastActivityAt: record.lastActivityAt, nextCheckAt: record.nextCheckAt
        )
    }

    func apply(_ record: ItemRecord) {
        title = record.title
        kind = record.kind
        project = record.project
        people = record.people
        link = record.link
        note = record.note
        isDone = record.isDone
        createdAt = record.createdAt
        doneAt = record.doneAt
        lastActivityAt = record.lastActivityAt
        nextCheckAt = record.nextCheckAt
    }
}
