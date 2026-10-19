import Foundation

/// What has been typed on the first run: four balances, then which of this month's items are already paid, and at what.
/// Nothing can start until everything that counts reads as money.
struct FirstRunDraft {
    let items: [PlanItem]
    /// Per pot, as typed. The card's is what is owed, a positive number.
    var typed: [Pot: String] = [:]
    var paid: Set<UUID>
    var amounts: [UUID: String]

    init(month: YearMonth) {
        items = Seed.firstRunItems(in: month)
        // Nothing ticked: tick what is already out of the balances typed in.
        paid = []
        amounts = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.amount.editable) })
    }

    /// The pot's balance; the card is kept as a debt, below zero.
    func balance(_ pot: Pot) -> Cents? {
        typed[pot].flatMap(Cents.parse).map(pot.balance(fromFigure:))
    }

    var balances: [Pot: Cents]? {
        var result: [Pot: Cents] = [:]
        for pot in Pot.allCases {
            guard let cents = balance(pot) else { return nil }
            result[pot] = cents
        }
        return result
    }

    /// The ticked items at the amounts typed; nil while any of those doesn't read as money.
    var paidAmounts: [UUID: Cents]? {
        var result: [UUID: Cents] = [:]
        for id in paid {
            guard let cents = amounts[id].flatMap(Cents.parse) else { return nil }
            result[id] = cents
        }
        return result
    }
}
