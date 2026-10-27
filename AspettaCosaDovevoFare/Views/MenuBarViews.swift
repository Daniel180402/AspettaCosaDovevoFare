import SwiftData
import SwiftUI

/// Icona nella menu bar con il numero dei punti fermi.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query private var items: [PendingItem]
    @AppStorage(PrefKey.staleWaitingDays) private var staleWaitingDays = PrefDefault.staleWaitingDays
    @AppStorage(PrefKey.staleDoingDays) private var staleDoingDays = PrefDefault.staleDoingDays

    var body: some View {
        let thresholds = StaleThresholds(waiting: staleWaitingDays, doing: staleDoingDays)
        let stale = summarize(items, now: model.now, thresholds: thresholds).stale
        HStack(spacing: 2) {
            Image(systemName: "checklist")
            if stale > 0 {
                Text("\(stale)").monospacedDigit()
            }
        }
        .accessibilityLabel(stale == 0 ? "Aspetta cosa dovevo Fare?" : "Aspetta cosa dovevo Fare?, \(stale) punti fermi")
        .onAppear { model.register(openWindow: openWindow) }
    }
}

/// Popover della menu bar: i punti "Tocca a me" e quelli fermi, con checkbox.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \PendingItem.createdAt) private var items: [PendingItem]
    @AppStorage(PrefKey.staleWaitingDays) private var staleWaitingDays = PrefDefault.staleWaitingDays
    @AppStorage(PrefKey.staleDoingDays) private var staleDoingDays = PrefDefault.staleDoingDays

    var body: some View {
        let thresholds = StaleThresholds(waiting: staleWaitingDays, doing: staleDoingDays)
        let open = sortedOpen(items.filter { !$0.isDone })
        let mine = open.filter { $0.kind == .fare }
        let stale = open.filter { $0.kind == .attesa && isStale($0, now: model.now, thresholds: thresholds) }

        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if mine.isEmpty && stale.isEmpty {
                        Text("Niente di urgente. Ottimo.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    group(Kind.fare.title, color: Kind.fare.color, items: mine, thresholds: thresholds)
                    group("Fermi da sollecitare", color: .stale, items: stale, thresholds: thresholds)
                }
                .padding(14)
            }
            .frame(maxHeight: 420)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
            HStack {
                Button {
                    model.register(openWindow: openWindow)
                    model.addItem()
                } label: {
                    Label("Aggiungi punto", systemImage: "plus")
                }
                Spacer()
                Button("Apri Aspetta cosa dovevo Fare?") {
                    model.register(openWindow: openWindow)
                    model.showMainWindow()
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
    }

    @ViewBuilder
    private func group(_ title: String, color: Color, items: [PendingItem], thresholds: StaleThresholds) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(title).font(.headline)
                    Text("\(items.count)")
                        .font(.system(.subheadline, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                ForEach(items) { item in
                    MenuBarRow(item: item, stale: isStale(item, now: model.now, thresholds: thresholds))
                }
            }
        }
    }
}

private struct MenuBarRow: View {
    @Environment(AppModel.self) private var model
    let item: PendingItem
    let stale: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle(isOn: Binding(
                get: { item.isDone },
                set: { model.store.setDone(id: item.id, $0) }
            )) {
                Text(item.title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Chiudi «\(item.title)»")
            Text(ageLabel(days: ageInDays(item, now: model.now)))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(stale ? Color.stale : .secondary)
        }
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Capsule().fill(item.kind.color).frame(width: 3).accessibilityHidden(true)
        }
    }
}
