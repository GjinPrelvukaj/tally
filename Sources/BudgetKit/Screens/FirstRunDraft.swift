import Foundation

/// What has been typed on the first run: the income, the regular costs, savings and every day, the pots, then which of
/// this month's items are already paid. It builds the person's own plan; a field left empty is nothing (a pot, 0).
/// Nothing can start while anything typed doesn't read as money.
struct FirstRunDraft {
    let month: YearMonth
    // Fixed for the draft, so ticks stay on their items while the rest is typed.
    let incomeID = UUID()
    let emergencyID = UUID()
    let clothesID = UUID()
    let dailyID = UUID()

    var incomeName = "Salary"
    var incomeAmount = ""
    var incomeDay = 1
    var costs: [FirstRunCost] = []
    var toEmergency = ""
    var toClothes = ""
    /// The emergency fund's goal.
    var goal = ""
    /// About how much goes on everything else, a day.
    var daily = ""
    /// Per pot, as typed. The card's is what is owed, a positive number.
    var typed: [Pot: String] = [:]
    var paid: Set<UUID> = []
    /// A ticked item's amount, when changed from its planned one.
    var amounts: [UUID: String] = [:]

    init(month: YearMonth) {
        self.month = month
    }

    /// A common one picked by name, or "" for one of their own.
    mutating func addCost(_ name: String) {
        costs.append(FirstRunCost(name: name, inMonth: month.month))
    }

    /// The plan, in the Plan's order; nil while something typed doesn't read.
    var plan: [PlanItem]? {
        guard let income = Self.amount(incomeAmount), let emergency = Self.amount(toEmergency),
              let clothes = Self.amount(toClothes), let daily = Self.amount(daily) else { return nil }
        var plan: [PlanItem] = []
        let name = incomeName.trimmingCharacters(in: .whitespaces)
        if let income {
            plan.append(PlanItem(id: incomeID, name: name.isEmpty ? "Income" : name, amount: income, kind: .income,
                                 to: .main, schedule: .day(incomeDay)))
        }
        // Without an income, nothing can wait for it.
        let withPay: Schedule = income == nil ? .anyDay : .withIncome(incomeID)
        for cost in costs {
            let name = cost.name.trimmingCharacters(in: .whitespaces)
            guard let amount = Self.amount(cost.amount) else { return nil }
            // Picked but left without an amount: not one of theirs after all.
            guard let amount else { continue }
            guard !name.isEmpty else { return nil }
            plan.append(PlanItem(id: cost.id, name: name, amount: amount, kind: .payment, from: .main,
                                 schedule: cost.day.map(Schedule.day) ?? withPay,
                                 repeatEvery: cost.yearly ? 12 : 1, startsIn: cost.yearly ? next(cost.inMonth) : nil))
        }
        if let emergency {
            plan.append(PlanItem(id: emergencyID, name: "Emergency fund", amount: emergency, kind: .transfer, from: .main,
                                 to: .emergency, schedule: withPay))
        }
        if let clothes {
            plan.append(PlanItem(id: clothesID, name: "Clothes pot", amount: clothes, kind: .transfer, from: .main,
                                 to: .clothes, schedule: withPay))
        }
        if let daily {
            plan.append(PlanItem(id: dailyID, name: "Daily life", amount: daily, kind: .daily, from: .main, schedule: .anyDay))
        }
        return plan
    }

    var goals: [Pot: Cents]? {
        guard let goal = Self.amount(goal) else { return nil }
        return goal.map { [.emergency: $0] } ?? [:]
    }

    /// Every pot; one left empty is 0, and any can be below it (overdrawn, or the card in credit). The card is kept as a debt, below zero.
    var balances: [Pot: Cents]? {
        var result: [Pot: Cents] = [:]
        for pot in Pot.allCases {
            let text = typed[pot, default: ""].trimmingCharacters(in: .whitespaces)
            guard let cents = text.isEmpty ? .zero : Cents.parseSigned(text) else { return nil }
            result[pot] = pot.balance(fromFigure: cents)
        }
        return result
    }

    /// This month's items that can be ticked as already paid.
    var items: [PlanItem] { Seed.firstRunItems(in: month, plan: plan ?? []) }

    /// Ticks what has most likely happened by `today` (a day of this month): a dated item before today, an income
    /// that came and what goes with it. Every tick can be taken off.
    mutating func tickWhatHasPassed(today: Int) {
        let incomeCame = incomeDay < today && items.contains { $0.id == incomeID }
        paid = Set(items.filter { item in
            switch item.schedule {
            case .day(let day): day < today
            case .withIncome: incomeCame
            default: false
            }
        }.map(\.id))
    }

    /// The ticked items at the amounts typed (their planned one, untouched); nil while any of those doesn't read.
    var paidAmounts: [UUID: Cents]? {
        var result: [UUID: Cents] = [:]
        for item in items where paid.contains(item.id) {
            guard let cents = amounts[item.id].map({ Cents.parsePositive($0) }) ?? .some(item.amount) else { return nil }
            result[item.id] = cents
        }
        return result
    }

    /// A typed amount: `.some(nil)` when left empty, nil when it doesn't read as money above 0.
    private static func amount(_ text: String) -> Cents?? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? .some(nil) : Cents.parsePositive(text).map { $0 }
    }

    /// The month a yearly cost next comes: this year's if it hasn't passed, else next year's.
    private func next(_ month: Int) -> YearMonth {
        YearMonth(self.month.year + (month < self.month.month ? 1 : 0), month)
    }
}

/// One regular cost as typed. No day: paid when the pay comes.
struct FirstRunCost: Identifiable {
    let id = UUID()
    var name: String
    var amount = ""
    var day: Int?
    var yearly = false
    /// The month a yearly one comes in, 1 to 12.
    var inMonth: Int
}
