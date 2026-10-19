import Testing
@testable import BudgetKit

@Test func aLongPullOrAFlickCloses() {
    #expect(Drawer<EmptyViewStandIn>.closes(dragged: 120, predicted: 130))
    #expect(Drawer<EmptyViewStandIn>.closes(dragged: 30, predicted: 300))
    #expect(!Drawer<EmptyViewStandIn>.closes(dragged: 40, predicted: 80))
}

import SwiftUI
typealias EmptyViewStandIn = EmptyView
