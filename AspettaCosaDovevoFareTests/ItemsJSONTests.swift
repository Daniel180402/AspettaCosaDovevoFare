import Foundation
import SwiftData
import Testing
@testable import AspettaCosaDovevoFare

@Suite("JSON import/export")
struct ItemsJSONTests {
    @Test func roundtripNonPerdeDati() throws {
        var closed = ItemRecord(title: "Chiuso", kind: .attesa, project: "Maia", people: "Simo, Clark",
                                link: URL(string: "https://upkeep.beatdata.it/cards/c3tqzvwpo7rc"), note: "Nota con «virgolette» e accenti: è",
                                createdAt: Date(millisecondsSince1970: 1_793_034_000_000))
        closed.isDone = true
        closed.doneAt = Date(millisecondsSince1970: 1_793_120_400_123)
        closed.lastActivityAt = Date(millisecondsSince1970: 1_793_100_000_456)
        closed.nextCheckAt = Date(millisecondsSince1970: 1_793_200_000_000)
        let records = SeedData.records + [closed, ItemRecord(title: "Nuovo", kind: .fare)]

        let decoded = try ItemsJSON.decode(ItemsJSON.encode(records))
        #expect(Set(decoded.map(\.id)) == Set(records.map(\.id)))
        for record in records {
            #expect(decoded.first { $0.id == record.id } == record)
        }
    }

    @Test func formatoDelleSpecifiche() throws {
        let json = """
        [{"id":"abc-1","title":"Risposta di Paolo","kind":"attesa","project":"Telethon","people":"Paolo",
          "link":"https://upkeep.beatdata.it/cards/x","note":"","done":false,"createdAt":1793034000000,"doneAt":null}]
        """
        let r = try #require(try ItemsJSON.decode(Data(json.utf8)).first)
        #expect(r.kind == .attesa)
        #expect(r.createdAt == SeedData.createdAt)
        #expect(r.doneAt == nil)
        #expect(r.link?.host == "upkeep.beatdata.it")
        #expect(r.id == ItemsJSON.deterministicUUID(from: "abc-1"))
    }

    @Test func esportaDateInMillisecondiEChiaviNull() throws {
        let data = try ItemsJSON.encode([ItemRecord(title: "A", kind: .fare, createdAt: SeedData.createdAt)])
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]]).first
        #expect(object?["createdAt"] as? Int64 == 1_793_034_000_000)
        #expect(object?["doneAt"] is NSNull)
        #expect(object?["link"] is NSNull)
        #expect(object?["done"] as? Bool == false)
        #expect(object?["lastActivityAt"] is NSNull)
        #expect(object?["nextCheckAt"] is NSNull)
    }

    @Test func idNonUUIDDeterministico() {
        let a = ItemsJSON.deterministicUUID(from: "punto-42")
        #expect(a == ItemsJSON.deterministicUUID(from: "punto-42"))
        #expect(a != ItemsJSON.deterministicUUID(from: "punto-43"))
        #expect(a.uuidString.dropFirst(14).first == "5")
    }

    @Test func campiFacoltativiMancanti() throws {
        let json = #"[{"id":"x","title":"Solo titolo","kind":"fare"}]"#
        let now = Date(millisecondsSince1970: 1_800_000_000_000)
        let r = try #require(try ItemsJSON.decode(Data(json.utf8), now: now).first)
        #expect(r.project == "" && r.people == "" && r.note == "" && r.link == nil && !r.isDone)
        #expect(r.createdAt == now)
    }

    @Test func coordinareDeiFileVecchiDiventaFare() throws {
        let json = #"[{"id":"x","title":"T","kind":"coordinare"}]"#
        let r = try #require(try ItemsJSON.decode(Data(json.utf8)).first)
        #expect(r.kind == .fare)
        #expect(r.lastActivityAt == nil && r.nextCheckAt == nil)
    }

    @Test func linkNonHttpScartato() throws {
        let json = #"[{"id":"x","title":"T","kind":"fare","link":"javascript:alert(1)"}]"#
        #expect(try ItemsJSON.decode(Data(json.utf8)).first?.link == nil)
    }

    @Test func titoloENotaTroncati() throws {
        let long = String(repeating: "a", count: 900)
        let json = #"[{"id":"x","title":"\#(long)","kind":"fare","note":"\#(long)"}]"#
        let r = try #require(try ItemsJSON.decode(Data(json.utf8)).first)
        #expect(r.title.count == 200 && r.note.count == 600)
    }

    @Test func errori() {
        #expect(throws: ItemsJSON.ParseError.notAnArray) { try ItemsJSON.decode(Data(#"{"id":"x"}"#.utf8)) }
        #expect(throws: ItemsJSON.ParseError.invalidItem(index: 1, reason: "«boh» non è fare o attesa")) {
            try ItemsJSON.decode(Data(#"[{"id":"a","title":"A","kind":"fare"},{"id":"b","title":"B","kind":"boh"}]"#.utf8))
        }
        #expect(throws: ItemsJSON.ParseError.invalidItem(index: 0, reason: "manca «title»")) {
            try ItemsJSON.decode(Data(#"[{"id":"a","kind":"fare"}]"#.utf8))
        }
    }

    @MainActor
    @Test func importFaMergePerID() throws {
        let container = try ModelContainer(for: PendingItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = ItemStore(context: container.mainContext)
        store.merge(SeedData.records)
        let exported = try ItemsJSON.encode(store.allRecords())

        var reimported = try ItemsJSON.decode(exported)
        reimported[0].title = "Titolo cambiato"
        reimported.append(ItemRecord(title: "Arrivato dall'import", kind: .fare))
        let result = store.merge(reimported)
        #expect(result.inserted == 1 && result.updated == 1)
        #expect(store.allItems().count == 14)
    }

    @MainActor
    @Test func fonteLocale() async throws {
        let container = try ModelContainer(for: PendingItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let source = LocalItemSource(store: ItemStore(context: container.mainContext))
        source.store.merge(SeedData.records)
        let items = try source.items()
        #expect(items.count == 13)
        #expect(try await source.signals(for: items).isEmpty)
    }
}
