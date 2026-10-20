import Testing
import Foundation
@testable import BudgetKit

@Suite struct ModelTests {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func dayClampsToMonthEnd() {
        let feb = YearMonth(2027, 2)
        for day in [31, 30] {
            let parts = cal.dateComponents([.year, .month, .day], from: feb.date(day: day, calendar: cal))
            #expect(parts.year == 2027 && parts.month == 2 && parts.day == 28)
        }
    }

    @Test func octoberHas31Days() {
        #expect(YearMonth(2026, 10).days(calendar: cal) == 31)
    }

    @Test func nextAndPreviousCrossYears() {
        let dec = YearMonth(2026, 12)
        #expect(dec.next == YearMonth(2027, 1))
        #expect(dec.next.previous == dec)
        #expect(dec < dec.next)
    }

    @Test func readsTheMonthOfADate() {
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 19))!
        #expect(YearMonth(date, calendar: cal) == YearMonth(2026, 10))
    }

    @Test func oneOffAppliesOnlyInItsMonth() {
        let item = PlanItem(name: "Card", amount: .euros(100), kind: .payment, from: .main, to: .card,
                            schedule: .anyDay, onlyIn: YearMonth(2026, 10))
        #expect(item.applies(in: YearMonth(2026, 10)))
        #expect(!item.applies(in: YearMonth(2026, 11)))
    }

    @Test func pausedNeverApplies() {
        let item = PlanItem(name: "Gym", amount: .euros(30), kind: .payment, from: .main,
                            schedule: .day(1), paused: true)
        #expect(!item.applies(in: YearMonth(2026, 10)))
    }

    @Test func clothesAndFragranceComeFromClothesPot() {
        #expect(Category.clothes.pot == .clothes)
        #expect(Category.fragrance.pot == .clothes)
        #expect(Category.food.pot == .main)
        #expect(Category.goingOut.pot == .main)
        #expect(Category.other.pot == .main)
    }

    @Test func aPotIsKeptAsItsIdAlone() throws {
        let data = try JSONEncoder().encode([Pot.main, Pot("holiday")])
        #expect(String(decoding: data, as: UTF8.self) == #"["main","holiday"]"#)
        #expect(try JSONDecoder().decode([Pot].self, from: data) == [.main, Pot("holiday")])
        #expect([Pot.main, .clothes, .emergency, .card].map(\.title) == ["Main", "Clothes", "Emergency fund", "Credit card"])
        #expect(!Pot.main.isSavings && !Pot.card.isSavings && Pot("holiday").isSavings)
    }

    /// The ledger knows the savings pots of the person's own: shown between Main and the card, named, coloured, counted.
    @Test func savingsPotsOfYourOwn() {
        let holiday = SavingsPot(id: Pot("holiday"), name: "Holiday", colour: 4)
        let old = SavingsPot(id: Pot("car"), name: "Car", colour: 5, retired: true)
        let ledger = Ledger(start: [.main: .euros(100), holiday.id: .euros(50), .card: .euros(-20)], startMonth: YearMonth(2026, 10),
                            plan: [], entries: [], calendar: Fixtures.calendar, savings: [holiday, old])
        #expect(ledger.pots == [.main, holiday.id, .card])
        #expect(ledger.spendingPots == [.main, holiday.id])
        #expect(ledger.name(holiday.id) == "Holiday" && ledger.name(.card) == "Credit card" && ledger.name(Pot("gone")) == "gone")
        #expect(ledger.colour(holiday.id) == 4 && ledger.colour(.main) == SavingsPot.mainColour && ledger.colour(.card) == SavingsPot.cardColour)
        #expect(ledger.total == .euros(130))
        #expect(ledger.potCount == "three pots")
        // Data from before pots of your own: Clothes and the Emergency fund.
        #expect(Ledger(start: [:], startMonth: YearMonth(2026, 10), plan: [], entries: [], calendar: Fixtures.calendar).pots
                == [.main, .clothes, .emergency, .card])
    }

    @Test func aPotIsRetiredOnlyWhenEmptyAndOutOfThePlan() {
        let holiday = SavingsPot(id: Pot("holiday"), name: "Holiday", colour: 4)
        var ledger = Ledger(start: [holiday.id: .euros(50)], startMonth: YearMonth(2026, 10), plan: [], entries: [],
                            calendar: Fixtures.calendar, savings: [holiday])
        #expect(!ledger.canRetire(holiday.id))
        ledger.start[holiday.id] = .zero
        #expect(ledger.canRetire(holiday.id))
        ledger.plan = [PlanItem(name: "Holiday", amount: .euros(50), kind: .transfer, from: .main, to: holiday.id, schedule: .anyDay, paused: true)]
        #expect(!ledger.canRetire(holiday.id))
        #expect(!ledger.canRetire(.main) && !ledger.canRetire(.card))
    }

    @Test func aNewPotTakesTheNextColourFree() {
        #expect(SavingsPot.nextColour(after: []) == SavingsPot.colours[0])
        #expect(SavingsPot.nextColour(after: SavingsPot.original) == 4)
        let all = SavingsPot.colours.map { SavingsPot(name: "", colour: $0) }
        #expect(SavingsPot.colours.contains(SavingsPot.nextColour(after: all)))
    }

    @Test func entryAndPlanItemRoundTripThroughJSON() throws {
        let income = UUID()
        let item = PlanItem(name: "Rent", amount: .euros(500), kind: .payment, from: .main,
                            schedule: .withIncome(income))
        let entry = Entry(date: Date(timeIntervalSince1970: 0), amount: .euros(-5), kind: .adjustment,
                          to: .main, forMonth: YearMonth(2026, 10), movesMoney: false)
        let back = try JSONDecoder().decode(PlanItem.self, from: JSONEncoder().encode(item))
        let entryBack = try JSONDecoder().decode(Entry.self, from: JSONEncoder().encode(entry))
        #expect(back == item)
        #expect(entryBack == entry)
    }

    @Test func monthNamesInEnglish() {
        #expect(YearMonth(2026, 10).name == "October")
        #expect(YearMonth(2027, 3).shortName == "Mar 2027")
    }
}
