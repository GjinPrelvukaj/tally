import Testing
import Foundation
@testable import BudgetKit

/// Savings pots of the person's own: set up at the first run, then added, renamed, given a goal, retired and brought back.
@MainActor @Suite struct PotTests {
    let oct19 = Fixtures.date(2026, 10, 19)

    func store(savings: [SavingsPot]) -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUp(balances: [.main: .euros(500)], paid: [:], today: oct19, plan: [], goals: [:], savings: savings)
        return store
    }

    @Test func theFirstRunsPotsAreKeptAndCategoriesForAPotNotChosenSpendFromMain() {
        let holiday = SavingsPot(id: Pot("holiday"), name: "Holiday", colour: 4)
        let ledger = store(savings: [holiday]).ledger()
        #expect(ledger.savings == [holiday])
        #expect(ledger.pots == [.main, holiday.id, .card])
        // Clothes and Fragrance began in a clothes pot this person doesn't have.
        #expect(ledger.categories.allSatisfy { $0.pot == .main })
    }

    @Test func choosingNoSavingsPotsIsKept() {
        #expect(store(savings: []).ledger().pots == [.main, .card])
    }

    @Test func aPotIsAddedRenamedAndGivenAGoal() throws {
        let store = store(savings: [])
        let car = try #require(store.addPot("  Car "))
        #expect(store.addPot("   ") == nil)
        #expect(store.ledger().savings.map(\.name) == ["Car"])
        store.rename(car.id, to: "New car")
        store.rename(car.id, to: " ")
        #expect(store.ledger().name(car.id) == "New car")
        store.setGoal(.euros(8000), for: car.id)
        #expect(store.ledger().goals[car.id] == .euros(8000))
        store.setGoal(.zero, for: car.id)
        #expect(store.ledger().goals[car.id] == nil)
        let second = try #require(store.addPot("Gifts"))
        #expect(second.colour != car.colour)
    }

    @Test func aPotIsRetiredOnlyWhenEmptyAndItsCategoriesSpendFromMain() throws {
        let store = store(savings: [])
        let car = try #require(store.addPot("Car"))
        store.addCategory("Fuel", pot: car.id)
        store.setBalance(car.id, to: .euros(30), at: oct19)
        store.retire(car.id)
        #expect(store.ledger().pots.contains(car.id))
        store.setBalance(car.id, to: .zero, at: oct19)
        store.retire(car.id)
        #expect(!store.ledger().pots.contains(car.id))
        #expect(store.ledger().savings.first?.retired == true)
        #expect(store.ledger().categories.first { $0.name == "Fuel" }?.pot == .main)
        store.bringBack(car.id)
        #expect(store.ledger().pots.contains(car.id))
    }
}
