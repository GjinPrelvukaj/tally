import Testing
import Foundation
@testable import BudgetKit

@MainActor @Suite struct EntryEditingTests {
    let oct19 = Fixtures.date(2026, 10, 19)

    func store() -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                           paid: Example.paidInOctober, today: oct19)
        return store
    }

    func lastSpend(_ store: Store) throws -> Entry {
        try #require(store.ledger().entries.last { $0.kind == .spend })
    }

    @Test func aSpendLoggedOnTheWrongPotCanBeMovedToTheCard() throws {
        let store = store()
        store.logSpend(Cents(340), category: .other, note: nil, paidWith: .bank, at: oct19)
        var draft = EntryDraft(try lastSpend(store), ledger: store.ledger())
        draft.method = .card
        store.update(try #require(draft.entry))
        #expect(store.ledger().balance(.main) == Cents(15000))
        #expect(store.ledger().balance(.card) == Cents(-6680))
    }

    @Test func aSpendsAmountCanBeChanged() throws {
        let store = store()
        store.logSpend(Cents(510), category: .food, note: "coffee", paidWith: .bank, at: oct19)
        var draft = EntryDraft(try lastSpend(store), ledger: store.ledger())
        draft.amount = "5"
        store.update(try #require(draft.entry))
        let spend = try lastSpend(store)
        #expect(spend.amount == Cents(500))
        #expect(spend.note == "coffee")
        #expect(spend.date == oct19)
        #expect(store.ledger().balance(.main) == Cents(14500))
    }

    @Test func aCategoryOfClothesMovesTheSpendToTheClothesPot() throws {
        let store = store()
        store.logSpend(Cents(2000), category: .food, note: nil, paidWith: .bank, at: oct19)
        var draft = EntryDraft(try lastSpend(store), ledger: store.ledger())
        draft.category = .clothes
        store.update(try #require(draft.entry))
        #expect(store.ledger().balance(.main) == Cents(15000))
        #expect(store.ledger().balance(.clothes) == Cents(-2000))
    }

    @Test func zeroOrTextIsNeverSaved() throws {
        let store = store()
        store.logSpend(Cents(510), category: .food, note: nil, paidWith: .bank, at: oct19)
        var draft = EntryDraft(try lastSpend(store), ledger: store.ledger())
        draft.amount = "0"
        #expect(draft.entry == nil)
        draft.amount = "abc"
        #expect(draft.entry == nil)
    }

    @Test func deletingAPaymentMakesItDueAgain() throws {
        let store = store()
        let gym = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(gym, amount: gym.item.amount, at: oct19)
        let paid = try #require(store.ledger().entries.last { $0.planItem == Example.ID.gym })
        store.deleteEntry(paid.id)
        #expect(store.ledger().stillToPay(today: oct19).contains { $0.item.id == Example.ID.gym })
        #expect(store.ledger().balance(.main) == Cents(15000))
        // Undo has nothing left to take back.
        #expect(!store.canUndo)
    }

    @Test func theMonthsEntriesAreTheOnesThatMovedMoneyNewestFirst() throws {
        let store = store()
        store.logSpend(Cents(510), category: .food, note: nil, paidWith: .bank, at: oct19)
        store.logSpend(Cents(340), category: .other, note: nil, paidWith: .card, at: Fixtures.date(2026, 10, 19, hour: 18))
        store.logSpend(Cents(900), category: .food, note: nil, paidWith: .bank, at: Fixtures.date(2026, 11, 2))
        let october = store.ledger().entries(in: YearMonth(2026, 10))
        // "Paid before you started" moved no money, so it is not listed.
        #expect(october.map(\.amount) == [Cents(340), Cents(510)])
    }
}
