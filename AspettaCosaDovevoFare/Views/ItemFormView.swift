import SwiftData
import SwiftUI

/// Form di aggiunta e modifica di un punto (stesso form per entrambe).
struct ItemFormView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [PendingItem]

    /// nil = nuovo punto.
    let itemID: UUID?

    @State private var title = ""
    @State private var kind: Kind = .fare
    @State private var project = ""
    @State private var people = ""
    @State private var link = ""
    @State private var note = ""
    @State private var original: ItemRecord?
    @FocusState private var focused: Field?

    private enum Field { case title, project, people, link, note }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var linkIsValid: Bool { link.trimmingCharacters(in: .whitespaces).isEmpty || validatedLink(link) != nil }
    private var canSave: Bool { !trimmedTitle.isEmpty && linkIsValid }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(itemID == nil ? "Aggiungi punto" : "Modifica punto")
                .font(.title3.weight(.semibold))
                .padding([.horizontal, .top], 20)
                .padding(.bottom, 8)

            Form {
                TextField("Cosa", text: $title, prompt: Text("Obbligatorio"))
                    .focused($focused, equals: .title)
                    .onChange(of: title) { _, new in
                        if new.count > PendingItem.titleLimit { title = String(new.prefix(PendingItem.titleLimit)) }
                    }

                Picker("Chi deve muoversi", selection: $kind) {
                    ForEach(Kind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbolName).tag(kind)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Progetto", text: $project, prompt: Text("Facoltativo"))
                        .focused($focused, equals: .project)
                    SuggestionRow(suggestions: projectSuggestions) { project = $0 }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Persone", text: $people, prompt: Text("Nomi separati da virgola"))
                        .focused($focused, equals: .people)
                    SuggestionRow(suggestions: peopleSuggestions) { name in
                        var names = parsePeople(people)
                        if !people.trimmingCharacters(in: .whitespaces).hasSuffix(","), !names.isEmpty {
                            names.removeLast()
                        }
                        names.append(name)
                        people = names.joined(separator: ", ")
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    TextField("Link", text: $link, prompt: Text("https://…"))
                        .focused($focused, equals: .link)
                    if !linkIsValid {
                        Text("Serve un indirizzo completo http o https.")
                            .font(.caption)
                            .foregroundStyle(Color.stale)
                    }
                }

                VStack(alignment: .trailing, spacing: 2) {
                    TextField("Nota", text: $note, prompt: Text("Facoltativa"), axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused, equals: .note)
                        .onChange(of: note) { _, new in
                            if new.count > PendingItem.noteLimit { note = String(new.prefix(PendingItem.noteLimit)) }
                        }
                    Text("\(note.count)/\(PendingItem.noteLimit)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("\(note.count) caratteri su \(PendingItem.noteLimit)")
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Annulla", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salva") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding([.horizontal, .bottom], 20)
            .padding(.top, 4)
        }
        .frame(width: 480)
        .onAppear(perform: load)
    }

    // MARK: Suggerimenti

    private var projectSuggestions: [String] {
        let typed = normalizedProject(project)
        return projectCounts(allItems).map(\.name)
            .filter { typed.isEmpty || ($0.localizedCaseInsensitiveContains(typed) && $0.caseInsensitiveCompare(typed) != .orderedSame) }
            .prefix(8).map { $0 }
    }

    private var peopleSuggestions: [String] {
        let names = parsePeople(people)
        let endsWithComma = people.trimmingCharacters(in: .whitespaces).hasSuffix(",")
        let fragment = endsWithComma ? "" : (names.last ?? "")
        let chosen = Set((endsWithComma ? names : names.dropLast()).map { $0.lowercased() })
        return peopleCounts(allItems).map(\.name)
            .filter { !chosen.contains($0.lowercased()) }
            .filter { fragment.isEmpty || ($0.localizedCaseInsensitiveContains(fragment) && $0.caseInsensitiveCompare(fragment) != .orderedSame) }
            .prefix(8).map { $0 }
    }

    // MARK: Caricamento e salvataggio

    private func load() {
        if let itemID, let item = model.store.item(id: itemID) {
            let record = ItemRecord(item)
            original = record
            title = record.title
            kind = record.kind
            project = record.project
            people = record.people
            link = record.link?.absoluteString ?? ""
            note = record.note
        } else if case .project(let p) = model.filter.scope {
            project = p
        } else if case .person(let p) = model.filter.scope {
            people = p
        }
        focused = .title
    }

    private func save() {
        guard canSave else { return }
        var record = original ?? ItemRecord(title: "", kind: kind)
        record.title = trimmedTitle
        record.kind = kind
        record.project = normalizedProject(project)
        record.people = parsePeople(people).joined(separator: ", ")
        record.link = validatedLink(link)
        record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let original, record != original {
            // Una modifica è un aggiornamento: il punto smette di essere fermo.
            record.lastActivityAt = .nowMillis
            record.nextCheckAt = nil
        }
        if original == nil {
            model.store.insert(record)
            model.selection = record.id
        } else {
            model.store.update(record)
        }
        dismiss()
    }
}

/// Riga di suggerimenti cliccabili sotto un campo.
private struct SuggestionRow: View {
    let suggestions: [String]
    let pick: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { pick(suggestion) }
                            .buttonStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(.quaternary, in: Capsule())
                            .accessibilityLabel("Usa \(suggestion)")
                    }
                }
            }
        }
    }
}
