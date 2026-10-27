import SwiftUI

struct ItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let item: PendingItem
    let now: Date
    let thresholds: StaleThresholds

    var body: some View {
        let stale = isStale(item, now: now, thresholds: thresholds)
        HStack(alignment: .top, spacing: 10) {
            Toggle(isOn: Binding(
                get: { item.isDone },
                set: { model.store.setDone(id: item.id, $0) }
            )) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel(item.isDone ? "Riapri «\(item.title)»" : "Chiudi «\(item.title)»")
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .fontWeight(.semibold)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                chips
                if model.pendingDeleteID == item.id {
                    DeleteConfirmation()
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                ageText(stale: stale)
                if let link = item.link {
                    Button(linkLabel(for: link)) { openURL(link) }
                        .buttonStyle(.link)
                        .font(.caption)
                        .help(link.absoluteString)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(item.kind.color.opacity(item.isDone ? 0.35 : 1))
                .frame(width: 3)
                .padding(.vertical, 3)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.kind.title): \(item.title)")
    }

    @ViewBuilder private var chips: some View {
        let project = normalizedProject(item.project)
        let people = parsePeople(item.people)
        if !project.isEmpty || !people.isEmpty {
            HStack(spacing: 4) {
                if !project.isEmpty {
                    Chip(text: project, systemImage: "folder",
                         isActive: model.filter.project?.caseInsensitiveCompare(project) == .orderedSame) {
                        model.refine(project: project)
                    }
                }
                ForEach(people, id: \.self) { person in
                    Chip(text: person, systemImage: "person",
                         isActive: model.filter.person?.caseInsensitiveCompare(person) == .orderedSame) {
                        model.refine(person: person)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder private func ageText(stale: Bool) -> some View {
        if item.isDone, let doneAt = item.doneAt {
            Text("chiuso il \(doneAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "it_IT"))))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text(ageLabel(days: ageInDays(item, now: now)))
                .font(.caption.weight(stale ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(stale ? Color.stale : .secondary)
                .accessibilityLabel(stale ? "\(ageLabel(days: ageInDays(item, now: now))), fermo" : ageLabel(days: ageInDays(item, now: now)))
        }
    }
}

/// Conferma di eliminazione inline, al posto di un alert.
struct DeleteConfirmation: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Text("Eliminare questo punto?")
                .font(.callout)
                .foregroundStyle(Color.stale)
            Button("Elimina", role: .destructive) { model.confirmDelete() }
                .keyboardShortcut(.defaultAction)
            Button("Annulla") { model.pendingDeleteID = nil }
        }
        .controlSize(.small)
        .padding(.top, 4)
    }
}

/// Voci del menu contestuale di una riga (usate anche dal menu "Punto").
struct ItemContextMenu: View {
    @Environment(AppModel.self) private var model
    let item: PendingItem

    var body: some View {
        Button(item.isDone ? "Riapri" : "Chiudi") { model.toggleDone(item.id) }
        Button("Modifica…") { model.edit(item.id) }
        Menu("Sposta in") {
            ForEach(Kind.allCases) { kind in
                Button(kind.title) { model.store.move(id: item.id, to: kind) }
                    .disabled(kind == item.kind)
            }
        }
        Button("Copia sollecito") { model.copyReminder(item.id) }
        Divider()
        Button("Elimina…", role: .destructive) {
            model.selection = item.id
            model.requestDelete(item.id)
        }
    }
}
