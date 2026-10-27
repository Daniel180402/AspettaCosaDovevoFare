import Foundation

/// Chi deve muoversi su un punto aperto.
enum Kind: String, CaseIterable, Codable, Sendable, Identifiable {
    case fare
    case attesa

    var id: String { rawValue }

    /// Legge anche i valori salvati dalle versioni precedenti: "coordinare" è diventato "fare".
    init?(storedValue: String) {
        if storedValue == "coordinare" {
            self = .fare
        } else {
            self.init(rawValue: storedValue)
        }
    }

    /// Titolo della sezione nella finestra principale.
    var title: String {
        switch self {
        case .fare: "Tocca a me"
        case .attesa: "Aspetto da altri"
        }
    }

    /// Sottotitolo grigio della sezione.
    var subtitle: String {
        switch self {
        case .fare: "Da chiudere tu"
        case .attesa: "Da sollecitare se fermo"
        }
    }

    /// Etichetta dei contatori nella riga di riepilogo.
    var counterLabel: String {
        switch self {
        case .fare: "tocca a me"
        case .attesa: "aspetto da altri"
        }
    }

    var symbolName: String {
        switch self {
        case .fare: "person.fill"
        case .attesa: "hourglass"
        }
    }
}
