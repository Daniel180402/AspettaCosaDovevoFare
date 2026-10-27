import AppKit
import UserNotifications

/// Possiede il modello dell'app e riceve i clic sulle notifiche.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppModel.isRunningTests else { return }
        UNUserNotificationCenter.current().delegate = self
        model.rescheduleNotifications()
        Task {
            // Lascia comparire la finestra prima di chiedere aggiornamenti.
            try? await Task.sleep(for: .seconds(2))
            model.presentCheckInIfNeeded()
        }
    }

    /// Clic sulla notifica: apre la finestra principale.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { model.showMainWindow() }
    }

    /// Mostra il banner anche se l'app è in primo piano.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
