import Foundation
@testable import BudgetKit

/// The example month (Example.swift) and its 19 October 2026 state, as test data.
/// The plan and the paid entries come from `Seed`: one table only.
enum Fixtures {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static let october = Example.october

    static let salary = Example.ID.salary
    static let emergencyFirst = Example.ID.emergencyFirst
    static let course = Example.ID.course
    static let second = Example.ID.second
    static let bills = Example.ID.bills
    static let groceries = Example.ID.groceries
    static let emergencyExtra = Example.ID.emergencyExtra
    static let clothesPot = Example.ID.clothesPot
    static let gym = Example.ID.gym
    static let daily = Example.ID.daily
    static let card = Example.ID.card

    static let plan = Example.plan

    /// What was already paid by 19 October, recorded without moving money (the balances already include it).
    static func paidBeforeStart() -> [Entry] {
        Example.paidBeforeStart(month: october, calendar: calendar, at: date(2026, 10, 19))
    }

    static func oct19(main: Cents) -> Ledger {
        Ledger(start: [.main: main, .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
               startMonth: october, plan: plan, entries: paidBeforeStart(), calendar: calendar)
    }

    /// The side job's pay arrived on 20 October and its split was moved, as Payday would record it.
    static func afterSideJob() -> Ledger {
        var l = oct19(main: .euros(150))
        let day = Fixtures.date(2026, 10, 20)
        func record(_ id: UUID, _ amount: Cents, _ kind: EntryKind, from: Pot?, to: Pot?) {
            l.entries.append(Entry(date: day, amount: amount, kind: kind, from: from, to: to, planItem: id, forMonth: Fixtures.october))
        }
        record(Fixtures.second, .euros(650), .income, from: nil, to: .main)
        record(Fixtures.emergencyExtra, .euros(120), .transfer, from: .main, to: .emergency)
        record(Fixtures.clothesPot, .euros(80), .transfer, from: .main, to: .clothes)
        record(Fixtures.card, Cents(6340), .transfer, from: .main, to: .card)
        return l
    }
}
