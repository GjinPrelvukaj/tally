import Testing
import Foundation
@testable import BudgetKit

@MainActor @Suite struct StoreTests {
    let oct19 = Fixtures.date(2026, 10, 19)
    let oct20 = Fixtures.date(2026, 10, 20)

    /// A store set up the way the first run does it on 19 October.
    func firstRun() -> Store {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                    paid: Example.paidInOctober, today: oct19)
        return store
    }

    /// Quick log starts on the category of the newest spend, so it is the same after Tally is reopened, and Undo takes it back.
    @Test func theLastCategoryIsTheNewestSpends() {
        let store = firstRun()
        #expect(store.ledger().lastSpendCategory == nil)
        store.logSpend(Cents(510), category: .goingOut, note: nil, paidWith: .bank, at: Fixtures.date(2026, 10, 19, hour: 18))
        store.logSpend(Cents(390), category: .food, note: nil, paidWith: .card, at: Fixtures.date(2026, 10, 19, hour: 9))
        // By when it happened, not when it was typed.
        #expect(store.ledger().lastSpendCategory == "goingOut")
        store.logSpend(Cents(800), category: .other, note: nil, paidWith: .cash, at: Fixtures.date(2026, 10, 19, hour: 20))
        #expect(store.ledger().lastSpendCategory == "other")
        store.undo()
        #expect(store.ledger().lastSpendCategory == "goingOut")
    }

    /// Everything waiting on the second job, at the planned amounts.
    func defaultSplit(_ store: Store) -> [UUID: Cents] {
        let waiting = store.ledger().stillToPay(today: oct20).filter { $0.item.schedule == .withIncome(Example.ID.second) }
        return Dictionary(uniqueKeysWithValues: waiting.map { ($0.item.id, $0.item.amount) })
    }

    func payday(_ store: Store) throws {
        let income = try #require(store.ledger().stillToPay(today: oct20).first { $0.item.id == Example.ID.second })
        store.payday(income, amount: .euros(650), split: defaultSplit(store), at: oct20)
    }

    @Test func setUpSeedsPlanAndState() throws {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        #expect(!store.isSetUp)
        store.setUpExample(balances: [.main: Cents(15000), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)],
                    paid: Example.paidInOctober, today: oct19)
        #expect(store.isSetUp)
        let ledger = store.ledger()
        #expect(ledger.plan == Example.plan)
        #expect(ledger.balance(.main) == Cents(15000))
        #expect(try #require(ledger.allowance(today: oct19)).perDay == Cents(10500))
        #expect(store.ledger().goals[.emergency] == Cents(500000))
        #expect(store.ledger().goals[.main] == nil)
    }

    @Test func paydayRecordsIncomeAndSplit() throws {
        let store = firstRun()
        try payday(store)
        let ledger = store.ledger()
        #expect(ledger.balance(.main) == Cents(53660))
        #expect(ledger.balance(.emergency) == Cents(143250))
        #expect(ledger.balance(.clothes) == Cents(8000))
        #expect(ledger.balance(.card) == .zero)
    }

    @Test func spendOnClothesComesFromClothesPot() throws {
        let store = firstRun()
        try payday(store)
        store.logSpend(Cents(6000), category: .fragrance, note: nil, paidWith: .bank, at: oct20)
        let ledger = store.ledger()
        #expect(ledger.balance(.clothes) == Cents(2000))
        #expect(ledger.balance(.main) == Cents(53660))
    }

    @Test func aLoggedSpendLowersWhatHeCanSpendEachDay() throws {
        let store = firstRun()
        let before = try #require(store.ledger().allowance(today: oct19)).perDay
        store.logSpend(.euros(20), category: .food, note: nil, paidWith: .bank, at: oct19)
        let after = try #require(store.ledger().allowance(today: oct19)).perDay
        #expect(after < before)
    }

    @Test func spendOnCardGrowsDebt() {
        let store = firstRun()
        store.logSpend(Cents(2000), category: .food, note: " lunch ", paidWith: .card, at: oct19)
        #expect(store.ledger().balance(.card) == Cents(-8340))
        #expect(store.ledger().balance(.main) == Cents(15000))
        #expect(store.ledger().entries.last?.note == "lunch")
    }

    @Test func markPaidMovesMoneyByKind() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .euros(45), at: oct19)
        #expect(store.ledger().balance(.main) == .euros(105))
        #expect(store.ledger().isDone(Example.ID.gym, in: Example.october))
    }

    @Test func dismissMarksDoneWithoutMovingMoney() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.dismiss(due, at: oct19)
        #expect(store.ledger().isDone(Example.ID.gym, in: Example.october))
        #expect(store.ledger().balance(.main) == Cents(15000))
    }

    @Test func markingPaidTwiceRecordsOnce() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .euros(45), at: oct19)
        store.markPaid(due, amount: .euros(45), at: oct19)
        #expect(store.ledger().balance(.main) == .euros(105))
        #expect(store.ledger().entries.filter { $0.planItem == Example.ID.gym }.count == 1)
    }

    @Test func dismissingTwiceRecordsOnce() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.dismiss(due, at: oct19)
        store.dismiss(due, at: oct19)
        store.markPaid(due, amount: .euros(45), at: oct19)
        #expect(store.ledger().entries.filter { $0.planItem == Example.ID.gym }.count == 1)
        #expect(store.ledger().balance(.main) == Cents(15000))
    }

    @Test func paydayTwiceRecordsOnce() throws {
        let store = firstRun()
        let income = try #require(store.ledger().stillToPay(today: oct20).first { $0.item.id == Example.ID.second })
        let split = defaultSplit(store)
        store.payday(income, amount: .euros(650), split: split, at: oct20)
        let entries = store.ledger().entries.count
        store.payday(income, amount: .euros(650), split: split, at: oct20)
        #expect(store.ledger().entries.count == entries)
        #expect(store.ledger().balance(.main) == Cents(53660))
    }

    @Test func paydayNeverPaysAnAlreadyPaidItemAgain() throws {
        let store = firstRun()
        let card = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.card })
        let split = defaultSplit(store)
        store.markPaid(card, amount: Cents(6340), at: oct19)
        let income = try #require(store.ledger().stillToPay(today: oct20).first { $0.item.id == Example.ID.second })
        store.payday(income, amount: .euros(650), split: split, at: oct20)
        #expect(store.ledger().entries.filter { $0.planItem == Example.ID.card }.count == 1)
        #expect(store.ledger().balance(.main) == Cents(53660))
        #expect(store.ledger().balance(.card) == .zero)
    }

    @Test func setBalanceRecordsAdjustment() {
        let store = firstRun()
        store.setBalance(.main, to: .euros(140), at: oct19)
        let adjustments = store.ledger().entries.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments.first?.amount == Cents(-1000))
        #expect(store.ledger().balance(.main) == .euros(140))
    }

    @Test func deletingPlanItemKeepsEntries() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .euros(45), at: oct19)
        let entries = store.ledger().entries.count
        store.delete(Example.ID.gym)
        #expect(store.ledger().plan.contains { $0.id == Example.ID.gym } == false)
        #expect(store.ledger().balance(.main) == .euros(105))
        #expect(store.ledger().entries.count == entries)
    }

    @Test func deletingAnIncomeLetsWhatWaitedForItBecomeAnyDay() {
        let store = firstRun()
        #expect(store.ledger().waiting(on: Example.ID.second).count == 5)
        store.delete(Example.ID.second)
        let plan = store.ledger().plan
        #expect(plan.contains { $0.id == Example.ID.second } == false)
        for id in [Example.ID.bills, Example.ID.groceries, Example.ID.emergencyExtra, Example.ID.clothesPot, Example.ID.card] {
            #expect(plan.first { $0.id == id }?.schedule == .anyDay)
        }
        // What waited for the other income is untouched.
        #expect(plan.first { $0.id == Example.ID.course }?.schedule == .withIncome(Example.ID.salary))
        #expect(store.ledger().waiting(on: Example.ID.second).isEmpty)
    }

    @Test func nolongerBeingAnIncomeDoesTheSame() throws {
        let store = firstRun()
        var second = try #require(store.ledger().plan.first { $0.id == Example.ID.second })
        second.kind = .payment
        second.from = .main
        second.to = nil
        store.save(second)
        #expect(store.ledger().plan.first { $0.id == Example.ID.bills }?.schedule == .anyDay)
        #expect(store.ledger().plan.first { $0.id == Example.ID.second }?.kind == .payment)
        // Editing only an amount leaves the waiting items alone.
        var salary = try #require(store.ledger().plan.first { $0.id == Example.ID.salary })
        salary.amount = .euros(1300)
        store.save(salary)
        #expect(store.ledger().plan.first { $0.id == Example.ID.course }?.schedule == .withIncome(Example.ID.salary))
    }

    @Test func settingTheCardsBalanceTakesWhatHeOwesAsADebt() {
        let store = firstRun()
        // Typed as owing 120: the card is kept at −120, and the adjustment is the −56,60 more.
        store.setBalance(.card, to: Pot.card.balance(fromFigure: .euros(120)), at: oct19)
        #expect(store.ledger().balance(.card) == .euros(-120))
        #expect(store.ledger().entries.last?.amount == Cents(-5660))
        // The field starts from what is owed.
        #expect(Pot.card.figure(for: store.ledger().balance(.card)) == .euros(120))
    }

    @Test func savingEditsKeepsPlaceAndAddsNewAtEnd() throws {
        let store = firstRun()
        var gym = try #require(store.ledger().plan.first { $0.id == Example.ID.gym })
        gym.amount = .euros(60)
        store.save(gym)
        let extra = PlanItem(name: "Phone", amount: .euros(20), kind: .payment, from: .main, schedule: .day(5))
        store.save(extra)
        let plan = store.ledger().plan
        #expect(plan.map(\.id) == Example.plan.map(\.id) + [extra.id])
        #expect(plan.first { $0.id == Example.ID.gym }?.amount == .euros(60))
    }

    @Test func revisionGoesUpWithEveryAction() {
        let store = firstRun()
        let before = store.revision
        store.logSpend(Cents(100), category: .other, note: nil, paidWith: .bank, at: oct19)
        #expect(store.revision > before)
    }

    @Test func survivesReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Budget.store")
        do {
            let store = try Store(url: url, calendar: Fixtures.calendar)
            store.setUpExample(balances: [.main: Cents(15000)], paid: Example.paidInOctober, today: oct19)
            store.logSpend(Cents(1000), category: .food, note: nil, paidWith: .bank, at: oct19)
        }
        let reopened = try Store(url: url, calendar: Fixtures.calendar)
        #expect(reopened.isSetUp)
        #expect(reopened.ledger().balance(.main) == Cents(14000))
        #expect(reopened.ledger().plan == Example.plan)
    }

    @Test func settingUpAgainOnAReopenedStoreChangesNothing() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Budget.store")
        do {
            let store = try Store(url: url, calendar: Fixtures.calendar)
            store.setUpExample(balances: [.main: Cents(15000)], paid: Example.paidInOctober, today: oct19)
            var gym = try #require(store.ledger().plan.first { $0.id == Example.ID.gym })
            gym.amount = .euros(60)
            store.save(gym)
        }
        let reopened = try Store(url: url, calendar: Fixtures.calendar)
        let before = reopened.ledger()
        reopened.setUpExample(balances: [.main: Cents(99999)], paid: Example.paidInOctober, today: oct20)
        let after = reopened.ledger()
        #expect(after.plan == before.plan)
        #expect(after.plan.first { $0.id == Example.ID.gym }?.amount == .euros(60))
        #expect(after.entries.count == before.entries.count)
        #expect(after.balance(.main) == Cents(15000))
        #expect(after.startMonth == Example.october)
        #expect(reopened.loadError == nil)
    }

    // MARK: Undo, zero amounts

    @Test func undoingMarkPaidMakesItDueAgainAndRestoresBalances() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .euros(45), at: oct19)
        #expect(store.canUndo)
        store.undo()
        let ledger = store.ledger()
        #expect(ledger.balance(.main) == Cents(15000))
        #expect(ledger.stillToPay(today: oct19).contains { $0.item.id == Example.ID.gym })
        #expect(ledger.allowance(today: oct19)?.perDay == Cents(10500))
        #expect(!store.canUndo)
    }

    @Test func undoingPaydayRestoresEverything() throws {
        let store = firstRun()
        let before = store.ledger().entries.count
        try payday(store)
        store.undo()
        let ledger = store.ledger()
        #expect(ledger.entries.count == before)
        #expect(ledger.balance(.main) == Cents(15000))
        #expect(ledger.balance(.emergency) == Cents(131250))
        #expect(ledger.balance(.card) == Cents(-6340))
        #expect(ledger.stillToPay(today: oct20).contains { $0.item.id == Example.ID.second })
    }

    @Test func undoingASpendDismissAndBalanceChange() throws {
        let store = firstRun()
        store.logSpend(.euros(20), category: .food, note: nil, paidWith: .bank, at: oct19)
        store.undo()
        #expect(store.ledger().balance(.main) == Cents(15000))
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.dismiss(due, at: oct19)
        store.undo()
        #expect(!store.ledger().isDone(Example.ID.gym, in: Example.october))
        store.setBalance(.main, to: .euros(140), at: oct19)
        store.undo()
        #expect(store.ledger().balance(.main) == Cents(15000))
    }

    @Test func onlyTheLastActionIsUndoneAndOnlyOnce() {
        let store = firstRun()
        store.logSpend(.euros(10), category: .food, note: nil, paidWith: .bank, at: oct19)
        store.logSpend(.euros(5), category: .food, note: nil, paidWith: .bank, at: oct19)
        store.undo()
        #expect(store.ledger().balance(.main) == Cents(14000))
        store.undo()
        #expect(store.ledger().balance(.main) == Cents(14000))
    }

    @Test func aRefusedActionLeavesTheLastOneUndoable() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .euros(45), at: oct19)
        store.markPaid(due, amount: .euros(45), at: oct19)
        store.undo()
        #expect(!store.ledger().isDone(Example.ID.gym, in: Example.october))
    }

    @Test func aZeroNeverCountsAsPaidOrSpent() throws {
        let store = firstRun()
        let due = try #require(store.ledger().stillToPay(today: oct19).first { $0.item.id == Example.ID.gym })
        store.markPaid(due, amount: .zero, at: oct19)
        store.logSpend(.zero, category: .food, note: nil, paidWith: .bank, at: oct19)
        #expect(store.ledger().isDone(Example.ID.gym, in: Example.october) == false)
        #expect(store.ledger().entries.count == Example.paidInOctober.count)
    }

    @Test func paydaySkipsSplitItemsAtZeroAndTheyStayDueAndHeldBack() throws {
        let store = firstRun()
        let income = try #require(store.ledger().stillToPay(today: oct20).first { $0.item.id == Example.ID.second })
        var split = defaultSplit(store)
        split[Example.ID.clothesPot] = .zero
        store.payday(income, amount: .euros(650), split: split, at: oct20)
        let ledger = store.ledger()
        #expect(ledger.isDone(Example.ID.second, in: Example.october))
        #expect(!ledger.isDone(Example.ID.clothesPot, in: Example.october))
        #expect(ledger.balance(.clothes) == .zero)
        #expect(ledger.stillToPay(today: oct20).first { $0.item.id == Example.ID.clothesPot }?.heldBack == true)
    }

    @Test func aZeroIncomeIsNotRecorded() throws {
        let store = firstRun()
        let income = try #require(store.ledger().stillToPay(today: oct20).first { $0.item.id == Example.ID.second })
        store.payday(income, amount: .zero, split: defaultSplit(store), at: oct20)
        #expect(!store.ledger().isDone(Example.ID.second, in: Example.october))
    }
}
