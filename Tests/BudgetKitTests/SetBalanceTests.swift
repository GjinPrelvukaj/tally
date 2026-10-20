import Testing
import Foundation
@testable import BudgetKit

/// A balance set by hand stays as it was set: deleting or changing an entry from before it no longer moves it.
@MainActor @Suite struct SetBalanceTests {
    func at(_ hour: Int, minute: Int = 0) -> Date { Fixtures.date(2026, 10, 19, hour: hour).addingTimeInterval(Double(minute) * 60) }

    func store(card: Cents = Cents(-9994)) -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUp(balances: [.main: .euros(500), .card: card], paid: [:], today: at(9), plan: [], goals: [:])
        return store
    }

    /// What happened on the real data: a card payment by mistake, the card set to what the bank says, then the mistake
    /// deleted. The card must still owe what was set; Main gets the mistaken payment back.
    @Test func deletingAMistakeMadeBeforeSettingTheCardKeepsTheCard() throws {
        let store = store()
        let mistake = Entry(date: at(16, minute: 40), amount: Cents(9914), kind: .transfer, from: .main, to: .card)
        store.add(mistake)
        store.setBalance(.card, to: Cents(-430), at: at(16, minute: 41))
        #expect(store.ledger().balance(.card) == Cents(-430))
        store.deleteEntry(mistake.id)
        #expect(store.ledger().balance(.card) == Cents(-430))
        #expect(store.ledger().balance(.main) == .euros(500))
        // And what comes after it still counts.
        store.logSpend(Cents(530), category: .food, note: nil, paidWith: .card, at: at(20))
        #expect(store.ledger().balance(.card) == Cents(-960))
    }

    @Test func changingAnEarlierSpendKeepsTheSetBalance() throws {
        let store = store()
        store.logSpend(Cents(390), category: .food, note: nil, paidWith: .bank, at: at(12))
        store.setBalance(.main, to: .euros(400), at: at(13))
        var spend = try #require(store.ledger().entries.first { $0.kind == .spend })
        spend.amount = Cents(1390)
        store.update(spend)
        #expect(store.ledger().balance(.main) == .euros(400))
        // Moved to the card instead: Main still holds what was set, the card owes it.
        spend.from = .card
        store.update(spend)
        #expect(store.ledger().balance(.main) == .euros(400))
        #expect(store.ledger().balance(.card) == Cents(-9994 - 1390))
    }

    @Test func anEntryAfterTheSetBalanceStillMovesIt() throws {
        let store = store()
        store.setBalance(.main, to: .euros(400), at: at(13))
        store.logSpend(Cents(390), category: .food, note: nil, paidWith: .bank, at: at(14))
        let spend = try #require(store.ledger().entries.first { $0.kind == .spend })
        store.deleteEntry(spend.id)
        #expect(store.ledger().balance(.main) == .euros(400))
        store.logSpend(Cents(390), category: .food, note: nil, paidWith: .bank, at: at(15))
        #expect(store.ledger().balance(.main) == Cents(39610))
    }

    /// Only the first balance set after it takes up the difference; every later one then holds too.
    @Test func onlyTheFirstSetBalanceAfterItChanges() throws {
        let store = store()
        let mistake = Entry(date: at(10), amount: .euros(50), kind: .transfer, from: .main, to: .card)
        store.add(mistake)
        store.setBalance(.main, to: .euros(300), at: at(11))
        store.logSpend(Cents(1000), category: .food, note: nil, paidWith: .bank, at: at(12))
        store.setBalance(.main, to: .euros(250), at: at(13))
        store.deleteEntry(mistake.id)
        #expect(store.ledger().balance(.main) == .euros(250))
        let adjustments = store.ledger().entries.filter { $0.kind == .adjustment && $0.to == .main }.sorted { $0.date < $1.date }
        #expect(adjustments.map(\.amount) == [.euros(-200), .euros(-40)])
    }

    @Test func deletingTheSetBalanceItselfTakesItBack() throws {
        let store = store()
        store.setBalance(.main, to: .euros(400), at: at(13))
        let adjustment = try #require(store.ledger().entries.first { $0.kind == .adjustment })
        store.deleteEntry(adjustment.id)
        #expect(store.ledger().balance(.main) == .euros(500))
    }

    /// The editor says it before the delete: "Credit card stays at what was set on the 19th."
    @Test func theLedgerSaysWhichSetBalancesHold() {
        let mistake = Entry(date: at(10), amount: .euros(50), kind: .transfer, from: .main, to: .card)
        let pin = Entry(date: at(11), amount: .euros(-5), kind: .adjustment, to: .card)
        let ledger = Ledger(start: [:], startMonth: YearMonth(2026, 10), plan: [], entries: [mistake, pin], calendar: Fixtures.calendar)
        #expect(ledger.setBalancesHeld(changing: mistake, to: nil).map(\.to) == [.card])
        #expect(ledger.setBalancesHeld(changing: mistake, to: nil).first?.amount == .euros(45))
        #expect(ledger.setBalancesHeld(changing: pin, to: nil).isEmpty)
    }
}
