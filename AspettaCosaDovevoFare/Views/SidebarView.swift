import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Query private var items: [PendingItem]

    var body: some View {
        let selection = Binding<SidebarScope?>(
            get: { model.filter.scope },
            set: { if let scope = $0 { model.select(scope: scope) } }
        )
        List(selection: selection) {
            Section {
                row("Tutti", systemImage: "tray.full", count: items.count(where: { !$0.isDone }), scope: .all)
            }

            let projects = projectCounts(items)
            if !projects.isEmpty {
                Section("Progetti") {
                    ForEach(projects) { project in
                        row(project.name, systemImage: "folder", count: project.openCount, scope: .project(project.name))
                    }
                }
            }

            Section {
                row("Chiusi", systemImage: "checkmark.circle", count: items.count(where: \.isDone), scope: .closed)
            }

            let people = peopleCounts(items)
            if !people.isEmpty {
                Section("Persone") {
                    ForEach(people) { person in
                        row(person.name, systemImage: "person", count: person.openCount, scope: .person(person.name))
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ title: String, systemImage: String, count: Int, scope: SidebarScope) -> some View {
        Label(title, systemImage: systemImage)
            .badge(count)
            .tag(scope)
            .accessibilityLabel("\(title), \(count) aperti")
    }
}
