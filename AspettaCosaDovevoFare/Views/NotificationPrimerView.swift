import SwiftUI

/// Spiegazione mostrata al primo avvio, prima di chiedere il permesso per le notifiche.
struct NotificationPrimerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.badge")
                .font(.system(size: 40))
                .foregroundStyle(Kind.fare.color)
                .accessibilityHidden(true)
            Text("Un promemoria al mattino")
                .font(.title2.weight(.semibold))
            Text("Ogni giorno feriale alle 9:00 ricevi una sola notifica, per esempio «3 cose toccano a te, 2 attese da sollecitare». Cliccandola si apre questa finestra.\n\nOrario e giorni si cambiano nelle Impostazioni (⌘,).")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Non ora") { answer(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Attiva promemoria") { answer(true) }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 420)
    }

    private func answer(_ enable: Bool) {
        dismiss()
        Task { await model.answerNotificationPrimer(enable: enable) }
    }
}
