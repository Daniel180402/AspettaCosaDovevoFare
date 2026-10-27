import Foundation

/// Testo breve e cortese da incollare in chat per sollecitare il primo nome in `people`.
///
/// Se il titolo ha la forma "Risposta di <Nome> sul/alla …", toglie la parte ridondante
/// e trasforma la preposizione articolata in articolo:
/// "Risposta di Paolo sul deploy X" → "Ciao Paolo, ti scrivo per il deploy X: hai novità?".
/// Negli altri casi cita il titolo tra virgolette.
func reminderText(for item: some ItemFields) -> String {
    let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let name = parsePeople(item.people).first else {
        return "Ciao, ti scrivo per «\(title)»: hai novità?"
    }
    if let topic = topicAfterReplyPrefix(title: title, name: name) {
        return "Ciao \(name), ti scrivo per \(topic): hai novità?"
    }
    return "Ciao \(name), ti scrivo per «\(title)»: hai novità?"
}

private let articulatedPrepositions: [(String, String)] = [
    ("sull'", "l'"), ("sullo ", "lo "), ("sulla ", "la "), ("sulle ", "le "), ("sugli ", "gli "), ("sui ", "i "), ("sul ", "il "),
    ("all'", "l'"), ("allo ", "lo "), ("alla ", "la "), ("alle ", "le "), ("agli ", "gli "), ("ai ", "i "), ("al ", "il "),
]

private func topicAfterReplyPrefix(title: String, name: String) -> String? {
    let prefix = "Risposta di \(name) "
    guard title.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil else { return nil }
    let rest = String(title.dropFirst(prefix.count))
    for (preposition, article) in articulatedPrepositions
    where rest.range(of: preposition, options: [.anchored, .caseInsensitive]) != nil {
        let topic = article + rest.dropFirst(preposition.count)
        return topic.trimmingCharacters(in: .whitespaces).isEmpty ? nil : topic
    }
    return nil
}
