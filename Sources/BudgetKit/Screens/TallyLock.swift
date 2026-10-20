import Foundation
import Observation

/// Whether Tally is locked right now: one for the window and the menu bar, so they never disagree. The window locks it
/// (on opening with the setting on, and when the Mac sleeps) and unlocks it with Touch ID; the menu bar only reads it.
@MainActor @Observable public final class TallyLock {
    public internal(set) var isLocked: Bool

    /// Locked to begin with in the real app when the setting is on; the demo never locks.
    public init(real: Bool) {
        isLocked = real && UserDefaults.standard.bool(forKey: Preference.lock)
    }
}
