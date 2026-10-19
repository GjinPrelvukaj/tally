import Foundation
@testable import BudgetKit

/// An example month the tests are built on: two incomes, savings, bills, a one-off card payment, part paid by the 19th.
enum Example {
    /// Fixed ids, so the plan items that point at an income (`.withIncome`) survive a reinstall.
    enum ID {
        static let salary = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let emergencyFirst = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        static let course = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        static let second = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        static let bills = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        static let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        static let emergencyExtra = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
        static let clothesPot = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
        static let gym = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        static let daily = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        static let card = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    }

    static let october = YearMonth(2026, 10)
    static let goals: [Pot: Cents] = [.emergency: .euros(5000)]

    /// In the design's table order; that order is how the plan is listed everywhere.
    static let plan: [PlanItem] = [
        PlanItem(id: ID.salary, name: "Salary", amount: .euros(2400), kind: .income, to: .main, schedule: .day(1)),
        PlanItem(id: ID.emergencyFirst, name: "Emergency fund", amount: .euros(350), kind: .transfer, from: .main, to: .emergency, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.course, name: "Course", amount: .euros(90), kind: .payment, from: .main, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.second, name: "Side job", amount: .euros(650), kind: .income, to: .main, schedule: .window(from: 15, to: 20)),
        PlanItem(id: ID.bills, name: "Bills", amount: .euros(140), kind: .payment, from: .main, schedule: .withIncome(ID.second)),
        PlanItem(id: ID.groceries, name: "Groceries", amount: .euros(260), kind: .payment, from: .main, schedule: .withIncome(ID.second)),
        PlanItem(id: ID.emergencyExtra, name: "Extra to emergency fund", amount: .euros(120), kind: .transfer, from: .main, to: .emergency, schedule: .withIncome(ID.second)),
        PlanItem(id: ID.clothesPot, name: "Clothes pot", amount: .euros(80), kind: .transfer, from: .main, to: .clothes, schedule: .withIncome(ID.second)),
        PlanItem(id: ID.gym, name: "Gym", amount: .euros(45), kind: .payment, from: .main, schedule: .anyDay),
        PlanItem(id: ID.daily, name: "Daily life", amount: .euros(25), kind: .daily, from: .main, schedule: .anyDay),
        PlanItem(id: ID.card, name: "Credit card", amount: Cents(6340), kind: .transfer, from: .main, to: .card, schedule: .withIncome(ID.second), onlyIn: october),
    ]

    /// Already paid by 19 October 2026 (bills and groceries part-paid), amounts as paid.
    static let paidInOctober: [UUID: Cents] = [
        ID.salary: .euros(2400), ID.emergencyFirst: .euros(350), ID.course: .euros(90),
        ID.bills: .euros(52), ID.groceries: .euros(175),
    ]




    static func paidBeforeStart(month: YearMonth, calendar: Calendar, at date: Date) -> [Entry] {
        Seed.paidEntries(paidInOctober, plan: plan, month: month, at: date)
    }
}

extension Store {
    /// Sets the store up with the example month instead of the app's starter plan.
    func setUpExample(balances: [Pot: Cents], paid: [UUID: Cents], today: Date) {
        setUp(balances: balances, paid: paid, today: today, plan: Example.plan, goals: Example.goals)
    }
}
