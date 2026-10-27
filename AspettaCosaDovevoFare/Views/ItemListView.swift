import SwiftData
import SwiftUI

/// Lista dei punti filtrati, divisa in Tocca a me / Aspetto da altri / Chiusi.
struct ItemListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \PendingItem.createdAt) private var items: [PendingItem]
    @AppStorage(PrefKey.staleWaitingDays) private var staleWaitingDays = PrefDefault.staleWaitingDays
    @AppStorage(PrefKey.staleDoingDays) private var staleDoingDays = PrefDefault.staleDoingDays

    private var thresholds: StaleThresholds {
        StaleThresholds(waiting: staleWaitingDays, doing: staleDoingDays)
    }

    var body: some View {
        @Bindable var model = model
        let filtered = applyFilter(items, model.filter)
        let open = sortedOpen(filtered.filter { !$0.isDone })
        let closed = sortedClosed(filtered.filter(\.isDone))

        VStack(spacing: 0) {
            SummaryHeader(summary: summarize(items, now: model.now, thresholds: thresholds))
            Divider()
            List(selection: $model.selection) {
                if model.filter.closedOnly {
                    if closed.isEmpty {
                        emptyRow(model.filter.query.isEmpty ? "Nessun punto chiuso." : noResults)
                    }
                    ForEach(closed) { row($0) }
                } else {
                    if open.isEmpty {
                        emptyRow(model.filter.query.isEmpty
                                 ? "Nessun punto aperto. Premi ⌘N per aggiungerne uno."
                                 : noResults)
                    }
                    ForEach(Kind.allCases) { kind in
                        let group = open.filter { $0.kind == kind }
                        if !group.isEmpty {
                            Section {
                                ForEach(group) { row($0) }
                            } header: {
                                SectionHeader(kind: kind, count: group.count)
                            }
                        }
                    }
                    if !closed.isEmpty {
                        Section {
                            if model.showClosed {
                                ForEach(closed) { row($0) }
                            }
                        } header: {
                            ClosedSectionHeader(count: closed.count, isExpanded: $model.showClosed)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .environment(\.defaultMinListRowHeight, 34)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first, let item = items.first(where: { $0.id == id }) {
                    ItemContextMenu(item: item)
                }
            } primaryAction: { ids in
                model.edit(ids.first)
            }
            .onKeyPress(.space) {
                guard model.selection != nil else { return .ignored }
                model.toggleDone(model.selection)
                return .handled
            }
            .onDeleteCommand {
                model.requestDelete(model.selection)
            }
            .onExitCommand {
                model.pendingDeleteID = nil
            }
        }
    }

    private var noResults: String {
        "Nessun risultato per «\(model.filter.query)»."
    }

    private func row(_ item: PendingItem) -> some View {
        ItemRow(item: item, now: model.now, thresholds: thresholds)
            .tag(item.id)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
            .selectionDisabled()
    }
}

struct SectionHeader: View {
    let kind: Kind
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(kind.color).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(count)")
                .font(.system(.subheadline, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(kind.color)
            Text(kind.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct ClosedSectionHeader: View {
    let count: Int
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Chiusi").font(.headline).foregroundStyle(.primary)
                Text("\(count)")
                    .font(.system(.subheadline, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .accessibilityLabel("Chiusi, \(count)")
        .accessibilityValue(isExpanded ? "espansa" : "compressa")
        .accessibilityHint(isExpanded ? "Comprime la sezione" : "Espande la sezione")
    }
}
