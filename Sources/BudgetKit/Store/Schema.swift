import Foundation
import SwiftData

// What is saved, version by version. A file saved by an older Tally is moved to the newest version when it opens;
// before a model changes, add a version here (and back up `Budget.store`, `-wal`, `-shm`).

/// The records as Tally saved them before it had versions: frozen copies, so an old file can be recognised.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PlanItemRecord.self, EntryRecord.self, SettingsRecord.self] }

    @Model final class PlanItemRecord {
        @Attribute(.unique) var id: UUID
        var order: Int
        var name: String
        var amount: Int
        var kind: String
        var from: String?
        var to: String?
        var schedule: Data
        var onlyInYear: Int?
        var onlyInMonth: Int?
        var paused: Bool

        init(id: UUID, order: Int, name: String, amount: Int, kind: String, schedule: Data, paused: Bool) {
            self.id = id
            self.order = order
            self.name = name
            self.amount = amount
            self.kind = kind
            self.schedule = schedule
            self.paused = paused
        }
    }

    @Model final class EntryRecord {
        @Attribute(.unique) var id: UUID
        var date: Date
        var amount: Int
        var kind: String
        var from: String?
        var to: String?
        var category: String?
        var note: String?
        var planItem: UUID?
        var forYear: Int?
        var forMonth: Int?
        var movesMoney: Bool

        init(id: UUID, date: Date, amount: Int, kind: String, from: String?, category: String?, note: String?, movesMoney: Bool) {
            self.id = id
            self.date = date
            self.amount = amount
            self.kind = kind
            self.from = from
            self.category = category
            self.note = note
            self.movesMoney = movesMoney
        }
    }

    @Model final class SettingsRecord {
        var startBalances: Data
        var startYear: Int
        var startMonth: Int
        var goals: Data

        init(startBalances: Data, startYear: Int, startMonth: Int, goals: Data) {
            self.startBalances = startBalances
            self.startYear = startYear
            self.startMonth = startMonth
            self.goals = goals
        }
    }
}

/// Categories of your own (`CategoryRecord`); the partner and how it was paid on an entry (`EntryRecord.partner`, `owed`, `method`).
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [PlanItemRecord.self, EntryRecord.self, SettingsRecord.self, CategoryRecord.self] }
}

/// Only things added, nothing renamed or removed, so SwiftData moves the file itself.
enum TallyMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)] }
}
