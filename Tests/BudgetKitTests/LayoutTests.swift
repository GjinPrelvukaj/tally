import Testing
import Foundation
@testable import BudgetKit

/// Today grows with the window, and never past what still reads as one piece.
@Suite struct TodayLayoutTests {
    @Test func theSmallestWindowKeepsTheRingAt240() {
        let layout = TodayLayout(width: 589, height: 428)
        #expect(layout.ring == 240 && layout.scale == 1)
        #expect(layout.width <= 589)
    }

    @Test func aBigWindowGrowsTheRingAndColumn() {
        let layout = TodayLayout(width: 1210, height: 834)
        #expect(layout.ring > 300 && layout.ring <= 380)
        #expect(layout.column == 460)
    }

    @Test func itNeverGrowsPastItsLargest() {
        let layout = TodayLayout(width: 4000, height: 3000)
        #expect(layout.ring == 380 && layout.column == 460)
    }
}

/// Hovering the month line: a day before Tally was set up reads nothing, rather than the first day's balance.
@Suite struct MonthLineHoverTests {
    private let frame = MonthLineFrame(line: (19...31).map { LinePoint(day: $0, balance: Cents(290), projected: $0 > 19) },
                                        days: 31, size: CGSize(width: 600, height: 100))

    @Test func aDayBeforeTheLineReadsNothing() {
        #expect(frame.nearestDay(to: frame.x(5)) == nil)
        #expect(frame.nearestDay(to: frame.x(18)) == nil)
        #expect(frame.nearestDay(to: frame.x(19)) == 19)
        #expect(frame.nearestDay(to: frame.x(25) + 3) == 25)
    }
}
