import Testing
@testable import BudgetKit

@Suite struct PlanEditingTests {
    @Test func theSeededPlanFallsIntoFourGroups() {
        func names(_ group: PlanGroup) -> [String] { Example.plan.filter { $0.group == group }.map(\.name) }
        #expect(names(.comesIn) == ["Salary", "Side job"])
        #expect(names(.savings) == ["Emergency fund", "Extra to emergency fund", "Clothes pot"])
        // Paying off the card is money going out, not saving.
        #expect(names(.goesOut) == ["Course", "Bills", "Groceries", "Gym", "Credit card"])
        #expect(names(.everyDay) == ["Daily life"])
    }

    @Test func everyPlanItemSurvivesTheEditor() {
        for item in Example.plan {
            #expect(PlanItemDraft(item).item == item, "\(item.name)")
        }
    }

    @Test func editingChangesOnlyWhatWasTyped() throws {
        var draft = PlanItemDraft(Example.plan[4])
        draft.amount = "120,50"
        draft.when = .day
        draft.day = 5
        draft.repeats = .once
        draft.repeatMonth = YearMonth(2026, 11)
        draft.paused = true
        let item = try #require(draft.item)
        #expect(item.id == Example.ID.bills)
        #expect(item.amount == Cents(12050))
        #expect(item.schedule == .day(5))
        #expect(item.onlyIn == YearMonth(2026, 11))
        #expect(item.paused)
        #expect(item.from == .main)
    }

    @Test func anItemNeedsANameAnAmountAndAWhen() {
        var draft = PlanItemDraft(startingIn: YearMonth(2026, 10))
        #expect(draft.item == nil)
        draft.name = "Gym"
        #expect(draft.item == nil)
        draft.amount = "2o"
        #expect(draft.item == nil)
        draft.amount = "20"
        #expect(draft.item?.kind == .payment)
        draft.when = .withIncome
        #expect(draft.item == nil)
        draft.income = Example.ID.salary
        #expect(draft.item?.schedule == .withIncome(Example.ID.salary))
        draft.when = .window
        draft.windowFrom = 20
        draft.windowTo = 10
        #expect(draft.item == nil)
    }

    @Test func changingWhatItIsPicksSensiblePots() throws {
        var draft = PlanItemDraft(startingIn: YearMonth(2026, 10))
        draft.name = "Side job"
        draft.amount = "100"
        draft.kind = .income
        #expect(try #require(draft.item).to == .main)
        #expect(try #require(draft.item).from == nil)
        draft.kind = .transfer
        let transfer = try #require(draft.item)
        #expect(transfer.from == .main && transfer.to != nil && transfer.to != .main)
        draft.kind = .daily
        #expect(try #require(draft.item).schedule == .anyDay)
    }
}
