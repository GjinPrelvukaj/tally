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
}
