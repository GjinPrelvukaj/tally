import Foundation

/// The payday sheet's amounts as typed. Nothing can be recorded until every one reads as money.
struct PaydayDraft {
    let items: [PlanItem]
    var amount: String
    var typed: [UUID: String]

    init(income: PlanItem, split: [PlanItem]) {
        items = split
        amount = income.amount.editable
        typed = Dictionary(uniqueKeysWithValues: split.map { ($0.id, $0.amount.editable) })
    }

    /// Each split item's amount; nil while any of them doesn't read as money.
    var split: [UUID: Cents]? {
        var result: [UUID: Cents] = [:]
        for item in items {
            guard let cents = typed[item.id].flatMap(Cents.parse) else { return nil }
            result[item.id] = cents
        }
        return result
    }

    /// The income reads as money above 0 and every split amount reads as money (a split item at 0 is simply not paid).
    var canAdd: Bool { Cents.parsePositive(amount) != nil && left != nil }

    /// What stays in Main once the split is paid; nil until everything reads as money.
    var left: Cents? {
        guard let income = Cents.parse(amount), let split else { return nil }
        return Payday.leftInMain(income: income, split: Array(split.values))
    }
}
