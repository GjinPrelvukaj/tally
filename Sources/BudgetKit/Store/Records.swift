import Foundation
import SwiftData

// The saved forms of the plain model values. Enums are kept as their raw text and `Schedule` as JSON,
// so a renamed Swift type never changes what is on disk.

private func json<T: Encodable>(_ value: T) -> Data { (try? JSONEncoder().encode(value)) ?? Data() }

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

    init(_ item: PlanItem, order: Int) {
        id = item.id
        self.order = order
        name = item.name
        amount = item.amount.value
        kind = item.kind.rawValue
        from = item.from?.rawValue
        to = item.to?.rawValue
        schedule = json(item.schedule)
        onlyInYear = item.onlyIn?.year
        onlyInMonth = item.onlyIn?.month
        paused = item.paused
    }

    /// Writes an edited item over this record, keeping its place in the list.
    func apply(_ item: PlanItem) {
        name = item.name
        amount = item.amount.value
        kind = item.kind.rawValue
        from = item.from?.rawValue
        to = item.to?.rawValue
        schedule = json(item.schedule)
        onlyInYear = item.onlyIn?.year
        onlyInMonth = item.onlyIn?.month
        paused = item.paused
    }

    /// An item that waits for an income that is going away becomes "any day", so it is never left waiting for nothing.
    func stopWaiting(on income: UUID) {
        if value.schedule == .withIncome(income) { schedule = json(Schedule.anyDay) }
    }

    var value: PlanItem {
        PlanItem(id: id, name: name, amount: Cents(amount), kind: PlanKind(rawValue: kind) ?? .payment,
                 from: from.flatMap(Pot.init), to: to.flatMap(Pot.init),
                 schedule: (try? JSONDecoder().decode(Schedule.self, from: schedule)) ?? .anyDay,
                 onlyIn: onlyInYear.flatMap { year in onlyInMonth.map { YearMonth(year, $0) } }, paused: paused)
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

    init(_ entry: Entry) {
        id = entry.id
        date = entry.date
        amount = entry.amount.value
        kind = entry.kind.rawValue
        movesMoney = entry.movesMoney
        apply(entry)
    }

    /// Writes an edited entry over this record; its id stays.
    func apply(_ entry: Entry) {
        date = entry.date
        amount = entry.amount.value
        kind = entry.kind.rawValue
        from = entry.from?.rawValue
        to = entry.to?.rawValue
        category = entry.category?.rawValue
        note = entry.note
        planItem = entry.planItem
        forYear = entry.forMonth?.year
        forMonth = entry.forMonth?.month
        movesMoney = entry.movesMoney
    }

    var value: Entry {
        Entry(id: id, date: date, amount: Cents(amount), kind: EntryKind(rawValue: kind) ?? .adjustment,
              from: from.flatMap(Pot.init), to: to.flatMap(Pot.init), category: category.flatMap(Category.init),
              note: note, planItem: planItem,
              forMonth: forYear.flatMap { year in forMonth.map { YearMonth(year, $0) } }, movesMoney: movesMoney)
    }
}

/// The one row of settings: where each pot started, in which month, and the goal of each pot.
@Model final class SettingsRecord {
    var startBalances: Data
    var startYear: Int
    var startMonth: Int
    var goals: Data

    init(balances: [Pot: Cents], startMonth: YearMonth, goals: [Pot: Cents]) {
        startBalances = Self.data(balances)
        startYear = startMonth.year
        self.startMonth = startMonth.month
        self.goals = Self.data(goals)
    }

    var balances: [Pot: Cents] { Self.pots(startBalances) }
    var goalAmounts: [Pot: Cents] { Self.pots(goals) }
    var month: YearMonth { YearMonth(startYear, startMonth) }

    private static func data(_ pots: [Pot: Cents]) -> Data {
        json(Dictionary(uniqueKeysWithValues: pots.map { ($0.key.rawValue, $0.value.value) }))
    }

    private static func pots(_ data: Data) -> [Pot: Cents] {
        let raw = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Pot(rawValue: key).map { ($0, Cents(value)) } })
    }
}
