import CryptoKit
import Foundation

/// Formato JSON di import/export:
/// `[{"id","title","kind":"fare|attesa","project","people","link","note","done","createdAt","doneAt","lastActivityAt","nextCheckAt"}]`
/// con le date in millisecondi epoch. Le ultime due chiavi sono facoltative; "coordinare" dei file vecchi diventa "fare".
enum ItemsJSON {
    enum ParseError: LocalizedError, Equatable {
        case notAnArray
        case invalidItem(index: Int, reason: String)

        var errorDescription: String? {
            switch self {
            case .notAnArray:
                "Il file non contiene un elenco JSON di punti."
            case .invalidItem(let index, let reason):
                "Punto n. \(index + 1): \(reason)."
            }
        }
    }

    private struct Entry: Codable {
        var id: String
        var title: String
        var kind: String
        var project: String?
        var people: String?
        var link: String?
        var note: String?
        var done: Bool?
        var createdAt: Double?
        var doneAt: Double?
        var lastActivityAt: Double?
        var nextCheckAt: Double?

        enum CodingKeys: String, CodingKey {
            case id, title, kind, project, people, link, note, done, createdAt, doneAt, lastActivityAt, nextCheckAt
        }

        init(_ r: ItemRecord) {
            id = r.id.uuidString
            title = r.title
            kind = r.kind.rawValue
            project = r.project
            people = r.people
            link = r.link?.absoluteString
            note = r.note
            done = r.isDone
            createdAt = Double(r.createdAt.millisecondsSince1970)
            doneAt = r.doneAt.map { Double($0.millisecondsSince1970) }
            lastActivityAt = r.lastActivityAt.map { Double($0.millisecondsSince1970) }
            nextCheckAt = r.nextCheckAt.map { Double($0.millisecondsSince1970) }
        }

        /// Scrive sempre tutte le chiavi, anche quelle a null, e le date come interi.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            try c.encode(kind, forKey: .kind)
            try c.encode(project ?? "", forKey: .project)
            try c.encode(people ?? "", forKey: .people)
            try c.encode(link, forKey: .link)
            try c.encode(note ?? "", forKey: .note)
            try c.encode(done ?? false, forKey: .done)
            try c.encode(Int64(createdAt ?? 0), forKey: .createdAt)
            try c.encode(doneAt.map { Int64($0) }, forKey: .doneAt)
            try c.encode(lastActivityAt.map { Int64($0) }, forKey: .lastActivityAt)
            try c.encode(nextCheckAt.map { Int64($0) }, forKey: .nextCheckAt)
        }
    }

    static func encode(_ records: [ItemRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let sorted = records.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        return try encoder.encode(sorted.map(Entry.init))
    }

    /// Converte il JSON in record validi. `now` serve solo se manca `createdAt`.
    static func decode(_ data: Data, now: Date = .nowMillis) throws -> [ItemRecord] {
        let entries: [Entry]
        do {
            entries = try JSONDecoder().decode([Entry].self, from: data)
        } catch DecodingError.typeMismatch(_, let context) where context.codingPath.isEmpty {
            throw ParseError.notAnArray
        } catch DecodingError.dataCorrupted(let context) where context.codingPath.isEmpty {
            throw ParseError.notAnArray
        } catch let DecodingError.keyNotFound(key, context) {
            throw ParseError.invalidItem(index: context.codingPath.first?.intValue ?? 0, reason: "manca «\(key.stringValue)»")
        } catch let DecodingError.typeMismatch(_, context), let DecodingError.valueNotFound(_, context) {
            let index = context.codingPath.first?.intValue ?? 0
            let field = context.codingPath.dropFirst().first?.stringValue ?? "?"
            throw ParseError.invalidItem(index: index, reason: "valore non valido per «\(field)»")
        }

        return try entries.enumerated().map { index, e in
            let title = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw ParseError.invalidItem(index: index, reason: "il titolo è vuoto") }
            guard let kind = Kind(storedValue: e.kind) else {
                throw ParseError.invalidItem(index: index, reason: "«\(e.kind)» non è fare o attesa")
            }
            let rawID = e.id.trimmingCharacters(in: .whitespaces)
            guard !rawID.isEmpty else { throw ParseError.invalidItem(index: index, reason: "l'id è vuoto") }
            let done = e.done ?? false
            return ItemRecord(
                id: UUID(uuidString: rawID) ?? deterministicUUID(from: rawID),
                title: String(title.prefix(PendingItem.titleLimit)),
                kind: kind,
                project: normalizedProject(e.project ?? ""),
                people: e.people ?? "",
                link: e.link.flatMap(validatedLink),
                note: String((e.note ?? "").prefix(PendingItem.noteLimit)),
                isDone: done,
                createdAt: e.createdAt.map { Date(millisecondsSince1970: Int64($0)) } ?? now,
                doneAt: done ? e.doneAt.map { Date(millisecondsSince1970: Int64($0)) } : nil,
                lastActivityAt: e.lastActivityAt.map { Date(millisecondsSince1970: Int64($0)) },
                nextCheckAt: e.nextCheckAt.map { Date(millisecondsSince1970: Int64($0)) }
            )
        }
    }

    /// UUID versione 5 (SHA-1) ricavato in modo stabile da un id non UUID: reimportare lo stesso file aggiorna, non duplica.
    static func deterministicUUID(from string: String) -> UUID {
        // Namespace fisso dell'app.
        let namespace = UUID(uuidString: "6B1E8F2A-3C4D-4E5F-9A0B-1C2D3E4F5A6B")!
        var bytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        bytes.append(contentsOf: Array(string.utf8))
        var hash = Array(Insecure.SHA1.hash(data: bytes).prefix(16))
        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }
}
