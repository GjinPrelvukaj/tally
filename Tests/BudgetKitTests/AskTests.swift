import Testing
import Foundation
@testable import BudgetKit

/// Ask Tally's answers, written by code from a `Question`. Today is Monday 19 October 2026: this week is today alone,
/// last week Monday 12 to Sunday 18 October.
@Suite struct AskTests {
    let today = Fixtures.date(2026, 10, 19)
    let salary = PlanItem(name: "Salary", amount: .euros(2000), kind: .income, to: .main, schedule: .day(1))
    let gym = PlanItem(name: "Gym", amount: .euros(35), kind: .payment, from: .main, schedule: .anyDay)

    func spend(_ cents: Int, _ m: Int, _ d: Int, note: String? = nil, category: BudgetKit.Category = .food,
               from: Pot = .main, partner: PartnerShare? = nil, owed: Cents? = nil) -> Entry {
        Entry(date: Fixtures.date(2026, m, d), amount: Cents(cents), kind: .spend, from: from, category: category.id, note: note,
              partner: partner, owed: owed)
    }

    var ledger: Ledger {
        let arrived = Entry(date: Fixtures.date(2026, 10, 1), amount: .euros(2000), kind: .income, to: .main,
                            planItem: salary.id, forMonth: YearMonth(2026, 10), movesMoney: false)
        let entries = [arrived,
                       spend(4200, 10, 13), spend(1800, 10, 15, category: .goingOut),
                       spend(510, 10, 15, note: "coffee", category: .goingOut, partner: .half, owed: Cents(255)),
                       spend(510, 10, 17, note: "Coffee", category: .goingOut, partner: .with),
                       spend(6120, 10, 17), spend(340, 10, 19, note: "cigarettes", category: .other),
                       spend(2500, 9, 20, note: "coffee beans")]
        return Ledger(start: [.main: .euros(600), .clothes: .euros(240), .emergency: .euros(2150), .card: .euros(-45)],
                      startMonth: YearMonth(2026, 10), plan: [salary, gym], entries: entries, calendar: Fixtures.calendar)
    }

    func ask(_ question: Question, partner: String = "Sam") -> Answer {
        ledger.answer(question, today: today, partnerName: partner)
    }

    @Test func spendingLastWeekByCategoryAndItsBiggestDay() {
        let answer = ask(Question(topic: .spending, period: .lastWeek))
        #expect(answer.title == "131,40\u{00A0}€ spent last week")
        #expect(answer.lines == ["5 spends",
                                 "Food 103,20\u{00A0}€ · Going out 28,20\u{00A0}€",
                                 "Most on the 17th: 66,30\u{00A0}€"])
        #expect(answer.understood == "Spending · last week")
    }

    @Test func spendingInOneCategory() {
        let answer = ask(Question(topic: .spending, period: .thisMonth, category: "going out"))
        #expect(answer.title == "28,20\u{00A0}€ spent on Going out this month")
        #expect(answer.lines.first == "3 spends")
        #expect(answer.understood == "Spending · this month · Going out")
    }

    @Test func nothingSpentSaysSo() {
        let answer = ask(Question(topic: .spending, period: .today, category: "food"))
        #expect(answer.title == "Nothing spent on Food today")
        #expect(answer.lines.isEmpty)
    }

    @Test func aCategoryThatIsNotYoursIsDropped() {
        #expect(ask(Question(topic: .spending, period: .today, category: "Smokes")).understood == "Spending · today")
    }

    @Test func searchFindsNotesWhateverTheirCase() {
        let answer = ask(Question(topic: .search, period: .thisMonth, search: "coffee"))
        #expect(answer.title == "10,20\u{00A0}€ on “coffee” this month")
        #expect(answer.lines == ["2 spends", "Last on the 17th: 5,10\u{00A0}€", "2 of them with Sam"])
        // Last month's beans are last month's.
        #expect(ask(Question(topic: .search, period: .lastMonth, search: "coffee")).title == "25,00\u{00A0}€ on “coffee” in September")
        #expect(ask(Question(topic: .search, period: .today, search: "coffee")).title == "Nothing on “coffee” today")
    }

    @Test func balancesSayTheCardAsWhatItOwes() {
        let answer = ask(Question(topic: .balances))
        // 600 − 42 − 18 − 5,10 − 5,10 − 61,20 − 3,40 − 25 = 440,20 in Main.
        #expect(answer.title == "2\u{00A0}785,20\u{00A0}€ across four pots")
        #expect(answer.lines == ["Main 440,20\u{00A0}€", "Clothes 240,00\u{00A0}€", "Emergency fund 2\u{00A0}150,00\u{00A0}€",
                                 "Credit card: you owe 45,00\u{00A0}€"])
        #expect(answer.understood == "Balances")
    }

    @Test func theDailyAmountAndWhatIsStillToPay() {
        let answer = ask(Question(topic: .allowance))
        // (440,20 − 35 gym) over the 13 days to the 1st.
        #expect(answer.title == "31,16\u{00A0}€ a day until the 2\u{00A0}000")
        #expect(answer.lines == ["13 days, today included", "Still to pay: Gym 35,00\u{00A0}€"])
    }

    @Test func thePartnerOwesAndHowOftenTogether() {
        let answer = ask(Question(topic: .partner, period: .thisMonth))
        #expect(answer.title == "Sam owes you 2,55\u{00A0}€")
        #expect(answer.lines == ["With Sam 2 times this month; 2,55\u{00A0}€ of it was Sam's"])
        #expect(ask(Question(topic: .partner, period: .thisMonth), partner: "").title == "No partner set")
    }

    @Test func insightsSayTheHeadline() {
        let answer = ask(Question(topic: .insights))
        #expect(answer.title == Insight.headline(ledger.insights(today: today, partnerName: "Sam")))
        #expect(answer.understood == "Insights")
    }
}

