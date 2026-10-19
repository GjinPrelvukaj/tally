import Foundation

/// The few choices kept in the app's preferences (not in `Budget.store`: they are about this Mac, not the money).
public enum Preference {
    /// Ask for Touch ID (or the Mac's password) when Tally opens and after the Mac sleeps.
    public static let lock = "lockWithTouchID"
    /// Start with every amount hidden.
    public static let hideAmounts = "hideAmountsOnOpen"
}
