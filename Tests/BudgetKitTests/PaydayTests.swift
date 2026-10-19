import Testing
@testable import BudgetKit

@Suite struct PaydayTests {
    @Test func whatIsLeftInMainIsTheIncomeLessTheSplit() {
        #expect(Payday.leftInMain(income: .euros(650), split: [.euros(120), .euros(80), Cents(6340)]) == Cents(38660))
        #expect(Payday.leftInMain(income: .euros(650), split: []) == .euros(650))
        #expect(Payday.leftInMain(income: .euros(100), split: [.euros(250)]) == Cents(-15000))
    }

    @Test func paydayDraftLeavesTheRestInMain() {
        let plan = Example.plan
        let split = plan.filter { [Example.ID.emergencyExtra, Example.ID.clothesPot, Example.ID.card].contains($0.id) }
        var draft = PaydayDraft(income: plan[3], split: split)
        #expect(draft.amount == "650,00")
        // 650 − 120 − 80 − 63,40
        #expect(draft.left == Cents(38660))
        draft.typed[Example.ID.clothesPot] = "30"
        #expect(draft.left == Cents(43660))
        #expect(draft.split?[Example.ID.clothesPot] == Cents(3000))
    }

    @Test func aTypoStopsThePayday() {
        var draft = PaydayDraft(income: Example.plan[3], split: [Example.plan[6]])
        draft.typed[Example.ID.emergencyExtra] = "2o0"
        #expect(draft.split == nil)
        #expect(draft.left == nil)
        draft.typed[Example.ID.emergencyExtra] = "200"
        draft.amount = ""
        #expect(draft.left == nil)
    }

    @Test func aZeroIncomeCannotBeAdded() {
        var draft = PaydayDraft(income: Example.plan[3], split: [Example.plan[6]])
        #expect(draft.canAdd)
        draft.amount = "0"
        #expect(!draft.canAdd)
        draft.amount = "650"
        draft.typed[Example.ID.emergencyExtra] = "0"
        #expect(draft.canAdd)
    }
}
