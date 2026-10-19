import Testing
import Foundation
@testable import BudgetKit

@Suite struct PreferenceTests {
    func defaults() -> UserDefaults {
        let name = "tally-tests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func amountsStartAsChosen() {
        #expect(!AmountsOnOpen.shown.startsHidden(lastHidden: true))
        #expect(AmountsOnOpen.hidden.startsHidden(lastHidden: false))
        #expect(AmountsOnOpen.asLeft.startsHidden(lastHidden: true))
        #expect(!AmountsOnOpen.asLeft.startsHidden(lastHidden: false))
    }

    @Test func nothingChosenIsAsLeft() {
        #expect(AmountsOnOpen.saved(in: defaults()) == .asLeft)
    }

    @Test func theOldAlwaysHiddenSwitchReadsAsHidden() {
        let d = defaults()
        d.set(true, forKey: "hideAmountsOnOpen")
        #expect(AmountsOnOpen.saved(in: d) == .hidden)
        d.set(AmountsOnOpen.shown.rawValue, forKey: Preference.amountsOnOpen)
        #expect(AmountsOnOpen.saved(in: d) == .shown)
    }
}
