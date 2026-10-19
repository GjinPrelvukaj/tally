import Testing
import Foundation
@testable import BudgetKit

@Suite struct LedgerForecastTests {
    let today = Fixtures.date(2026, 10, 19)
    let ledger = Fixtures.oct19(main: .euros(150))

    @Test func allowanceBeforeTheSideJob() throws {
        let a = try #require(ledger.allowance(today: today))
        #expect(a.perDay == .euros(105))
        #expect(a.days == 1)
        #expect(a.until.item.id == Fixtures.second)
        #expect(!a.until.late)
    }

    @Test func allowanceAfterTheSideJob() throws {
        let l = Fixtures.afterSideJob()
        let now = Fixtures.date(2026, 10, 20)
        #expect(l.balance(.main) == Cents(53660))
        let a = try #require(l.allowance(today: now))
        #expect(a.until.item.id == Fixtures.salary)
        #expect(a.until.date == Fixtures.date(2026, 11, 1, hour: 0))
        #expect(a.until.late == false)
        #expect(a.days == 12)
        #expect(a.perDay == Cents(4096))
    }

    @Test func lateSideJob() throws {
        let now = Fixtures.date(2026, 10, 21)
        let a = try #require(ledger.allowance(today: now))
        #expect(a.until.late)
        #expect(a.until.item.id == Fixtures.second)
        #expect(a.days == 1)
        #expect(a.perDay == .euros(105))
    }

    @Test func overspentAllowanceIsNegative() throws {
        let a = try #require(Fixtures.oct19(main: .euros(20)).allowance(today: today))
        #expect(a.perDay == .euros(-25))
    }

    @Test func nextMonthsIncomeWhenNoneIsLeft() throws {
        var l = ledger
        l.plan.removeAll { $0.id == Fixtures.second }
        let next = try #require(l.nextIncome(today: today))
        #expect(next.item.id == Fixtures.salary)
        #expect(next.date == Fixtures.date(2026, 11, 1, hour: 0))
    }

    @Test func paydaysAreTheIncomesDays() {
        // The salary on the 1st; the side job's window counts at its last day.
        #expect(ledger.paydays(today: today) == [1, 20])
    }

    @Test func noIncomesMeansNoAllowance() {
        var l = ledger
        l.plan.removeAll { $0.kind == .income }
        #expect(l.nextIncome(today: today) == nil)
        #expect(l.allowance(today: today) == nil)
    }

    @Test func emergencyGoalIsJune2027() {
        #expect(ledger.goalMonth(.emergency, goal: .euros(5000), today: today) == YearMonth(2027, 6))
    }

    @Test func goalAlreadyReachedIsThisMonth() {
        #expect(ledger.goalMonth(.emergency, goal: .euros(700), today: today) == Fixtures.october)
        #expect(ledger.goalMonth(.emergency, goal: .euros(500), today: today) == Fixtures.october)
    }

    @Test func noGoalWithoutPlan() {
        var l = ledger
        l.plan[l.plan.firstIndex { $0.id == Fixtures.clothesPot }!].paused = true
        #expect(l.goalMonth(.clothes, goal: .euros(1000), today: today) == nil)
    }

    /// The point for a day of the month, wherever the line starts.
    private func on(_ day: Int, _ line: [LinePoint]) -> LinePoint? { line.first { $0.day == day } }

    @Test func monthLineProjects() throws {
        let line = ledger.monthLine(Fixtures.october, today: today)
        #expect(line.count == 13)
        #expect(on(19, line) == LinePoint(day: 19, balance: .euros(150), projected: false))
        #expect(on(20, line) == LinePoint(day: 20, balance: Cents(46660), projected: true))
        #expect(on(21, line) == LinePoint(day: 21, balance: Cents(44160), projected: true))
        #expect(line.last?.projected == true)
    }

    @Test func monthLineStartsOnTheFirstRunDay() {
        let line = ledger.monthLine(Fixtures.october, today: today)
        #expect(line.first?.day == 19)
        #expect(ledger.monthLine(YearMonth(2026, 9), today: today).isEmpty)
    }

    @Test func monthLineWithNoEntriesStartsOnTheFirstOfTheStartMonth() {
        var l = ledger
        l.entries = []
        #expect(l.monthLine(Fixtures.october, today: today).first?.day == 1)
    }

    @Test func datedPaymentIsHeldBackAndProjectedOnItsDay() throws {
        var l = ledger
        l.plan.append(PlanItem(name: "Insurance", amount: .euros(30), kind: .payment, from: .main, schedule: .day(25)))
        let line = l.monthLine(Fixtures.october, today: today)
        #expect(on(24, line) == LinePoint(day: 24, balance: Cents(36660), projected: true))
        #expect(on(25, line) == LinePoint(day: 25, balance: Cents(31160), projected: true))
        #expect(try #require(l.allowance(today: today)).perDay == .euros(75))
    }

    @Test func monthLineOfALateIncomeLandsTomorrow() {
        let line = ledger.monthLine(Fixtures.october, today: Fixtures.date(2026, 10, 21))
        #expect(on(21, line) == LinePoint(day: 21, balance: .euros(150), projected: false))
        #expect(on(22, line) == LinePoint(day: 22, balance: Cents(46660), projected: true))
    }

    @Test func pastMonthComesFromEntriesAndLaterMonthsAreEmpty() {
        let l = Fixtures.afterSideJob()
        let november = Fixtures.date(2026, 11, 5)
        let line = l.monthLine(Fixtures.october, today: november)
        #expect(line.count == 13)
        #expect(line.allSatisfy { !$0.projected })
        #expect(on(19, line)?.balance == .euros(150))
        #expect(on(20, line)?.balance == Cents(53660))
        #expect(l.monthLine(YearMonth(2026, 12), today: november).isEmpty)
    }
}
