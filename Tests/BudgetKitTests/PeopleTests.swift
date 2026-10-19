import Testing
import Foundation
@testable import BudgetKit

/// Money open with people: lent, borrowed, paid back either way, and what was owed from before Tally.
/// A person is named; the partner is `nil`, so their spends marked to be paid back count too.
@MainActor @Suite struct PeopleTests {
    let oct19 = Fixtures.date(2026, 10, 19)

    func store() -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                           paid: Example.paidInOctober, today: oct19)
        return store
    }

    @Test func lendingTakesItOutOfMainAndTheyOweIt() {
        let store = store()
        store.record(.lent, Cents(5000), with: "Ben", at: oct19)
        #expect(store.ledger().balance(.main) == Cents(10000))
        #expect(store.ledger().owes("Ben") == Cents(5000))
        // The same person whatever the case or spaces.
        #expect(store.ledger().owes(" ben") == Cents(5000))
    }

    @Test func paidBackBringsItInAndOffWhatTheyOwe() {
        let store = store()
        store.record(.lent, Cents(5000), with: "Ben", at: oct19)
        store.record(.repayment, Cents(2000), with: "Ben", at: oct19)
        #expect(store.ledger().balance(.main) == Cents(12000))
        #expect(store.ledger().owes("Ben") == Cents(3000))
    }

    @Test func owedFromBeforeMovesNoMoney() {
        let store = store()
        store.record(.lent, Cents(4000), with: "Ben", before: true, at: oct19)
        #expect(store.ledger().balance(.main) == Cents(15000))
        #expect(store.ledger().owes("Ben") == Cents(4000))
        // Paid back now, it does come in.
        store.record(.repayment, Cents(4000), with: "Ben", at: oct19)
        #expect(store.ledger().balance(.main) == Cents(19000))
        #expect(store.ledger().owes("Ben") == .zero)
    }

    @Test func borrowingIsTheOtherWayRound() {
        let store = store()
        store.record(.borrowed, Cents(2000), with: "Ana", at: oct19)
        #expect(store.ledger().balance(.main) == Cents(17000))
        #expect(store.ledger().owes("Ana") == Cents(-2000))
        store.record(.paidBack, Cents(2000), with: "Ana", at: oct19)
        #expect(store.ledger().balance(.main) == Cents(15000))
        #expect(store.ledger().owes("Ana") == .zero)
        store.record(.borrowed, Cents(1500), with: "Ana", before: true, at: oct19)
        #expect(store.ledger().owes("Ana") == Cents(-1500))
        #expect(store.ledger().balance(.main) == Cents(15000))
    }

    @Test func thePartnersSpendsAndLoansAreOneBalance() {
        let store = store()
        store.logSpend(Cents(1000), category: .goingOut, note: nil, paidWith: .bank, at: oct19, partner: .half, paysBack: true)
        store.record(.lent, Cents(2000), with: nil, at: oct19)
        store.record(.repayment, Cents(500), with: nil, at: oct19)
        #expect(store.ledger().owes(nil) == Cents(2000))
        #expect(store.ledger().partnerOwes == Cents(2000))
    }

    @Test func nothingOrLessIsNeverRecorded() {
        let store = store()
        store.record(.lent, .zero, with: "Ben", at: oct19)
        store.record(.lent, Cents(-100), with: "Ben", at: oct19)
        store.record(.lent, Cents(100), with: "  ", at: oct19)
        #expect(store.ledger().people.isEmpty)
    }

    @Test func everyoneOnceTheyHaveAnythingThePartnerFirst() {
        let store = store()
        store.record(.lent, Cents(100), with: "Zoe", at: oct19)
        store.record(.borrowed, Cents(100), with: "ana", at: oct19)
        store.record(.lent, Cents(100), with: "Ana", at: oct19)
        store.record(.repayment, Cents(100), with: nil, at: oct19)
        // The first spelling of a name is the one kept.
        #expect(store.ledger().people == [nil, "ana", "Zoe"])
    }
}
