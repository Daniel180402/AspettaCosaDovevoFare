import AppKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(PrefKey.notificationHour) private var hour = PrefDefault.notificationHour
    @AppStorage(PrefKey.notificationMinute) private var minute = PrefDefault.notificationMinute
    @AppStorage(PrefKey.notificationWeekdays) private var weekdaysText = PrefDefault.notificationWeekdays
    @AppStorage(PrefKey.staleWaitingDays) private var staleWaitingDays = PrefDefault.staleWaitingDays
    @AppStorage(PrefKey.staleDoingDays) private var staleDoingDays = PrefDefault.staleDoingDays
    @AppStorage(PrefKey.checkInEnabled) private var checkInEnabled = PrefDefault.checkInEnabled
    @AppStorage(PrefKey.checkInDays) private var checkInDays = PrefDefault.checkInDays
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    /// Lunedì per primo, come sul calendario italiano.
    private let weekdayOrder: [(number: Int, short: String, long: String)] = [
        (2, "Lun", "lunedì"), (3, "Mar", "martedì"), (4, "Mer", "mercoledì"), (5, "Gio", "giovedì"),
        (6, "Ven", "venerdì"), (7, "Sab", "sabato"), (1, "Dom", "domenica"),
    ]

    var body: some View {
        Form {
            Section("Promemoria giornaliero") {
                DatePicker("Orario", selection: time, displayedComponents: .hourAndMinute)
                LabeledContent("Giorni") {
                    HStack(spacing: 4) {
                        ForEach(weekdayOrder, id: \.number) { day in
                            Toggle(day.short, isOn: weekdayBinding(day.number))
                                .toggleStyle(.button)
                                .accessibilityLabel(day.long)
                        }
                    }
                }
                notificationStatus
            }

            Section {
                Stepper(value: $staleWaitingDays, in: 1...60) {
                    LabeledContent("Aspetto da altri", value: daysText(staleWaitingDays))
                }
                Stepper(value: $staleDoingDays, in: 1...60) {
                    LabeledContent("Tocca a me", value: daysText(staleDoingDays))
                }
            } header: {
                Text("Punti fermi")
            } footer: {
                Text("Dopo quanti giorni senza aggiornamenti un punto aperto diventa rosso e conta nel badge della menu bar.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Chiedi aggiornamenti sui punti fermi", isOn: $checkInEnabled)
                Stepper(value: $checkInDays, in: 1...30) {
                    LabeledContent("Senza aggiornamenti", value: daysText(checkInDays))
                }
                .disabled(!checkInEnabled)
            } header: {
                Text("Richiesta aggiornamenti")
            } footer: {
                Text("Un riquadro chiede, un punto alla volta, se ci sono novità; per i punti in attesa propone un ping. Compare solo tra le \(CheckIn.startHour) e le \(CheckIn.endHour).")
                    .foregroundStyle(.secondary)
            }

            Section("Dati") {
                DataTransferSection()
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .task { authorization = await NotificationScheduler.authorizationStatus() }
        .onChange(of: hour) { model.rescheduleNotifications() }
        .onChange(of: minute) { model.rescheduleNotifications() }
        .onChange(of: weekdaysText) { model.rescheduleNotifications() }
        .onChange(of: staleWaitingDays) { model.rescheduleNotifications() }
        .onChange(of: staleDoingDays) { model.rescheduleNotifications() }
    }

    private func daysText(_ n: Int) -> String {
        n == 1 ? "dopo 1 giorno" : "dopo \(n) giorni"
    }

    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date() },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour = c.hour ?? PrefDefault.notificationHour
                minute = c.minute ?? PrefDefault.notificationMinute
            }
        )
    }

    private func weekdayBinding(_ day: Int) -> Binding<Bool> {
        Binding(
            get: { parseWeekdays(weekdaysText).contains(day) },
            set: { on in
                var days = parseWeekdays(weekdaysText)
                if on { days.insert(day) } else { days.remove(day) }
                weekdaysText = formatWeekdays(days)
            }
        )
    }

    @ViewBuilder private var notificationStatus: some View {
        switch authorization {
        case .authorized, .provisional:
            Label("Notifiche consentite", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .denied:
            HStack {
                Label("Notifiche disattivate in Impostazioni di Sistema", systemImage: "bell.slash")
                    .foregroundStyle(Color.stale)
                Spacer()
                Button("Apri Impostazioni di Sistema") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        default:
            HStack {
                Text("Le notifiche non sono ancora state consentite.").foregroundStyle(.secondary)
                Spacer()
                Button("Consenti notifiche") {
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        authorization = await NotificationScheduler.authorizationStatus()
                        model.rescheduleNotifications()
                    }
                }
            }
        }
    }
}

/// Esporta e importa i punti in JSON; l'import fa merge per id.
struct DataTransferSection: View {
    @Environment(AppModel.self) private var model
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        HStack {
            Button("Esporta JSON…", action: export)
            Button("Importa JSON…", action: importFile)
            Spacer()
        }
        if let message {
            Text(message)
                .font(.callout)
                .foregroundStyle(isError ? Color.stale : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "punti-\(Date().formatted(.iso8601.year().month().day())).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let records = model.store.allRecords()
            try ItemsJSON.encode(records).write(to: url, options: .atomic)
            report("Esportati \(records.count) punti in \(url.lastPathComponent).")
        } catch {
            report("Esportazione non riuscita: \(error.localizedDescription)", error: true)
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let records = try ItemsJSON.decode(Data(contentsOf: url))
            let result = model.store.merge(records)
            report("Importati \(records.count) punti: \(result.inserted) nuovi, \(result.updated) aggiornati.")
        } catch {
            report("Importazione non riuscita. \(error.localizedDescription)", error: true)
        }
    }

    private func report(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }
}
