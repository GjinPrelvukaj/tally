import Testing
@testable import BudgetKit

@Test func aLongPullOrAFlickCloses() {
    #expect(Drawer<EmptyViewStandIn>.closes(dragged: 120, predicted: 130))
    #expect(Drawer<EmptyViewStandIn>.closes(dragged: 30, predicted: 300))
    #expect(!Drawer<EmptyViewStandIn>.closes(dragged: 40, predicted: 80))
}

import SwiftUI
typealias EmptyViewStandIn = EmptyView

@Test func twoFingersCountTheWayTheyMoveWhateverTheScrollSetting() {
    // Fingers moving down: with natural scrolling the delta is positive, without it negative.
    #expect(SwipeDirection.down.travel(deltaX: 0, deltaY: 12, natural: true) == 12)
    #expect(SwipeDirection.down.travel(deltaX: 0, deltaY: -12, natural: false) == 12)
    #expect(SwipeDirection.down.travel(deltaX: 0, deltaY: -12, natural: true) == -12)
    #expect(SwipeDirection.right.travel(deltaX: 8, deltaY: 0, natural: true) == 8)
    #expect(SwipeDirection.right.travel(deltaX: 8, deltaY: 0, natural: false) == -8)
    // Mostly the other way (scrolling a list), it doesn't count.
    #expect(SwipeDirection.right.travel(deltaX: 2, deltaY: 10, natural: true) == 0)
}
