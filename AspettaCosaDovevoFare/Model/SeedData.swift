import Foundation

/// Punti inseriti al primo avvio, se il database è vuoto.
enum SeedData {
    static let createdAt = Date(millisecondsSince1970: 1_793_034_000_000)

    static var records: [ItemRecord] {
        func item(_ kind: Kind, _ title: String, _ project: String, people: String = "", link: String? = nil, note: String = "") -> ItemRecord {
            ItemRecord(
                title: title, kind: kind, project: project, people: people,
                link: link.flatMap(URL.init(string:)), note: note, createdAt: createdAt
            )
        }
        return [
            item(.fare, "Aggiungere Ryze su Upkeep", "Upkeep"),
            item(.fare, "Completare la review del corso Wins", "Corso Wins"),
            item(.fare, "115015: confermare o contestare la stima di Clark", "115015", people: "Clark",
                 link: "https://upkeep.beatdata.it/cards/su2nwmcexkra",
                 note: "Nel thread arriverà il tag con la risposta."),
            item(.fare, "Sentire Fabio per Maia Canada", "Maia", people: "Fabio"),
            item(.fare, "Maia Spagna: capire con Fabio chi risponde alla mail", "Maia", people: "Fabio",
                 note: "La mail è già stata inviata."),
            item(.fare, "ASM: coordinare l'analisi delle vulnerabilità", "ASM", people: "Simo, Fabio",
                 note: "Simo è già informato; va allineato con Fabio e con gli altri team coinvolti."),
            item(.fare, "Chiedere a Seb le risposte su budget e forecast", "MFA", people: "Seb",
                 note: "Domande fatte durante la call con Ciro."),
            item(.fare, "Gestire con Fabio le US che Simo stressa", "US", people: "Simo, Fabio",
                 note: "Simo ti tagga man mano: ricorrente."),
            item(.attesa, "Risposta di Paolo sul deploy Telethon Financial", "Telethon Financial", people: "Paolo"),
            item(.attesa, "Risposta di Seb alla domanda sulla webapp", "Webapp", people: "Seb"),
            item(.attesa, "Documento di Simo per i test della webapp", "Webapp", people: "Simo"),
            item(.attesa, "Sviluppo MFA di Axel, poi chiedere a Seb come e quando testarlo", "MFA", people: "Axel, Seb"),
            item(.attesa, "Maia Guardrail: stima di fattibilità di Simo e Clark", "Maia", people: "Simo, Clark",
                 link: "https://upkeep.beatdata.it/cards/c3tqzvwpo7rc",
                 note: "Card aperta su Upkeep perché mancava e rischiava di essere dimenticata."),
        ]
    }
}
