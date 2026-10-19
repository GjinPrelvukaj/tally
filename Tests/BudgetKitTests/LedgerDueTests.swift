import Testing
import Foundation
@testable import BudgetKit

@Suite struct LedgerDueTests {
    let today = Fixtures.date(2026, 10, 19)
    let ledger = Fixtures.oct19(main: .euros(150))

    private func entry(_ kind: EntryKind, _ item: UUID, month: YearMonth = Fixtures.october, movesMoney: Bool = true) -> Entry {
        Entry(date: today, amount: Cents(1), kind: kind, planItem: item, forMonth: month, movesMoney: movesMoney)
    }

    @Test func octoberStillToPay() {
        let due = ledger.stillToPay(today: today)
        #expect(due.map(\.item.id) == [Fixtures.second, Fixtures.emergencyExtra, Fixtures.clothesPot, Fixtures.gym, Fixtures.card])
        #expect(due.filter(\.heldBack).map(\.item.id) == [Fixtures.gym])
        #expect(due.first?.isIncome == true)
    }

    @Test func paymentMarksDoneWhateverTheAmount() {
        // Bills were paid 52,00 against a planned 140,00.
        #expect(ledger.isDone(Fixtures.bills, in: Fixtures.october))
        #expect(!ledger.isDone(Fixtures.gym, in: Fixtures.october))
    }

    @Test func paydayHoldsBackItsSplit() {
        var paid = ledger
        paid.entries.append(entry(.income, Fixtures.second))
        let held = paid.stillToPay(today: today).filter(\.heldBack).map(\.item.id)
        #expect(held == [Fixtures.emergencyExtra, Fixtures.clothesPot, Fixtures.gym, Fixtures.card])
    }

    @Test func unpaidCarriesOver() {
        let due = ledger.stillToPay(today: Fixtures.date(2026, 11, 3))
        let gym = due.filter { $0.item.id == Fixtures.gym }.map(\.month)
        #expect(gym == [Fixtures.october, YearMonth(2026, 11)])
        #expect(due.filter { $0.item.id == Fixtures.card }.map(\.month) == [Fixtures.october])
        #expect(due.first { $0.item.id == Fixtures.salary }?.month == YearMonth(2026, 11))
        // Second job's window has not opened yet in November.
        #expect(!due.contains { $0.item.id == Fixtures.second && $0.month == YearMonth(2026, 11) })
        #expect(due.map(\.month) == due.map(\.month).sorted())
    }

    @Test func dismissedIsDone() {
        var l = ledger
        l.entries.append(entry(.dismissed, Fixtures.gym, movesMoney: false))
        #expect(!l.stillToPay(today: today).contains { $0.item.id == Fixtures.gym })
    }

    @Test func pausedItemIsIgnored() {
        var l = ledger
        l.plan[l.plan.firstIndex { $0.id == Fixtures.gym }!].paused = true
        #expect(!l.stillToPay(today: today).contains { $0.item.id == Fixtures.gym })
    }

    @Test func dueIdNamesItemAndMonth() {
        let due = ledger.stillToPay(today: today).first!
        #expect(due.id == "\(Fixtures.second.uuidString)-2026-10")
    }

    @Test func paydaySplitIsItsUndoneItemsInPlanOrder() throws {
        let income = ledger.stillToPay(today: today).first(where: \.isIncome)
        let october = try #require(income)
        // Bills and groceries were paid early, so only the rest of the side job's split is left.
        #expect(ledger.split(of: october).map(\.id) == [Fixtures.emergencyExtra, Fixtures.clothesPot, Fixtures.card])
        let november = Due(item: october.item, month: YearMonth(2026, 11), heldBack: false, isIncome: true)
        #expect(ledger.split(of: november).map(\.id) == [Fixtures.bills, Fixtures.groceries, Fixtures.emergencyExtra, Fixtures.clothesPot])
    }

    @Test func whatWaitsForAPausedOrMissingIncomeIsHeldBackAnyway() {
        var paused = ledger
        paused.plan[paused.plan.firstIndex { $0.id == Fixtures.second }!].paused = true
        #expect(paused.stillToPay(today: today).filter(\.heldBack).map(\.item.id)
                == [Fixtures.emergencyExtra, Fixtures.clothesPot, Fixtures.gym, Fixtures.card])
        var gone = ledger
        gone.plan.removeAll { $0.id == Fixtures.second }
        #expect(gone.stillToPay(today: today).filter(\.heldBack).map(\.item.id)
                == [Fixtures.emergencyExtra, Fixtures.clothesPot, Fixtures.gym, Fixtures.card])
        // Limited to another month, the income does not apply this month either.
        var other = ledger
        other.plan[other.plan.firstIndex { $0.id == Fixtures.second }!].onlyIn = YearMonth(2026, 11)
        #expect(other.stillToPay(today: today).filter(\.heldBack).count == 4)
    }

    @Test func anIncomeNotYetDueIsListedAsUpcoming() {
        let early = Fixtures.date(2026, 10, 10)
        #expect(ledger.stillToPay(today: early).contains { $0.item.id == Fixtures.second } == false)
        let upcoming = ledger.upcomingIncomes(today: early)
        #expect(upcoming.map(\.item.id) == [Fixtures.second])
        #expect(upcoming.first?.isIncome == true)
        #expect(upcoming.first?.month == Fixtures.october)
        #expect(upcoming.first?.arrivesFrom == 15)
        // Once its window has opened it is due, not upcoming.
        #expect(ledger.upcomingIncomes(today: today).isEmpty)
        // Recorded early, it is gone from the list.
        var paid = ledger
        paid.entries.append(entry(.income, Fixtures.second))
        #expect(paid.upcomingIncomes(today: early).isEmpty)
    }
}
