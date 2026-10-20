import Testing
import Foundation
@testable import BudgetKit

/// Every entry keeps the time it happened: shown beside its day, and changed in the editor for a spend logged later.
@MainActor @Suite struct EntryTimeTests {
    let calendar = Fixtures.calendar

    @Test func aTimeReadsAsTypedAndIsWrittenByHand() {
        #expect(TimeOfDay("18:13") == TimeOfDay(hour: 18, minute: 13))
        #expect(TimeOfDay(" 9:05 ") == TimeOfDay(hour: 9, minute: 5))
        #expect(TimeOfDay("9.05") == TimeOfDay(hour: 9, minute: 5))
        #expect(TimeOfDay("0:00") == TimeOfDay(hour: 0, minute: 0))
        for wrong in ["24:00", "18:60", "18", "18:5", "ab:cd", "", "18:13:00", "-1:30"] { #expect(TimeOfDay(wrong) == nil) }
        #expect(TimeOfDay(hour: 9, minute: 5).formatted == "09:05")
        #expect(TimeOfDay(Fixtures.date(2026, 10, 19, hour: 18).addingTimeInterval(13 * 60), calendar: calendar).formatted == "18:13")
    }

    @Test func aSpendsTimeCanBeChangedOnItsDay() throws {
        let store = Store(inMemory: true, calendar: calendar)
        store.setUp(balances: [.main: .euros(100)], paid: [:], today: Fixtures.date(2026, 10, 19, hour: 9), plan: [], goals: [:])
        store.logSpend(Cents(510), category: .food, note: nil, paidWith: .bank, at: Fixtures.date(2026, 10, 19, hour: 20))
        var draft = EntryDraft(try #require(store.ledger().entries.last), ledger: store.ledger())
        #expect(draft.time == "20:00")
        draft.time = "13:45"
        let entry = try #require(draft.entry)
        #expect(calendar.isDate(entry.date, inSameDayAs: Fixtures.date(2026, 10, 19)))
        #expect(TimeOfDay(entry.date, calendar: calendar) == TimeOfDay(hour: 13, minute: 45))
        draft.time = "25:00"
        #expect(draft.entry == nil)
    }

    /// Moved to after a balance set by hand, a spend no longer counted before it: the set balance takes it up, so the pot
    /// still shows what was set, and the spend now counts after it.
    @Test func movingASpendPastASetBalanceKeepsTheSetBalance() throws {
        let store = Store(inMemory: true, calendar: calendar)
        store.setUp(balances: [.main: .euros(100)], paid: [:], today: Fixtures.date(2026, 10, 19, hour: 9), plan: [], goals: [:])
        store.logSpend(Cents(510), category: .food, note: nil, paidWith: .bank, at: Fixtures.date(2026, 10, 19, hour: 12))
        store.setBalance(.main, to: .euros(90), at: Fixtures.date(2026, 10, 19, hour: 14))
        var spend = try #require(store.ledger().entries.first { $0.kind == .spend })
        spend.date = Fixtures.date(2026, 10, 19, hour: 16)
        store.update(spend)
        // 90 set at 14:00, and the 5,10 now spent after it.
        #expect(store.ledger().balance(.main) == Cents(8490))
        #expect(store.ledger().balance(.main, endOf: Fixtures.date(2026, 10, 19, hour: 15)) == Cents(8490))
        // And back before it again: 90 once more.
        spend.date = Fixtures.date(2026, 10, 19, hour: 11)
        store.update(spend)
        #expect(store.ledger().balance(.main) == .euros(90))
    }
}
