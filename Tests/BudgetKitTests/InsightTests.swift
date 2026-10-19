import Testing
import Foundation
@testable import BudgetKit

/// Every insight on a month simple enough to check by hand: a salary of 2 000 on the 1st, 20 a day of daily life,
/// today the 19th of October 2026 (13 days to the 1st of November, today included).
@Suite struct InsightTests {
    let today = Fixtures.date(2026, 10, 19)
    let salary = PlanItem(name: "Salary", amount: .euros(2000), kind: .income, to: .main, schedule: .day(1))
    let daily = PlanItem(name: "Daily life", amount: .euros(20), kind: .daily, from: .main, schedule: .anyDay)

    /// `firstRun`: the day of October Tally was set up, when it started in October.
    func ledger(main: Cents, from start: YearMonth = YearMonth(2026, 10), plan extra: [PlanItem] = [], entries: [Entry] = [],
                card: Cents = .zero, firstRun: Int = 1) -> Ledger {
        // Each month's salary has arrived (before the first run, so it moves no money): the next pay is the 1st of November.
        let arrived = sequence(first: start) { $0.next }.prefix { $0 <= YearMonth(2026, 10) }.map { month in
            Entry(date: month.date(day: month == start ? firstRun : 1, calendar: Fixtures.calendar), amount: .euros(2000), kind: .income, to: .main,
                  planItem: salary.id, forMonth: month, movesMoney: false)
        }
        return Ledger(start: [.main: main, .card: card], startMonth: start, plan: [salary, daily] + extra, entries: arrived + entries,
                      calendar: Fixtures.calendar)
    }

    func spend(_ cents: Int, _ y: Int, _ m: Int, _ d: Int, note: String? = nil, category: BudgetKit.Category = .food, from: Pot = .main,
               partner: PartnerShare? = nil, owed: Cents? = nil) -> Entry {
        Entry(date: Fixtures.date(y, m, d), amount: Cents(cents), kind: .spend, from: from, category: category.id, note: note,
              partner: partner, owed: owed)
    }

    func of(_ kind: Insight.Kind, _ ledger: Ledger, partner: String = "") -> [Insight] {
        ledger.insights(today: today, partnerName: partner).filter { $0.kind == kind }
    }

    // MARK: Running short, and the good news when not

    @Test func mainThatRunsOutBeforePaydaySaysWhenAndWhatADayReachesIt() throws {
        // 100 less 20 a day: 0 on the 24th, below on the 25th.
        let insight = try #require(of(.runningShort, ledger(main: .euros(100))).first)
        #expect(insight.level == .warning)
        #expect(insight.title == "Main runs out on the 25th")
        #expect(insight.detail == "At the plan's 20,00\u{00A0}€ a day it goes below 0 before the 2\u{00A0}000. Keep to 7,69\u{00A0}€ a day to reach it.")
    }

    @Test func mainThatLastsSaysWhatIsLeftForPayday() throws {
        // 600 less 20 a day for the 12 days after today.
        #expect(of(.runningShort, ledger(main: .euros(600))).isEmpty)
        let insight = try #require(of(.onTrack, ledger(main: .euros(600))).first)
        #expect(insight.level == .good)
        #expect(insight.title == "Main reaches the 2\u{00A0}000 with 360,00\u{00A0}€ to spare")
    }

    // MARK: Pace

    @Test func spendingFasterThanTheAllowanceSaysByHowMuch() throws {
        // 30 a day for the last 7 days; 400 − 210 = 190 left, 14,61 a day allowed; 190 lasts 6 days at 30.
        let week = (13...19).map { spend(3000, 2026, 10, $0) }
        let insight = try #require(of(.pace, ledger(main: .euros(400), entries: week)).first)
        #expect(insight.level == .warning)
        #expect(insight.title == "This week you spent 30,00\u{00A0}€ a day")
        #expect(insight.detail == "The plan allows 14,61\u{00A0}€ a day until the 2\u{00A0}000. At this pace Main lasts 6 more days.")
    }

    @Test func spendingWithinTheAllowanceSaysNothing() {
        let week = (13...19).map { spend(1000, 2026, 10, $0) }
        #expect(of(.pace, ledger(main: .euros(800), entries: week)).isEmpty)
    }

    @Test func fewerThanThreeDaysOfSpendingIsTooSoonToTell() {
        let two = [spend(9000, 2026, 10, 18), spend(9000, 2026, 10, 19)]
        // Set up yesterday.
        #expect(of(.pace, ledger(main: .euros(400), entries: two, firstRun: 18)).isEmpty)
    }

    // MARK: Habits

