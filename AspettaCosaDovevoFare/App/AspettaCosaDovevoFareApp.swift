import SwiftData
import SwiftUI

@main
struct AspettaCosaDovevoFareApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        Window("Aspetta cosa dovevo Fare?", id: AppModel.mainWindowID) {
            MainView()
                .environment(model)
        }
        .modelContainer(model.container)
        .commands {
            AppCommands(model: model)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(model)
                .modelContainer(model.container)
        } label: {
            MenuBarLabel()
                .environment(model)
                .modelContainer(model.container)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .modelContainer(model.container)
        }
    }
}

/// Voci di menu e scorciatoie della finestra principale.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Aggiungi punto") { model.addItem() }
                .keyboardShortcut("n")
        }
        CommandMenu("Punto") {
            Button("Modifica…") { model.edit(model.selection) }
                .keyboardShortcut("e")
                .disabled(model.selection == nil)
            Button("Chiudi o riapri") { model.toggleDone(model.selection) }
                .disabled(model.selection == nil)
            Button("Copia sollecito") { model.copyReminder(model.selection) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.selection == nil)
            Divider()
            Button("Elimina…") { model.requestDelete(model.selection) }
                .disabled(model.selection == nil)
        }
    }
}
