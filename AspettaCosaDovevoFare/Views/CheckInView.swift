import SwiftData
import SwiftUI

/// Riquadro che, per un punto fermo alla volta, chiede se ci sono aggiornamenti
/// o, per i punti in attesa, se è il caso di fare un ping.
struct CheckInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \PendingItem.createdAt) private var items: [PendingItem]
    @AppStorage(PrefKey.checkInDays) private var checkInDays = PrefDefault.checkInDays

    @State private var update = ""
    @State private var interval: AskAgainInterval = .threeDays
    @FocusState private var updateFocused: Bool

    var body: some View {
        let due = CheckIn.dueItems(items, now: model.now, days: checkInDays)
        Group {
            if let item = due.first {
                content(item, remaining: due.count)
            }
        }
        .frame(width: 520)
        .onAppear {
            if due.isEmpty { dismiss() }
        }
        .onChange(of: due.first?.id) { _, newID in
            update = ""
            if newID == nil { dismiss() }
        }
        .onDisappear(perform: postponeRemaining)
    }

    // MARK: Contenuto

    private func content(_ item: PendingItem, remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(item.kind == .attesa ? "Serve un ping?" : "Ci sono aggiornamenti?",
                      systemImage: item.kind == .attesa ? "bell.badge" : "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if remaining > 1 {
                    Text("ancora \(remaining) da rivedere")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            itemCard(item)

            Text(CheckIn.question(for: item, now: model.now))
                .fixedSize(horizontal: false, vertical: true)

            if item.kind == .attesa {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sollecito pronto da incollare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(reminderText(for: item))
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Form {
                TextField("Aggiornamento", text: $update, prompt: Text("Facoltativo: cosa è cambiato"), axis: .vertical)
                    .lineLimit(1...3)
                    .focused($updateFocused)
                Picker("Richiedimelo tra", selection: $interval) {
                    ForEach(AskAgainInterval.allCases) { Text($0.label).tag($0) }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, -20)

            buttons(item)
        }
        .padding(20)
    }

    private func itemCard(_ item: PendingItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(item.kind.color).frame(width: 7, height: 7).accessibilityHidden(true)
                Text(item.kind.title)
                let project = normalizedProject(item.project)
                if !project.isEmpty { Text("· \(project)") }
                if !item.people.isEmpty { Text("· \(item.people)") }
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            Text(item.title).font(.headline)
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let link = item.link {
                Button(linkLabel(for: link)) { openURL(link) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule().fill(item.kind.color).frame(width: 3).padding(.vertical, 6).accessibilityHidden(true)
        }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func buttons(_ item: PendingItem) -> some View {
        HStack {
            Button("Chiudi il punto") { close(item) }
                .help("Il punto è risolto: lo sposta tra i chiusi")
            if item.kind == .attesa {
                Button("Ora tocca a me") { answer(item, activity: true, moveTo: .fare, askAgain: false) }
                    .help("La risposta è arrivata: sposta il punto in Tocca a me")
            }
            Spacer()
            Button("Più tardi") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .help("Richiede fra un'ora (sempre tra le 9 e le 18)")
            if item.kind == .attesa {
                Button("Non serve") { answer(item, activity: false) }
                    .help("Niente ping per ora: richiede dopo l'intervallo scelto")
                Button("Copia sollecito") { ping(item) }
                    .keyboardShortcut(.defaultAction)
                    .help("Copia il testo del sollecito e registra il ping")
            } else {
                Button("Nessuna novità") { answer(item, activity: false) }
                    .help("Richiede dopo l'intervallo scelto; il punto resta fermo")
                Button("Aggiornato") { answer(item, activity: true) }
                    .keyboardShortcut(.defaultAction)
                    .help("Registra l'aggiornamento e riparte il conteggio dei giorni")
            }
        }
    }

    // MARK: Azioni

    private func answer(_ item: PendingItem, activity: Bool, moveTo kind: Kind? = nil, askAgain: Bool = true, note: String? = nil) {
        let now = Date.nowMillis
        model.store.recordCheckIn(
            id: item.id,
            update: note ?? update,
            activity: activity,
            moveTo: kind,
            nextCheckAt: askAgain ? CheckIn.askAgainDate(inDays: interval.rawValue, from: now) : nil,
            now: now
        )
    }

    private func ping(_ item: PendingItem) {
        model.copyReminder(item.id)
        let people = parsePeople(item.people)
        var line = people.isEmpty ? "ping inviato" : "ping a \(italianList(people))"
        let extra = update.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { line += " – \(extra)" }
        answer(item, activity: true, note: line)
    }

    private func close(_ item: PendingItem) {
        if !update.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answer(item, activity: true, askAgain: false)
        }
        model.store.setDone(id: item.id, true)
    }

    /// Chiudere il riquadro senza rispondere equivale a "Più tardi" per i punti rimasti.
    private func postponeRemaining() {
        let now = Date()
        let ids = CheckIn.dueItems(items, now: now, days: checkInDays).map(\.id)
        guard !ids.isEmpty else { return }
        model.store.postponeCheckIn(ids: ids, until: CheckIn.laterDate(from: now))
    }
}
