import Foundation

/// The plan a new person starts from: one salary and the usual things paid out of it. Every item can be
/// changed, paused or deleted in the plan; it is only a starting point.
public enum Seed {
    /// Fixed ids, so items that point at an income (`.withIncome`) keep pointing at it.
    public enum ID {
        public static let salary = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        public static let rent = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        public static let bills = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        public static let emergency = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        public static let pot = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
        public static let gym = UUID(uuidString: "00000000-0000-0000-0000-000000000106")!
        public static let daily = UUID(uuidString: "00000000-0000-0000-0000-000000000107")!
    }

    /// In the order the plan lists them.
    public static let plan: [PlanItem] = [
        PlanItem(id: ID.salary, name: "Salary", amount: .euros(2000), kind: .income, to: .main, schedule: .day(1)),
        PlanItem(id: ID.rent, name: "Rent", amount: .euros(700), kind: .payment, from: .main, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.bills, name: "Bills", amount: .euros(150), kind: .payment, from: .main, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.emergency, name: "Emergency fund", amount: .euros(300), kind: .transfer, from: .main, to: .emergency, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.pot, name: "Clothes pot", amount: .euros(100), kind: .transfer, from: .main, to: .clothes, schedule: .withIncome(ID.salary)),
        PlanItem(id: ID.gym, name: "Gym", amount: .euros(35), kind: .payment, from: .main, schedule: .anyDay),
        PlanItem(id: ID.daily, name: "Daily life", amount: .euros(20), kind: .daily, from: .main, schedule: .anyDay),
    ]

    /// The emergency fund's goal: about six months of the starter plan's costs.
    public static let goals: [Pot: Cents] = [.emergency: .euros(6000)]

    /// What the first run lists to tick: this month's items that can be paid (not the daily amount).
    public static func firstRunItems(in month: YearMonth, plan: [PlanItem] = plan) -> [PlanItem] {
        plan.filter { $0.applies(in: month) && $0.kind != .daily }
    }

    /// Entries for items already paid before starting: they count as done but move no money, because the
    /// balances typed in already include them.
    static func paidEntries(_ paid: [UUID: Cents], plan: [PlanItem], month: YearMonth, at date: Date) -> [Entry] {
        plan.compactMap { item in
            guard let amount = paid[item.id], let kind = item.kind.entryKind else { return nil }
            return Entry(date: date, amount: amount, kind: kind, from: item.from, to: item.to,
                         planItem: item.id, forMonth: month, movesMoney: false)
        }
    }
}
