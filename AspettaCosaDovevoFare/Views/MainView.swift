import SwiftData
import SwiftUI

/// Finestra principale: sidebar con progetti e persone, lista dei punti a destra.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            ItemListView()
        }
        .searchable(text: $model.filter.query, placement: .toolbar, prompt: "Cerca nei punti")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.addItem()
                } label: {
                    Label("Aggiungi punto", systemImage: "plus")
                }
                .help("Aggiungi punto (⌘N)")
            }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .newItem: ItemFormView(itemID: nil)
            case .edit(let id): ItemFormView(itemID: id)
            case .notificationPrimer: NotificationPrimerView()
            case .checkIn: CheckInView()
            }
        }
        .onAppear {
            model.store.undoManager = undoManager
            model.register(openWindow: openWindow)
            model.showNotificationPrimerIfNeeded()
        }
        .onChange(of: undoManager) { _, newValue in
            model.store.undoManager = newValue
        }
        .frame(minWidth: 760, minHeight: 480)
    }
}
