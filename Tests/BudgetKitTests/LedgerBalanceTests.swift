import Testing
import Foundation
@testable import BudgetKit

@Suite struct LedgerBalanceTests {
    let main = Cents.euros(150)

    @Test func startingBalances() {
        let ledger = Fixtures.oct19(main: main)
        #expect(ledger.balance(.main) == Cents(15000))
        #expect(ledger.balance(.emergency) == Cents(131250))
        #expect(ledger.balance(.card) == Cents(-6340))
        #expect(ledger.balance(.clothes) == .zero)
    }

    @Test func paidBeforeStartDoesNotMoveMoney() {
        #expect(Fixtures.oct19(main: main).balance(.main) == main)
    }

    @Test func cardPaymentClearsDebt() {
        var ledger = Fixtures.oct19(main: main)
        ledger.entries.append(Entry(date: Fixtures.date(2026, 10, 20), amount: Cents(6340), kind: .transfer, from: .main, to: .card))
        #expect(ledger.balance(.card) == .zero)
        #expect(ledger.balance(.main) == Cents(8660))
    }

    @Test func adjustmentSetsBalance() {
        var ledger = Fixtures.oct19(main: main)
        ledger.entries.append(Entry(date: Fixtures.date(2026, 10, 20), amount: Cents(1200), kind: .adjustment, to: .main))
        #expect(ledger.balance(.main) == Cents(16200))
    }

    @Test func editingPlanDoesNotRewriteHistory() {
        var ledger = Fixtures.oct19(main: main)
        ledger.entries.append(Entry(date: Fixtures.date(2026, 10, 20), amount: .euros(45), kind: .payment, from: .main,
                                    planItem: Fixtures.gym, forMonth: Fixtures.october))
        #expect(ledger.balance(.main) == .euros(105))
        let at = ledger.plan.firstIndex { $0.id == Fixtures.gym }!
        ledger.plan[at].amount = .euros(60)
        #expect(ledger.balance(.main) == .euros(105))
    }

    @Test func balanceAtEndOfDayIgnoresLaterEntries() {
        var ledger = Fixtures.oct19(main: main)
        ledger.entries.append(Entry(date: Fixtures.date(2026, 10, 20, hour: 0), amount: .euros(10), kind: .spend, from: .main, category: Category.food.id))
        #expect(ledger.balance(.main, endOf: Fixtures.date(2026, 10, 19)) == main)
        #expect(ledger.balance(.main, endOf: Fixtures.date(2026, 10, 20, hour: 9)) == .euros(140))
    }

    @Test func totalTakesTheCardsDebtOff() {
        // 150 + 0 + 1 312,50 − 63,40
        #expect(Fixtures.oct19(main: main).total == Cents(139910))
    }
}
