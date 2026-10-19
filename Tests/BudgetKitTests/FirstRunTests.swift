import Testing
@testable import BudgetKit

/// The first run builds the person's own plan from what they type: nothing of the starter plan.
@Suite struct FirstRunTests {
    private let october = YearMonth(2026, 10)

    @Test func nothingTypedIsAnEmptyPlanAndEmptyPots() {
        let draft = FirstRunDraft(month: october)
        #expect(draft.plan == [])
        #expect(draft.goals == [:])
        #expect(draft.balances == [.main: .zero, .clothes: .zero, .emergency: .zero, .card: .zero])
        #expect(draft.items.isEmpty)
    }

    @Test func theIncomeAndCostsBecomeThePlan() throws {
        var draft = FirstRunDraft(month: october)
        draft.incomeAmount = "1 800"
        draft.incomeDay = 25
        draft.addCost("Rent")
        draft.costs[0].amount = "650"
        draft.addCost("Phone")
        draft.costs[1].amount = "20"
        draft.costs[1].day = 12
        let plan = try #require(draft.plan)
        #expect(plan.map(\.name) == ["Salary", "Rent", "Phone"])
        let salary = plan[0]
        #expect(salary.kind == .income && salary.to == .main && salary.schedule == .day(25) && salary.amount == .euros(1800))
        // No day: paid when the pay comes.
        #expect(plan[1].kind == .payment && plan[1].from == .main && plan[1].schedule == .withIncome(salary.id))
        #expect(plan[2].schedule == .day(12))
        // The same ids every time, so ticks stay on their items.
        #expect(draft.plan?.map(\.id) == plan.map(\.id))
    }

    @Test func aYearlyCostComesInItsMonthFromNowOn() throws {
        var draft = FirstRunDraft(month: october)
        draft.addCost("Domain")
        draft.costs[0].amount = "15"
        draft.costs[0].yearly = true
        draft.costs[0].inMonth = 3
        draft.addCost("Insurance")
        draft.costs[1].amount = "240"
        draft.costs[1].yearly = true
        draft.costs[1].inMonth = 10
        let plan = try #require(draft.plan)
        #expect(plan[0].repeatEvery == 12 && plan[0].startsIn == YearMonth(2027, 3))
        #expect(plan[1].startsIn == october)
        #expect(draft.items.map(\.name) == ["Insurance"])
    }

    @Test func withNoIncomeACostWithoutADayIsAnyDay() {
        var draft = FirstRunDraft(month: october)
        draft.addCost("Gym")
        draft.costs[0].amount = "35"
        #expect(draft.plan?.first?.schedule == .anyDay)
    }

    @Test func savingsTheGoalAndEveryDay() throws {
        var draft = FirstRunDraft(month: october)
        draft.incomeAmount = "2000"
        draft.toEmergency = "300"
        draft.toClothes = ""
        draft.goal = "6 000"
        draft.daily = "15"
        let plan = try #require(draft.plan)
        let saving = try #require(plan.first { $0.kind == .transfer })
        #expect(saving.from == .main && saving.to == .emergency && saving.amount == .euros(300))
        #expect(saving.schedule == .withIncome(plan[0].id))
        #expect(!plan.contains { $0.to == .clothes })
        #expect(plan.last?.kind == .daily && plan.last?.amount == .euros(15))
        #expect(draft.goals == [.emergency: .euros(6000)])
    }

    @Test func aTypoOrANamelessCostStopsIt() {
        var draft = FirstRunDraft(month: october)
        draft.incomeAmount = "2ooo"
        #expect(draft.plan == nil)
        draft.incomeAmount = "2000"
        draft.addCost("")
        draft.addCost("Gym")
        // A cost left without an amount is ignored.
        #expect(draft.plan?.count == 1)
        draft.costs[0].amount = "40"
        #expect(draft.plan == nil)
        draft.costs[0].name = "Bills"
        #expect(draft.plan != nil)
        draft.goal = "lots"
        #expect(draft.goals == nil)
    }

    @Test func theCardIsTypedAsWhatIsOwedAndAnEmptyPotIsZero() {
        var draft = FirstRunDraft(month: october)
        draft.typed[.card] = "63,40"
        draft.typed[.main] = "150"
        #expect(draft.balances?[.card] == Cents(-6340))
        #expect(draft.balances?[.main] == .euros(150))
        #expect(draft.balances?[.clothes] == .zero)
        draft.typed[.clothes] = "1o"
        #expect(draft.balances == nil)
    }

    @Test func whatHasPassedThisMonthStartsTicked() throws {
        var draft = FirstRunDraft(month: october)
        draft.incomeAmount = "2000"
        draft.addCost("Rent")
        draft.costs[0].amount = "700"
        draft.addCost("Phone")
        draft.costs[1].amount = "20"
        draft.costs[1].day = 25
        draft.toEmergency = "300"
        draft.daily = "20"
        draft.tickWhatHasPassed(today: 19)
        let plan = try #require(draft.plan)
        // The pay on the 1st has come, and what goes with it; the phone on the 25th hasn't. The daily amount is never listed.
        #expect(draft.paid == Set([plan[0].id, plan[1].id, plan[3].id]))
        #expect(!draft.items.contains { $0.kind == .daily })
        #expect(draft.paidAmounts?[plan[1].id] == .euros(700))
        draft.amounts[plan[1].id] = "650"
        #expect(draft.paidAmounts?[plan[1].id] == .euros(650))
        draft.amounts[plan[1].id] = "6s0"
        #expect(draft.paidAmounts == nil)
    }

    @MainActor @Test func aNewPersonLandsOnATodayThatMakesSense() throws {
        var draft = FirstRunDraft(month: october)
        draft.incomeAmount = "2000"
        draft.addCost("Rent")
        draft.costs[0].amount = "700"
        draft.daily = "20"
        draft.typed[.main] = "1 300"
        draft.tickWhatHasPassed(today: 19)
        let today = Fixtures.date(2026, 10, 19)
        let store = Store(inMemory: true, calendar: Fixtures.calendar)
        store.setUp(balances: try #require(draft.balances), paid: try #require(draft.paidAmounts), today: today,
                    plan: try #require(draft.plan), goals: try #require(draft.goals))
        let ledger = store.ledger()
        #expect(ledger.stillToPay(today: today).isEmpty)
        #expect(ledger.balance(.main) == .euros(1300))
        // 1 300 € over the 13 days to the next pay on 1 November.
        let allowance = try #require(ledger.allowance(today: today))
        #expect(allowance.days == 13 && allowance.perDay == Cents(10000))
    }
}
