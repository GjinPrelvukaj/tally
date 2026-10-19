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

/// Categories of your own (`CategoryRecord`); the partner and how it was paid on an entry (`EntryRecord.partner`,
/// `owed`, `method`). Frozen copies of what changed; plan items and settings are as in V1.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.PlanItemRecord.self, EntryRecord.self, SchemaV1.SettingsRecord.self, CategoryRecord.self]
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
        var partner: String?
        var owed: Int?
        var method: String?

        init(id: UUID, date: Date, amount: Int, kind: String, from: String?, category: String?, note: String?, movesMoney: Bool,
             partner: String?, owed: Int?) {
            self.id = id
            self.date = date
            self.amount = amount
            self.kind = kind
            self.from = from
            self.category = category
            self.note = note
            self.movesMoney = movesMoney
            self.partner = partner
            self.owed = owed
        }
    }

    @Model final class CategoryRecord {
        @Attribute(.unique) var id: String
        var name: String
        var pot: String
        var order: Int
        var retired: Bool

        init(id: String, name: String, pot: String, order: Int, retired: Bool) {
            self.id = id
            self.name = name
            self.pot = pot
            self.order = order
            self.retired = retired
        }
    }
}

/// Who money is open with, on an entry (`EntryRecord.person`). A frozen copy of the entry; the rest as before.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.PlanItemRecord.self, EntryRecord.self, SchemaV1.SettingsRecord.self, SchemaV2.CategoryRecord.self]
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
        var partner: String?
        var owed: Int?
        var method: String?
        var person: String?

        init(id: UUID, date: Date, amount: Int, kind: String, from: String?, to: String?, movesMoney: Bool, person: String?) {
            self.id = id
            self.date = date
            self.amount = amount
            self.kind = kind
            self.from = from
            self.to = to
            self.movesMoney = movesMoney
            self.person = person
        }
    }
}

/// How often a plan item comes (`PlanItemRecord.repeatEvery`, `startsInYear`, `startsInMonth`).
enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] { [PlanItemRecord.self, EntryRecord.self, SettingsRecord.self, CategoryRecord.self] }
}

/// Only things added, nothing renamed or removed, so SwiftData moves the file itself, a version at a time.
enum TallyMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
         .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
         .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)]
    }
}
