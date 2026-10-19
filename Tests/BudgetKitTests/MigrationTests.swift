import Testing
import Foundation
import SwiftData
@testable import BudgetKit

/// A file saved by the app before categories and the partner (`SchemaV1`) opens with everything in it.
@MainActor @Suite struct MigrationTests {
    @Test func aFileSavedBeforeOpensWithItsEntriesAndGainsTheStarterCategories() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tally-migration-\(UUID().uuidString)")
        let url = folder.appending(path: "Budget.store")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let spend = UUID()
        do {
            // Opened the way the app opened it before there were versions.
            let old = try ModelContainer(for: SchemaV1.PlanItemRecord.self, SchemaV1.EntryRecord.self, SchemaV1.SettingsRecord.self,
                                         configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(SchemaV1.SettingsRecord(startBalances: Data(#"{"main":15000}"#.utf8), startYear: 2026, startMonth: 10,
                                                   goals: Data("{}".utf8)))
            context.insert(SchemaV1.EntryRecord(id: spend, date: Fixtures.date(2026, 10, 19), amount: 340, kind: "spend",
                                                from: "main", category: "other", note: "cigarettes", movesMoney: true))
            try context.save()
        }

        let store = try Store(url: url, calendar: Fixtures.calendar)
        #expect(store.isSetUp)
        let ledger = store.ledger()
        let entry = try #require(ledger.entries.first { $0.id == spend })
        #expect(entry.amount == Cents(340))
        #expect(entry.category == "other")
        #expect(entry.note == "cigarettes")
        #expect(entry.partner == nil)
        #expect(ledger.balance(.main) == Cents(14660))
        #expect(ledger.categories.map(\.id) == ["food", "goingOut", "clothes", "fragrance", "other"])
    }
}

/// A file saved with categories and the partner (`SchemaV2`) opens with its partner's spends still owed.
@MainActor @Suite struct MigrationV2Tests {
    @Test func aFileWithThePartnerOpensWithWhatTheyOwe() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tally-migration-\(UUID().uuidString)")
        let url = folder.appending(path: "Budget.store")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        do {
            let old = try ModelContainer(for: Schema(versionedSchema: SchemaV2.self), migrationPlan: nil,
                                         configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(SchemaV1.SettingsRecord(startBalances: Data(#"{"main":15000}"#.utf8), startYear: 2026, startMonth: 10,
                                                   goals: Data("{}".utf8)))
            context.insert(SchemaV2.CategoryRecord(id: "food", name: "Food", pot: "main", order: 0, retired: false))
            context.insert(SchemaV2.EntryRecord(id: UUID(), date: Fixtures.date(2026, 10, 19), amount: 1000, kind: "spend",
                                                from: "main", category: "goingOut", note: "coffee", movesMoney: true,
                                                partner: "half", owed: 500))
            try context.save()
        }

        let store = try Store(url: url, calendar: Fixtures.calendar)
        let ledger = store.ledger()
        #expect(ledger.partnerOwes == Cents(500))
        #expect(ledger.entries.first { $0.kind == .spend }?.person == nil)
        #expect(ledger.categories.map(\.id) == ["food"])
    }
}

/// A file saved with people (`SchemaV3`) opens with its plan every month, as before, and its people.
@MainActor @Suite struct MigrationV3Tests {
    @Test func aFileWithPeopleOpensWithItsPlanEveryMonth() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "tally-migration-\(UUID().uuidString)")
        let url = folder.appending(path: "Budget.store")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let gym = UUID()
        do {
            let old = try ModelContainer(for: Schema(versionedSchema: SchemaV3.self), migrationPlan: nil,
                                         configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = ModelContext(old)
            context.insert(SchemaV1.SettingsRecord(startBalances: Data(#"{"main":15000}"#.utf8), startYear: 2026, startMonth: 10,
                                                   goals: Data("{}".utf8)))
            context.insert(SchemaV1.PlanItemRecord(id: gym, order: 0, name: "Gym", amount: 3500, kind: "payment",
                                                   schedule: Data(#"{"anyDay":{}}"#.utf8), paused: false))
            context.insert(SchemaV3.EntryRecord(id: UUID(), date: Fixtures.date(2026, 10, 19), amount: 5000, kind: "lent",
                                                from: "main", to: nil, movesMoney: false, person: "Ben"))
            try context.save()
        }

        let store = try Store(url: url, calendar: Fixtures.calendar)
        let ledger = store.ledger()
        let item = try #require(ledger.plan.first { $0.id == gym })
        #expect(item.repeatEvery == 1 && item.startsIn == nil)
        #expect(item.applies(in: YearMonth(2026, 10)))
        #expect(ledger.owes("Ben") == Cents(5000))
    }
}