    @Test func aSmallSpendRepeatedOftenSaysWhatItCostsAYear() throws {
        let smokes = [2, 6, 10, 14, 18].map { spend(340, 2026, 10, $0, note: "cigarettes") }
        let coffee = [5, 12].map { spend(510, 2026, 10, $0, note: "coffee") }
        let habits = of(.habit, ledger(main: .euros(600), entries: smokes + coffee))
        let insight = try #require(habits.first)
        #expect(habits.count == 1)
        #expect(insight.title == "Cigarettes: 5 times in 30 days")
        // 17,00 in 30 days is 206,83 over 365.
        #expect(insight.detail == "17,00\u{00A0}€ in 30 days; about 206,83\u{00A0}€ a year.")
    }

    @Test func notesThatDifferOnlyInCaseOrSpacesAreTheSameHabit() {
        let notes = ["Cigarettes", "cigarettes ", " CIGARETTES", "cigarettes"]
        let smokes = notes.enumerated().map { spend(340, 2026, 10, 10 + $0.offset, note: $0.element) }
        #expect(of(.habit, ledger(main: .euros(600), entries: smokes)).first?.title == "Cigarettes: 4 times in 30 days")
    }

    // MARK: This month against last

    @Test func aCategoryUpOnLastMonthByTheSameDaySaysSo() throws {
        let entries = [spend(1800, 2026, 9, 5, category: .goingOut), spend(5200, 2026, 10, 10, category: .goingOut),
                       // After the 19th of September: not counted against the 19th of October.
                       spend(9000, 2026, 9, 25, category: .goingOut)]
        let insight = try #require(of(.month, ledger(main: .euros(600), from: YearMonth(2026, 9), entries: entries)).first)
        #expect(insight.level == .notice)
        #expect(insight.title == "Going out is up 34,00\u{00A0}€ on last month")
        #expect(insight.detail == "52,00\u{00A0}€ by the 19th, against 18,00\u{00A0}€ by the 19th of September.")
    }

    @Test func aCategoryDownIsGoodNews() throws {
        let entries = [spend(6000, 2026, 9, 5), spend(2000, 2026, 10, 10)]
        let insight = try #require(of(.month, ledger(main: .euros(600), from: YearMonth(2026, 9), entries: entries)).first)
        #expect(insight.level == .good)
        #expect(insight.title == "Food is down 40,00\u{00A0}€ on last month")
    }

    @Test func aSmallChangeIsNotNews() {
        let entries = [spend(5000, 2026, 9, 5), spend(5600, 2026, 10, 10)]
        #expect(of(.month, ledger(main: .euros(600), from: YearMonth(2026, 9), entries: entries)).isEmpty)
    }

    @Test func theFirstMonthHasNothingToCompare() {
        #expect(of(.month, ledger(main: .euros(600), entries: [spend(5000, 2026, 10, 10)])).isEmpty)
    }

    // MARK: The plan

    @Test func aSpendThatCameEveryMonthButIsNotPlannedIsSuggested() throws {
        let netflix = [8, 9, 10].map { spend(1299, 2026, $0, 3, note: "Netflix", category: .other) }
        let insight = try #require(of(.unplanned, ledger(main: .euros(600), from: YearMonth(2026, 8), entries: netflix)).first)
        #expect(insight.title == "Netflix comes every month")
        #expect(insight.detail == "12,99\u{00A0}€ in each of the last 3 months, but it isn't in your plan. Add it, so the daily amount counts it.")
        let planned = PlanItem(name: "netflix", amount: Cents(1299), kind: .payment, from: .main, schedule: .day(3))
        #expect(of(.unplanned, ledger(main: .euros(600), from: YearMonth(2026, 8), plan: [planned], entries: netflix)).isEmpty)
    }

    @Test func aPlanItemSkippedTwoMonthsRunningIsPointedOut() throws {
        let gym = PlanItem(name: "Gym", amount: .euros(35), kind: .payment, from: .main, schedule: .anyDay)
        let skipped = [8, 9].map { Entry(date: Fixtures.date(2026, $0, 28), amount: .zero, kind: .dismissed, planItem: gym.id,
                                         forMonth: YearMonth(2026, $0), movesMoney: false) }
        let insight = try #require(of(.skipped, ledger(main: .euros(600), from: YearMonth(2026, 8), plan: [gym], entries: skipped)).first)
        #expect(insight.title == "Gym was skipped in August and September")
        let paid = Entry(date: Fixtures.date(2026, 9, 2), amount: .euros(35), kind: .payment, from: .main, planItem: gym.id,
                         forMonth: YearMonth(2026, 9))
        #expect(of(.skipped, ledger(main: .euros(600), from: YearMonth(2026, 8), plan: [gym], entries: [skipped[0], paid])).isEmpty)
    }

