import Testing
import Foundation
@testable import BudgetKit

/// How often a plan item comes: every month, every few months or every year from a month, or once.
@Suite struct RepeatTests {
    func item(every: Int = 1, startsIn: YearMonth? = nil, onlyIn: YearMonth? = nil) -> PlanItem {
        PlanItem(name: "Domains", amount: Cents(1500), kind: .payment, from: .main, schedule: .day(14),
                 onlyIn: onlyIn, repeatEvery: every, startsIn: startsIn)
    }

    @Test func everyYearFromAMonthIsDueThatMonthEachYear() {
        let domains = item(every: 12, startsIn: YearMonth(2027, 3))
        #expect(domains.applies(in: YearMonth(2027, 3)))
        #expect(domains.applies(in: YearMonth(2028, 3)))
        #expect(!domains.applies(in: YearMonth(2027, 4)))
        #expect(!domains.applies(in: YearMonth(2028, 2)))
        #expect(!domains.applies(in: YearMonth(2026, 3)))
    }

    @Test func everyThreeMonths() {
        let quarterly = item(every: 3, startsIn: YearMonth(2027, 1))
        let months = (1...12).filter { quarterly.applies(in: YearMonth(2027, $0)) }
        #expect(months == [1, 4, 7, 10])
    }

    @Test func everyMonthFromAMonthIsNotDueBefore() {
        let gym = item(startsIn: YearMonth(2026, 11))
        #expect(!gym.applies(in: YearMonth(2026, 10)))
        #expect(gym.applies(in: YearMonth(2026, 11)))
        #expect(gym.applies(in: YearMonth(2027, 5)))
        // With no start it is every month, as before.
        #expect(item().applies(in: YearMonth(2020, 1)))
    }

    @Test func onceAndPausedAreAsBefore() {
        #expect(item(onlyIn: YearMonth(2026, 12)).applies(in: YearMonth(2026, 12)))
        #expect(!item(onlyIn: YearMonth(2026, 12)).applies(in: YearMonth(2027, 12)))
    }

    @Test func whatItComesToAMonth() {
        #expect(item(every: 12, startsIn: YearMonth(2027, 3)).perMonth == Cents(125))
        #expect(item().perMonth == Cents(1500))
        #expect(item(onlyIn: YearMonth(2026, 12)).perMonth == nil)
    }

    @Test func aYearlyItemIsStillToPayOnlyInItsMonth() {
        var ledger = Fixtures.oct19(main: .euros(150))
        let domains = item(every: 12, startsIn: YearMonth(2026, 11))
        ledger.plan.append(domains)
        #expect(!ledger.stillToPay(today: Fixtures.date(2026, 10, 19)).contains { $0.item.id == domains.id })
        #expect(ledger.stillToPay(today: Fixtures.date(2026, 11, 20)).contains { $0.item.id == domains.id && $0.month == YearMonth(2026, 11) })
    }

    @Test func theEditorKeepsHowOftenItComes() throws {
        let yearly = item(every: 12, startsIn: YearMonth(2027, 3))
        #expect(PlanItemDraft(yearly).item == yearly)
        var draft = PlanItemDraft(yearly)
        draft.repeats = .every(3)
        draft.repeatMonth = YearMonth(2027, 1)
        let quarterly = try #require(draft.item)
        #expect(quarterly.repeatEvery == 3 && quarterly.startsIn == YearMonth(2027, 1) && quarterly.onlyIn == nil)
        draft.repeats = .once
        let once = try #require(draft.item)
        #expect(once.onlyIn == YearMonth(2027, 1) && once.repeatEvery == 1 && once.startsIn == nil)
    }

    @Test func aNewItemStartsInTheMonthItIsAdded() throws {
        let draft = PlanItemDraft(startingIn: YearMonth(2026, 11))
        var named = draft
        named.name = "Gym"
        named.amount = "35"
        let item = try #require(named.item)
        #expect(item.startsIn == YearMonth(2026, 11))
        #expect(!item.applies(in: YearMonth(2026, 10)))
    }
}

@MainActor @Suite struct RepeatStoreTests {
    @Test func howOftenIsSaved() throws {
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUpExample(balances: [.main: Cents(15000)], paid: [:], today: Fixtures.date(2026, 10, 19))
        let domains = PlanItem(name: "Domains", amount: Cents(1500), kind: .payment, from: .main, schedule: .day(14),
                               repeatEvery: 12, startsIn: YearMonth(2027, 3))
        store.save(domains)
        #expect(store.ledger().plan.last == domains)
    }
}

/// What the plan comes to in a month, top of the Plan page: in, to savings, out, every day, and what is left over.
@Suite struct PlanSummaryTests {
    @Test func aMonthOfThePlanAddsUp() {
        let plan = [PlanItem(name: "Salary", amount: .euros(2000), kind: .income, to: .main, schedule: .day(1)),
                    PlanItem(name: "Emergency", amount: .euros(300), kind: .transfer, from: .main, to: .emergency, schedule: .anyDay),
                    PlanItem(name: "Rent", amount: .euros(700), kind: .payment, from: .main, schedule: .day(1)),
                    PlanItem(name: "Card", amount: .euros(50), kind: .transfer, from: .main, to: .card, schedule: .anyDay),
                    PlanItem(name: "Domains", amount: .euros(15), kind: .payment, from: .main, schedule: .day(14),
                             repeatEvery: 12, startsIn: YearMonth(2027, 3)),
                    PlanItem(name: "Old", amount: .euros(99), kind: .payment, from: .main, schedule: .anyDay, paused: true),
                    PlanItem(name: "Daily life", amount: .euros(20), kind: .daily, from: .main, schedule: .anyDay)]
        let ledger = Ledger(start: [:], startMonth: YearMonth(2026, 10), plan: plan, entries: [], calendar: Fixtures.calendar)
        let october = ledger.planSummary(for: YearMonth(2026, 10))
        // 31 days of 20; the card's pay-off goes out; the yearly domains aren't due in October.
        #expect(october == PlanSummary(comesIn: .euros(2000), toSavings: .euros(300), goesOut: .euros(750), everyDay: .euros(620),
                                       left: .euros(330)))
        #expect(ledger.planSummary(for: YearMonth(2027, 3)).goesOut == .euros(765))
    }
}
