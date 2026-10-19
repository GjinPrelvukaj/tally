import Testing
import Foundation
@testable import BudgetKit

/// Paying off the card asks for what is owed now, not the amount once written in the plan.
@Suite struct CardPayoffTests {
    let today = Fixtures.date(2026, 10, 19)

    func ledger(owed: Cents, plan: [PlanItem] = Fixtures.plan) -> Ledger {
        var l = Fixtures.oct19(main: .euros(150))
        l.start[.card] = .zero - owed
        l.plan = plan
        return l
    }

    func cardDues(_ ledger: Ledger, today: Date) -> [Due] {
        ledger.stillToPay(today: today).filter { $0.item.id == Fixtures.card }
    }

    @Test func theCardRowAsksForWhatIsOwed() {
        #expect(cardDues(ledger(owed: Cents(430)), today: today).map(\.item.amount) == [Cents(430)])
    }

    @Test func nothingOwedNothingToPay() {
        #expect(cardDues(ledger(owed: .zero), today: today).isEmpty)
        // A card in credit owes nothing either.
        #expect(cardDues(ledger(owed: Cents(-500)), today: today).isEmpty)
    }

    @Test func theIncomesSplitPaysWhatIsOwed() throws {
        let l = ledger(owed: Cents(430))
        let income = try #require(l.stillToPay(today: today).first { $0.item.id == Fixtures.second })
        #expect(l.split(of: income).first { $0.id == Fixtures.card }?.amount == Cents(430))
    }

    @Test func theAllowanceHoldsBackWhatIsOwed() throws {
        // The card waits for the side job, so once that has come its pay-off is held back out of Main.
        var small = ledger(owed: Cents(430))
        var large = ledger(owed: Cents(6340))
        for i in [0, 1] {
            let entry = Entry(date: today, amount: .zero, kind: .income, planItem: Fixtures.second, forMonth: Fixtures.october, movesMoney: false)
            if i == 0 { small.entries.append(entry) } else { large.entries.append(entry) }
        }
        let a = try #require(small.allowance(today: today)).perDay
        let b = try #require(large.allowance(today: today)).perDay
        #expect(a > b)
    }

    @Test func whatIsOwedNowCoversEarlierMonths() {
        // Every month, not only October: October left unpaid is not asked for again in November.
        let plan = Fixtures.plan.map { $0.id == Fixtures.card ? PlanItem(id: $0.id, name: $0.name, amount: $0.amount, kind: $0.kind,
                                                                         from: $0.from, to: $0.to, schedule: .anyDay) : $0 }
        let dues = cardDues(ledger(owed: Cents(430), plan: plan), today: Fixtures.date(2026, 11, 3))
        #expect(dues.map(\.month) == [YearMonth(2026, 11)])
        #expect(dues.map(\.item.amount) == [Cents(430)])
    }
}
