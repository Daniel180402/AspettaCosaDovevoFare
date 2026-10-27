import Foundation

/// Voce selezionabile nella sidebar.
enum SidebarScope: Hashable, Sendable {
    case all
    case closed
    case project(String)
    case person(String)
}

/// Filtro attivo sulla lista: progetto, persona e ricerca si combinano in AND.
struct ItemFilter: Equatable, Sendable {
    var project: String?
    var person: String?
    /// Vista "Chiusi": solo i punti chiusi.
    var closedOnly = false
    var query = ""

    init(project: String? = nil, person: String? = nil, closedOnly: Bool = false, query: String = "") {
        self.project = project
        self.person = person
        self.closedOnly = closedOnly
        self.query = query
    }

    /// Filtro corrispondente a una voce della sidebar; la ricerca resta quella attuale.
    init(scope: SidebarScope, query: String = "") {
        switch scope {
        case .all: self.init(query: query)
        case .closed: self.init(closedOnly: true, query: query)
        case .project(let p): self.init(project: p, query: query)
        case .person(let p): self.init(person: p, query: query)
        }
    }

    /// Voce della sidebar da evidenziare, o nil se il filtro combina progetto e persona.
    var scope: SidebarScope? {
        switch (project, person, closedOnly) {
        case (nil, nil, true): .closed
        case (nil, nil, false): .all
        case (let p?, nil, false): .project(p)
        case (nil, let p?, false): .person(p)
        default: nil
        }
    }

    func matches(_ item: some ItemFields) -> Bool {
        if closedOnly && !item.isDone { return false }
        if let project, normalizedProject(item.project).caseInsensitiveCompare(project) != .orderedSame {
            return false
        }
        if let person, !parsePeople(item.people).contains(where: { $0.caseInsensitiveCompare(person) == .orderedSame }) {
            return false
        }
        return matchesQuery(item, query)
    }
}

func normalizedProject(_ project: String) -> String {
    project.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Ricerca su titolo, nota, progetto e persone; ogni parola deve comparire (senza badare a maiuscole e accenti).
func matchesQuery(_ item: some ItemFields, _ query: String) -> Bool {
    let words = query.split(whereSeparator: \.isWhitespace)
    guard !words.isEmpty else { return true }
    let haystack = [item.title, item.note, item.project, item.people].joined(separator: " ")
    return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
}

func applyFilter<I: ItemFields>(_ items: [I], _ filter: ItemFilter) -> [I] {
    items.filter(filter.matches)
}

/// Nome visualizzato e numero di punti aperti, per la sidebar.
struct NamedCount: Equatable, Hashable, Sendable, Identifiable {
    var name: String
    var openCount: Int
    var id: String { name.lowercased() }
}

/// Progetti presenti nei dati, in ordine alfabetico, con il conteggio dei punti aperti.
func projectCounts(_ items: [some ItemFields]) -> [NamedCount] {
    groupedCounts(items) { item in
        let p = normalizedProject(item.project)
        return p.isEmpty ? [] : [p]
    }
}

/// Persone ricavate dal campo `people`, in ordine alfabetico, con il conteggio dei punti aperti.
func peopleCounts(_ items: [some ItemFields]) -> [NamedCount] {
    groupedCounts(items) { parsePeople($0.people) }
}

private func groupedCounts<I: ItemFields>(_ items: [I], names: (I) -> [String]) -> [NamedCount] {
    var byKey: [String: NamedCount] = [:]
    for item in items {
        for name in names(item) {
            let key = name.lowercased()
            var entry = byKey[key] ?? NamedCount(name: name, openCount: 0)
            if !item.isDone { entry.openCount += 1 }
            byKey[key] = entry
        }
    }
    return byKey.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