/// The model's reading of a question, checked against the question's own words. Each case is a real misreading
/// the on-device model made on this Mac.
@Suite struct QuestionCheckTests {
    let categories = Category.starters + [Category(id: "s", name: "Smokes")]

    func check(_ text: String, _ read: Question) -> Question {
        read.checked(against: text, categories: categories, partnerName: "Sam")
    }

    @Test func aCategoryOrWordNotInTheQuestionIsDropped() {
        let read = check("Where did my money go this week?", Question(topic: .spending, period: .thisWeek, category: "Food", search: "coffee"))
        #expect(read == Question(topic: .spending, period: .thisWeek))
    }

    @Test func aThingNamedWithoutACategoryIsASearch() {
        let read = check("How much did I spend on coffee this month?", Question(topic: .spending, period: .thisMonth, category: "Food", search: "coffee"))
        #expect(read == Question(topic: .search, period: .thisMonth, search: "coffee"))
    }

    @Test func owingAndThePartnerIsAboutThePartner() {
        #expect(check("What does Sam owe me?", Question(topic: .balances, category: "Other")).topic == .partner)
    }

    @Test func owingOnTheCardIsBalances() {
        #expect(check("What do I owe on the credit card?", Question(topic: .partner)).topic == .balances)
        #expect(check("what's my credit card at", Question(topic: .spending)).topic == .balances)
    }

    @Test func enoughUntilPaydayIsTheDailyAmount() {
        #expect(check("do i have enough until payday?", Question(topic: .balances)).topic == .allowance)
        #expect(check("How much can I spend today?", Question(topic: .spending, period: .today)).topic == .allowance)
    }

    @Test func spendingWithThePartnerIsFilteredToThem() {
        let read = check("how much did i spend going out with sam", Question(topic: .spending, category: "Going out", search: "going out"))
        #expect(read == Question(topic: .spending, period: .thisMonth, category: "Going out", withPartner: true))
    }

    @Test func aCategorySaidInTheQuestionIsKept() {
        let read = check("smokes this week", Question(topic: .spending, period: .thisWeek, category: "Smokes", search: "smokes"))
        #expect(read == Question(topic: .spending, period: .thisWeek, category: "Smokes"))
    }

    @Test func timeWordsInTheQuestionWin() {
        #expect(check("food last month", Question(topic: .spending, period: .thisMonth, category: "Food")).period == .lastMonth)
        #expect(check("what did I spend last week", Question(topic: .spending, period: .thisWeek)).period == .lastWeek)
        #expect(check("what did I spend", Question(topic: .spending, period: .today)).period == .today)
    }
}

@Suite struct PartnerFilterTests {
    @Test func spendingWithThePartnerCountsOnlyThoseSpends() {
        let today = Fixtures.date(2026, 10, 19)
        let entries = [Entry(date: today, amount: Cents(1000), kind: .spend, from: .main, category: "goingOut", partner: .with),
                       Entry(date: today, amount: Cents(500), kind: .spend, from: .main, category: "goingOut")]
        let ledger = Ledger(start: [.main: .euros(100)], startMonth: YearMonth(2026, 10), plan: [], entries: entries, calendar: Fixtures.calendar)
        let answer = ledger.answer(Question(topic: .spending, period: .today, withPartner: true), today: today, partnerName: "Sam")
        #expect(answer.title == "10,00\u{00A0}€ spent with Sam today")
        #expect(answer.understood == "Spending · today · with Sam")
    }
}
