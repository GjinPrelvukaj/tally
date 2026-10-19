import Testing
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
