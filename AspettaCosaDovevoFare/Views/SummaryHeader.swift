import SwiftUI

/// Riga di riepilogo in testa alla lista: data di oggi e contatori di tutti i punti aperti.
struct SummaryHeader: View {
    @Environment(AppModel.self) private var model
    let summary: ItemSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(italianDayLabel(model.now))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                filterTokens
            }
            HStack(spacing: 6) {
                ForEach(Array(Kind.allCases.enumerated()), id: \.element) { index, kind in
                    if index > 0 { separator }
                    counter(summary.count(for: kind), kind.counterLabel, color: kind.color)
                }
                if summary.stale > 0 {
                    separator
                    counter(summary.stale, summary.stale == 1 ? "fermo" : "fermi", color: .stale)
                }
            }
            .font(.callout)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var separator: some View {
        Text("·").foregroundStyle(.tertiary).accessibilityHidden(true)
    }

    private func counter(_ value: Int, _ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label).foregroundStyle(.secondary)
        }
    }

    /// Token dei filtri combinati (progetto + persona) con la x per toglierli.
    @ViewBuilder private var filterTokens: some View {
        if model.filter.scope == nil {
            HStack(spacing: 6) {
                if let project = model.filter.project {
                    token(project, systemImage: "folder") { model.refine(project: project) }
                }
                if let person = model.filter.person {
                    token(person, systemImage: "person") { model.refine(person: person) }
                }
            }
        }
    }

    private func token(_ text: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(text)
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Togli il filtro \(text)")
    }
}
