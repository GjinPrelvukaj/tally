import Testing
@testable import BudgetKit

@Suite struct CentsTests {
    @Test func aPaymentIsTypedAboveZero() {
        #expect(Cents.parsePositive("12,5") == Cents(1250))
        #expect(Cents.parsePositive("0") == nil)
        #expect(Cents.parsePositive("0,00") == nil)
        #expect(Cents.parsePositive("x") == nil)
    }

    @Test func formatsEuros() {
        #expect(Cents(245017).formatted == "2\u{00A0}450,17\u{00A0}€")
        #expect(Cents(4096).formatted == "40,96\u{00A0}€")
        #expect(Cents(-6340).formatted == "\u{2212}63,40\u{00A0}€")
        #expect(Cents(0).formatted == "0,00\u{00A0}€")
    }

    @Test func wholeEurosForTheIncomeName() {
        #expect(Cents(65000).wholeEuros == "650")
        #expect(Cents(240000).wholeEuros == "2\u{00A0}400")
        #expect(Cents(81250).wholeEuros == "812")
    }

    @Test func parsesTypedAmounts() {
        #expect(Cents.parse("12,5") == Cents(1250))
        #expect(Cents.parse(" 12.50 ") == Cents(1250))
        #expect(Cents.parse("2 400") == Cents(240000))
        #expect(Cents.parse("12,555") == nil)   // more than two decimals
        #expect(Cents.parse("abc") == nil)
        #expect(Cents.parse("") == nil)
    }

    @Test func floorDivision() {
        #expect(Cents(49160).dividedFloor(by: 12) == Cents(4096))
        #expect(Cents(-100).dividedFloor(by: 3) == Cents(-34))
    }

    @Test func editableIsTheAmountWithoutTheEuroSign() {
        #expect(Cents(65000).editable == "650,00")
        #expect(Cents(245017).editable == "2\u{00A0}450,17")
        #expect(Cents.parse(Cents(245017).editable) == Cents(245017))
    }
}

@Test func shortDropsRoundCents() {
    #expect(Cents(20000).short == "200\u{00A0}€")
    #expect(Cents(240000).short == "2\u{00A0}400\u{00A0}€")
    #expect(Cents(6340).short == "63,40\u{00A0}€")
    // A round debt keeps its minus.
    #expect(Cents(-4500).short == "\u{2212}45\u{00A0}€")
}

/// A balance can be below zero (an overdrawn account, a card in credit): its field takes a minus, as typed or as
/// Tally writes it (U+2212), so a negative balance it shows can be saved again. Payments never can.
@Test func aBalanceCanBeTypedBelowZero() {
    #expect(Cents.parseSigned("-45") == Cents(-4500))
    #expect(Cents.parseSigned("\u{2212}45,50") == Cents(-4550))
    #expect(Cents.parseSigned(" - 1 200,5 ") == Cents(-120050))
    #expect(Cents.parseSigned("12,30") == Cents(1230))
    #expect(Cents.parseSigned(Cents(-4517).editable) == Cents(-4517))
    #expect(Cents.parseSigned("--4") == nil)
    #expect(Cents.parseSigned("4-") == nil)
    #expect(Cents.parseSigned("-") == nil)
    #expect(Cents.parse("-45") == nil)
    #expect(Cents.parsePositive("-45") == nil)
}
