# Aspetta cosa dovevo Fare?

Una piccola app per Mac nata da un problema molto concreto: a fine giornata avevo in testa una decina di cose rimaste a metà. Alcune toccavano a me, altre erano ferme perché aspettavo una risposta da un collega o da un cliente. Le prime le dimenticavo, le seconde le lasciavo morire senza sollecitare nessuno.

L'app tiene queste cose in un posto solo e ogni tanto me le ricorda.

![Icona](AspettaCosaDovevoFare/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

## Come funziona

Ogni punto ha un titolo, un progetto, le persone coinvolte, una nota e, se serve, un link (per esempio la card su Upkeep). E finisce in uno di due gruppi:

- Tocca a me: cose che devo chiudere io.
- Aspetto da altri: cose ferme finché qualcuno non risponde.

La finestra principale mostra i due gruppi con i punti più vecchi in alto. Dalla sidebar si filtra per progetto o per persona, e cliccando sulle etichette di una riga si possono combinare i due filtri. Quando un punto resta senza aggiornamenti troppo a lungo l'età diventa rossa e compare un numero accanto all'icona nella barra dei menu.

Se un punto è fermo da tre giorni, durante l'orario di lavoro (tra le 9 e le 18) l'app apre un riquadro e chiede come sta andando. Per le cose che toccano a me la domanda è semplice: ci sono novità? Per quelle in attesa propone di mandare un messaggio, e il testo è già pronto da incollare in chat, tipo "Ciao Paolo, ti scrivo per il deploy: hai novità?". Si può anche dire di richiederlo fra un giorno, una settimana o due.

C'è poi una notifica al mattino, di default alle 9 nei giorni feriali, che dice quante cose ci sono da fare e quante attese andrebbero sollecitate.

## Scorciatoie

| | |
|---|---|
| ⌘N | nuovo punto |
| ⌘E o doppio clic | modifica |
| Spazio | chiude o riapre il punto selezionato |
| ⌫ | elimina (chiede conferma nella riga) |
| ⇧⌘C | copia il testo del sollecito |
| ⌘Z | annulla, funziona su quasi tutto |

## Dati

Tutto resta sul Mac, in un database SwiftData dentro il container dell'app. Dalle Impostazioni si esporta e si importa un file JSON. L'import non cancella niente: i punti con lo stesso id vengono aggiornati, gli altri aggiunti. Il formato è questo:

```json
[
  {
    "id": "6F1C…",
    "title": "Risposta di Paolo sul deploy",
    "kind": "attesa",
    "project": "Telethon",
    "people": "Paolo",
    "link": null,
    "note": "",
    "done": false,
    "createdAt": 1793034000000,
    "doneAt": null,
    "lastActivityAt": null,
    "nextCheckAt": null
  }
]
```

`kind` vale `fare` oppure `attesa`, le date sono in millisecondi. Se l'id non è un UUID ne viene ricavato uno stabile, così reimportare lo stesso file non crea doppioni.

## Compilare

Serve un Mac con Apple Silicon, macOS 14 o successivo e Xcode 16. Non ci sono dipendenze esterne: si apre `AspettaCosaDovevoFare.xcodeproj` e si preme Run.

Da terminale:

```bash
xcodebuild -project AspettaCosaDovevoFare.xcodeproj -scheme AspettaCosaDovevoFare -destination 'platform=macOS,arch=arm64' build
```

I test usano Swift Testing e girano con lo stesso comando sostituendo `build` con `test`. Coprono la logica che conta davvero: calcolo dei giorni, soglie, filtri, testo dei solleciti, JSON, undo e il riquadro degli aggiornamenti. Se restano appesi senza dire niente, di solito è perché la Developer Mode del Mac è disattivata (`DevToolsSecurity -enable`).

L'icona è disegnata in codice. Per rigenerarla dopo aver cambiato colori o forme:

```bash
swift Support/MakeAppIcon.swift AspettaCosaDovevoFare/Assets.xcassets/AppIcon.appiconset
```

## Com'è organizzato il codice

- `Model`: il modello SwiftData e i punti iniziali del primo avvio.
- `Domain`: la logica pura, senza interfaccia, quella che viene testata.
- `Store`: tutte le modifiche passano da qui, così ognuna si può annullare.
- `Views` e `App`: interfaccia, menu, barra dei menu, impostazioni.

In `Domain/ItemSource.swift` c'è un protocollo pensato per il futuro: l'idea è collegare prima o poi Outlook e Teams, così un punto in attesa si accorge da solo quando arriva la risposta. Per ora esiste solo la versione locale.
