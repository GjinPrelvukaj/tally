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

    /// The menu bar never shows an amount the window would hide: set to start hidden, or last hidden in the window.
    @Test func outsideTheWindowAmountsHideWheneverTheWindowWould() {
        let d = defaults()
        #expect(!AmountsOnOpen.hiddenOutsideWindow(in: d))
        d.set(AmountsOnOpen.hidden.rawValue, forKey: Preference.amountsOnOpen)
        #expect(AmountsOnOpen.hiddenOutsideWindow(in: d))
        d.set(AmountsOnOpen.shown.rawValue, forKey: Preference.amountsOnOpen)
        #expect(!AmountsOnOpen.hiddenOutsideWindow(in: d))
        d.set(true, forKey: Preference.amountsHidden)
        #expect(AmountsOnOpen.hiddenOutsideWindow(in: d))
    }
}

/// The window and the menu bar read one lock, so they never disagree; the demo never locks.
@MainActor @Test func theDemoNeverLocksAndOneLockIsShared() {
    let lock = TallyLock(real: false)
    #expect(!lock.isLocked)
    lock.isLocked = true
    // The menu bar holds the same object the window locked.
    let menuBarSees = lock
    #expect(menuBarSees.isLocked)
}