    @Test func aCardThatOwesMoreEachMonthIsAWarning() throws {
        let entries = [spend(4500, 2026, 8, 10, from: .card), spend(3500, 2026, 9, 10, from: .card), spend(4000, 2026, 10, 10, from: .card)]
        let insight = try #require(of(.card, ledger(main: .euros(600), from: YearMonth(2026, 8), entries: entries)).first)
        #expect(insight.level == .warning)
        #expect(insight.title == "The card owes more every month")
        #expect(insight.detail == "45,00\u{00A0}€ at the end of August, 80,00\u{00A0}€ at the end of September, 120,00\u{00A0}€ now.")
    }

    // MARK: The partner

    @Test func whatThePartnerOwesAndHowOftenYouWereTogether() throws {
        let entries = [spend(1000, 2026, 10, 3, partner: .half, owed: Cents(500)),
                       spend(2400, 2026, 10, 8, partner: .forThem, owed: Cents(2400)),
                       spend(800, 2026, 10, 12, partner: .with),
                       // Last month: not this month's.
                       spend(800, 2026, 9, 12, partner: .with)]
        let insights = of(.partner, ledger(main: .euros(600), from: YearMonth(2026, 9), entries: entries), partner: "Sam")
        #expect(insights.map(\.title) == ["Sam owes you 29,00\u{00A0}€", "With Sam 3 times this month"])
        #expect(insights.last?.detail == "29,00\u{00A0}€ of it was Sam's.")
        #expect(of(.partner, ledger(main: .euros(600), entries: entries)).isEmpty)
    }

    @Test func anyoneWhoOwesOrIsOwedSaysSinceWhen() {
        let entries = [Entry(date: Fixtures.date(2026, 10, 3), amount: .euros(50), kind: .lent, from: .main, person: "Ben"),
                       Entry(date: Fixtures.date(2026, 10, 9), amount: .euros(20), kind: .borrowed, to: .main, movesMoney: false, person: "Ana"),
                       Entry(date: Fixtures.date(2026, 10, 12), amount: .euros(50), kind: .repayment, to: .main, person: "Cleo"),
                       Entry(date: Fixtures.date(2026, 10, 2), amount: .euros(50), kind: .lent, from: .main, person: "Cleo")]
        let insights = of(.partner, ledger(main: .euros(600), entries: entries))
        #expect(insights.map(\.title) == ["You owe Ana 20,00\u{00A0}€", "Ben owes you 50,00\u{00A0}€"])
        #expect(insights.last?.detail == "Open since the 3rd of October.")
    }

    // MARK: Order

    @Test func warningsComeFirstThenNewsThenGoodNews() {
        let levels = ledger(main: .euros(100), entries: (13...19).map { spend(3000, 2026, 10, $0) })
            .insights(today: today, partnerName: "").map(\.level)
        #expect(levels == levels.sorted())
        #expect(levels.first == .warning)
    }
}

/// The line over the insights: what needs a look, or that all is on track. Written by code from them, never guessed.
@Suite struct InsightHeadlineTests {
    func insight(_ kind: Insight.Kind, _ level: Insight.Level, _ title: String) -> Insight {
        Insight(id: title, kind: kind, level: level, title: title, detail: "")
    }

    @Test func oneWarningLeads() {
        let all = [insight(.runningShort, .warning, "Main runs out on the 25th"), insight(.habit, .notice, "Cigarettes: 7 times in 30 days")]
        #expect(Insight.headline(all) == "One thing needs a look: Main runs out on the 25th. 1 more below.")
    }

    @Test func moreWarningsAreCounted() {
        let all = [insight(.runningShort, .warning, "Main runs out on the 25th"), insight(.card, .warning, "The card owes more every month")]
        #expect(Insight.headline(all) == "2 things need a look, first: Main runs out on the 25th. 1 more below.")
    }

    @Test func noWarningAndOnTrackSaysSo() {
        let all = [insight(.habit, .notice, "Cigarettes: 7 times in 30 days"), insight(.onTrack, .good, "Main reaches the 2 000 with 127,00 € to spare")]
        #expect(Insight.headline(all) == "On track: Main reaches the 2 000 with 127,00 € to spare. 1 more below.")
    }

    @Test func nothingIsNothing() {
        #expect(Insight.headline([]) == nil)
        #expect(Insight.headline([insight(.habit, .notice, "Coffee: 4 times in 30 days")]) == "Nothing pressing. 1 below.")
    }
}
