import SwiftUI

extension Kind {
    var color: Color {
        switch self {
        case .fare: Color(.fare)
        case .attesa: Color(.attesa)
        }
    }
}

/// Etichetta piccola in monospace per progetto e persone; il clic restringe il filtro.
struct Chip: View {
    let text: String
    let systemImage: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(isActive ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(isActive ? "Togli il filtro «\(text)»" : "Mostra solo «\(text)»")
        .accessibilityLabel(text)
        .accessibilityHint(isActive ? "Toglie il filtro" : "Filtra la lista")
    }
}
