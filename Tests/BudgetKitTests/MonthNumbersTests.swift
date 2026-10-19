import Testing
import Foundation
@testable import BudgetKit

@Suite struct MonthNumbersTests {
    let today = Fixtures.date(2026, 10, 19)
    let ledger = Fixtures.oct19(main: .euros(150))

    @Test func lowestPointIsTheFirstDayAtTheLowestBalance() {
        let line = [LinePoint(day: 3, balance: .euros(90), projected: false),
                    LinePoint(day: 4, balance: .euros(40), projected: false),
                    LinePoint(day: 5, balance: .euros(40), projected: true),
                    LinePoint(day: 6, balance: .euros(400), projected: true)]
        #expect(line.lowest == line[1])
        #expect([LinePoint]().lowest == nil)
    }

    @Test func lowestPointOfHisOctoberIsToday() {
        #expect(ledger.monthLine(Fixtures.october, today: today).lowest == LinePoint(day: 19, balance: .euros(150), projected: false))
    }

    @Test func savedIsWhatMovedIntoClothesAndEmergency() {
        // The 350 paid before the first run was saved this month too, though its money was already in the balances.
        // The card isn't saving.
        #expect(ledger.saved(in: Fixtures.october) == .euros(350))
        #expect(Fixtures.afterSideJob().saved(in: Fixtures.october) == .euros(550))
        #expect(Fixtures.afterSideJob().saved(in: YearMonth(2026, 11)) == .zero)
    }

    @Test func savedLeavesOutCorrections() {
        var l = ledger
        l.entries.append(Entry(date: today, amount: .euros(30), kind: .adjustment, to: .emergency))
        #expect(l.saved(in: Fixtures.october) == ledger.saved(in: Fixtures.october))
    }

    @Test func theSideJobIsExpectedTomorrowUntilItArrives() {
        #expect(ledger.linePaydays(Fixtures.october, today: today) == [LinePayday(day: 20, amount: .euros(650), projected: true)])
        #expect(ledger.linePaydays(Fixtures.october, today: Fixtures.date(2026, 10, 21))
                == [LinePayday(day: 22, amount: .euros(650), projected: true)])
    }

    @Test func anArrivedIncomeIsOnItsDay() {
        let l = Fixtures.afterSideJob()
        #expect(l.linePaydays(Fixtures.october, today: Fixtures.date(2026, 10, 20)) == [LinePayday(day: 20, amount: .euros(650), projected: false)])
        // Looking back from November, nothing is expected in October any more.
        #expect(ledger.linePaydays(Fixtures.october, today: Fixtures.date(2026, 11, 2)).isEmpty)
    }

    @Test func ordinals() {
        #expect([1, 2, 3, 4, 11, 12, 13, 19, 21, 22, 23, 31].map(ordinal) ==
                ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "19th", "21st", "22nd", "23rd", "31st"])
    }
}
