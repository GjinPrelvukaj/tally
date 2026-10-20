import Testing
@testable import BudgetKit

@Suite struct TubesTests {
    @Test func tubeLevelIsTheAmountOverTheSharedScale() {
        #expect(Tubes.level(Cents(250000), of: Cents(500000)) == 0.5)
        #expect(Tubes.level(Cents(500), of: Cents(400)) == 1)
        #expect(Tubes.level(Cents(-500), of: Cents(400)) == 0)
        #expect(Tubes.level(Cents(500), of: .zero) == 0)
    }

    @Test func theCardIsHeldAsWhatIsOwed() {
        #expect(Tubes.held(Cents(-6340), in: .card) == Cents(6340))
        #expect(Tubes.held(Cents(-6340), in: .main) == Cents(-6340))
        #expect(Tubes.held(.zero, in: .card) == .zero)
    }

    @Test func onlyTheCardIsTypedTheOtherWayRound() {
        #expect(Pot.card.figure(for: Cents(-6340)) == Cents(6340))
        #expect(Pot.card.balance(fromFigure: Cents(6340)) == Cents(-6340))
        #expect(Pot.main.figure(for: Cents(-500)) == Cents(-500))
        #expect(Pot.main.balance(fromFigure: Cents(500)) == Cents(500))
        for pot in [Pot.main, .clothes, .emergency, .card, Pot("holiday")] { #expect(pot.balance(fromFigure: pot.figure(for: Cents(1234))) == Cents(1234)) }
    }

    @Test func theScaleIsTheLargestHeldAmountOrGoal() {
        let balances: [Pot: Cents] = [.main: .euros(150), .clothes: .zero, .emergency: Cents(131250), .card: Cents(-6340)]
        #expect(Tubes.scale(balances: balances, goals: [.emergency: .euros(5000)]) == .euros(5000))
        #expect(Tubes.scale(balances: balances, goals: [:]) == Cents(131250))
        // A debt bigger than everything else sets the scale: the card tube is full.
        #expect(Tubes.scale(balances: [.main: .euros(10), .card: .euros(-300)], goals: [:]) == .euros(300))
        #expect(Tubes.scale(balances: [:], goals: [:]) == .zero)
    }
}
