import Testing
@testable import BudgetKit

@Suite struct FirstRunTests {
    @Test func itStartsWithTheStarterPlanAndNothingTicked() {
        let draft = FirstRunDraft(month: YearMonth(2026, 10))
        // Every starter item but the daily amount.
        #expect(draft.items.map(\.id) == Seed.plan.filter { $0.kind != .daily }.map(\.id))
        #expect(draft.paid.isEmpty)
        #expect(draft.paidAmounts == [:])
    }

    @Test func theCardIsTypedAsWhatIsOwedAndKeptAsADebt() {
        var draft = FirstRunDraft(month: YearMonth(2026, 10))
        draft.typed[.card] = "63,40"
        draft.typed[.main] = "150"
        #expect(draft.balance(.card) == Cents(-6340))
        #expect(draft.balance(.main) == .euros(150))
        #expect(draft.balance(.clothes) == nil)
    }

    @Test func aTickedAmountCanBeChangedAndATypoStopsIt() {
        var draft = FirstRunDraft(month: YearMonth(2026, 10))
        draft.paid.insert(Seed.ID.bills)
        draft.amounts[Seed.ID.bills] = "40"
        #expect(draft.paidAmounts?[Seed.ID.bills] == .euros(40))
        draft.amounts[Seed.ID.bills] = "4o"
        #expect(draft.paidAmounts == nil)
        // An unticked item's text doesn't matter.
        draft.paid.remove(Seed.ID.bills)
        #expect(draft.paidAmounts?[Seed.ID.bills] == nil)
        #expect(draft.paidAmounts != nil)
    }

    @Test func allFourBalancesAreNeededToStart() {
        var draft = FirstRunDraft(month: YearMonth(2026, 10))
        #expect(draft.balances == nil)
        for pot in Pot.allCases { draft.typed[pot] = "10" }
        #expect(draft.balances == [.main: .euros(10), .clothes: .euros(10), .emergency: .euros(10), .card: .euros(-10)])
    }
}
