import AppKit
import Foundation
import Observation
import SwiftData
import SwiftUI

/// Sheet presentabile sulla finestra principale.
enum ActiveSheet: Identifiable, Equatable {
    case newItem
    case edit(UUID)
    case notificationPrimer
    case checkIn

    var id: String {
        switch self {
        case .newItem: "new"
        case .edit(let id): "edit-\(id)"
        case .notificationPrimer: "primer"
        case .checkIn: "check-in"
        }
    }
}

/// Stato condiviso dell'app: contenitore dati, store e stato dell'interfaccia.
@MainActor
@Observable
final class AppModel {
    static let mainWindowID = "main"

    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let store: ItemStore

    var filter = ItemFilter()
    var selection: UUID?
    var sheet: ActiveSheet?
    /// Punto per cui è visibile la conferma di eliminazione inline.
    var pendingDeleteID: UUID?
    var showClosed = false
    /// Ora corrente, aggiornata ogni minuto: età e staleness si ricalcolano da sole.
    var now = Date()

    @ObservationIgnored private var openWindowAction: OpenWindowAction?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var rescheduleTask: Task<Void, Never>?

    init(inMemory: Bool = AppModel.isRunningTests) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: PendingItem.self, configurations: configuration)
        } catch {
            fatalError("Impossibile aprire il database: \(error)")
        }
        store = ItemStore(context: container.mainContext)
        if !inMemory {
            store.migrateLegacyKinds()
            store.seedIfNeeded()
        }
        store.onChange = { [weak self] in self?.rescheduleNotifications() }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self else { return }
                let previous = self.now
                self.now = Date()
                if !Calendar.current.isDate(previous, inSameDayAs: self.now) {
                    self.rescheduleNotifications()
                }
                self.presentCheckInIfNeeded()
            }
        }
    }

    nonisolated static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: Notifiche

    /// Ripianifica le notifiche dei prossimi giorni con i dati attuali (raggruppando le modifiche ravvicinate).
    func rescheduleNotifications() {
        guard !Self.isRunningTests else { return }
        let defaults = UserDefaults.standard
        let plan = planDailyNotifications(
            store.allRecords(),
            now: Date(),
            hour: defaults.object(forKey: PrefKey.notificationHour) as? Int ?? PrefDefault.notificationHour,
            minute: defaults.object(forKey: PrefKey.notificationMinute) as? Int ?? PrefDefault.notificationMinute,
            weekdays: parseWeekdays(defaults.string(forKey: PrefKey.notificationWeekdays) ?? PrefDefault.notificationWeekdays),
            thresholds: .current(defaults)
        )
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await NotificationScheduler.replace(with: plan)
        }
    }

    /// Al primo avvio mostra la spiegazione prima di chiedere il permesso.
    func showNotificationPrimerIfNeeded() {
        guard !Self.isRunningTests, !UserDefaults.standard.bool(forKey: PrefKey.didShowNotificationPrimer) else { return }
        sheet = .notificationPrimer
    }

    func answerNotificationPrimer(enable: Bool) async {
        UserDefaults.standard.set(true, forKey: PrefKey.didShowNotificationPrimer)
        if enable {
            _ = await NotificationScheduler.requestAuthorization()
            rescheduleNotifications()
        }
    }

    // MARK: Riquadro aggiornamenti

    /// Apre il riquadro se ci sono punti fermi da rivedere, siamo nella fascia 9–18 e non c'è già un'altra sheet.
    func presentCheckInIfNeeded(now: Date = Date()) {
        let defaults = UserDefaults.standard
        guard !Self.isRunningTests, sheet == nil,
              defaults.object(forKey: PrefKey.checkInEnabled) as? Bool ?? PrefDefault.checkInEnabled,
              CheckIn.isWithinHours(now),
              !CheckIn.dueItems(store.allItems(), now: now, days: checkInDays).isEmpty
        else { return }
        showMainWindow()
        sheet = .checkIn
    }

    var checkInDays: Int {
        UserDefaults.standard.object(forKey: PrefKey.checkInDays) as? Int ?? PrefDefault.checkInDays
    }

    // MARK: Finestra

    /// Le viste sempre presenti (finestra e menu bar) registrano qui l'azione per aprire la finestra.
    func register(openWindow: OpenWindowAction) {
        openWindowAction = openWindow
    }

    func showMainWindow() {
        openWindowAction?(id: Self.mainWindowID)
        NSApp.activate()
    }

    // MARK: Filtri

    func select(scope: SidebarScope) {
        filter = ItemFilter(scope: scope, query: filter.query)
        pendingDeleteID = nil
    }

    /// Clic su un chip: restringe il filtro corrente a quel progetto, o lo toglie se è già attivo.
    func refine(project: String) {
        filter.project = filter.project?.caseInsensitiveCompare(project) == .orderedSame ? nil : project
    }

    func refine(person: String) {
        filter.person = filter.person?.caseInsensitiveCompare(person) == .orderedSame ? nil : person
    }

    // MARK: Azioni sui punti

    func addItem() {
        showMainWindow()
        sheet = .newItem
    }

    func edit(_ id: UUID?) {
        guard let id else { return }
        sheet = .edit(id)
    }

    func toggleDone(_ id: UUID?) {
        guard let id else { return }
        store.toggleDone(id: id)
    }

    func requestDelete(_ id: UUID?) {
        pendingDeleteID = id
    }

    func confirmDelete() {
        guard let id = pendingDeleteID else { return }
        pendingDeleteID = nil
        if selection == id { selection = nil }
        store.delete(id: id)
    }

    func copyReminder(_ id: UUID?) {
        guard let id, let item = store.item(id: id) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(reminderText(for: item), forType: .string)
    }
}
