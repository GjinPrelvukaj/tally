import Testing
import Foundation
@testable import BudgetKit

@MainActor @Suite struct DemoTests {
    @Test func demoIsAMadeUpNineteenthOfOctober() {
        let demo = Store.demo(afterPayday: false, calendar: Fixtures.calendar)
        #expect(demo.today == Fixtures.date(2026, 10, 19))
        let ledger = demo.store.ledger()
        #expect(ledger.balance(.main) == .euros(640))
        #expect(ledger.balance(.card) == .euros(-45))
        #expect(ledger.isDone(Seed.ID.rent, in: YearMonth(2026, 10)))
        // 640 less the gym still to pay, over the 13 days to the 1st.
        #expect(ledger.allowance(today: demo.today)?.perDay == Cents(4653))
    }

    @Test func paydayDueWaitsOnTheFirst() {
        let demo = Store.demo(afterPayday: false, paydayDue: true, calendar: Fixtures.calendar)
        #expect(demo.today == Fixtures.date(2026, 11, 1))
        #expect(demo.store.ledger().stillToPay(today: demo.today).contains { $0.isIncome && $0.item.id == Seed.ID.salary })
    }

    @Test func afterPaydayTheSalaryIsSplit() {
        let demo = Store.demo(afterPayday: true, calendar: Fixtures.calendar)
        let ledger = demo.store.ledger()
        // 640 + 2 000 − 700 rent − 150 bills − 300 emergency − 100 clothes pot.
        #expect(ledger.balance(.main) == .euros(1390))
        #expect(ledger.balance(.emergency) == .euros(2450))
    }
}

@Suite struct ScreenTests {
    @Test func sixSectionsInTheSidebarsOrder() {
        #expect(Screen.allCases == [.today, .pots, .month, .insights, .entries, .plan])
        // ⌘1 to ⌘6.
        #expect(Screen.allCases.map(\.key) == ["1", "2", "3", "4", "5", "6"])
    }

    @Test func namedFromTheCommandLine() {
        #expect(Screen(named: "pots") == .pots)
        #expect(Screen(named: "month") == .month)
        #expect(Screen(named: "entries") == .entries)
        #expect(Screen(named: "plan") == .plan)
        #expect(Screen(named: "insights") == .insights)
        #expect(Screen(named: "payday") == nil)
    }

    @Test func aDaySaysItsNameInEnglish() {
        #expect(dayTitle(Fixtures.date(2026, 10, 19), calendar: Fixtures.calendar) == "Monday 19 October")
        #expect(dayTitle(Fixtures.date(2026, 11, 1), calendar: Fixtures.calendar) == "Sunday 1 November")
    }
}
