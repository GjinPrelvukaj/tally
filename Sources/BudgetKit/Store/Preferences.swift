import Foundation

/// The few choices kept in the app's preferences (not in `Budget.store`: they are about this Mac, not the money).
public enum Preference {
    /// Ask for Touch ID (or the Mac's password) when Tally opens and after the Mac sleeps.
    public static let lock = "lockWithTouchID"
    /// How amounts start when Tally opens (`AmountsOnOpen`).
    public static let amountsOnOpen = "amountsOnOpen"
    /// Whether amounts were hidden when Tally was last used, for "As I Left Them".
    public static let amountsHidden = "amountsHidden"
    /// Before the choice there was one switch, "always start hidden".
    static let hideAmounts = "hideAmountsOnOpen"
}

/// How amounts start when Tally opens.
public enum AmountsOnOpen: String, CaseIterable, Sendable {
    case shown, hidden, asLeft

    public var title: String {
        switch self {
        case .shown: "Shown"
        case .hidden: "Hidden"
        case .asLeft: "As I Left Them"
        }
    }

    public func startsHidden(lastHidden: Bool) -> Bool {
        switch self {
        case .shown: false
        case .hidden: true
        case .asLeft: lastHidden
        }
    }

    /// The saved choice. Nothing saved is As I Left Them; the old "always start hidden" switch, if on, is Hidden.
    public static func saved(in defaults: UserDefaults) -> AmountsOnOpen {
        if let raw = defaults.string(forKey: Preference.amountsOnOpen), let choice = AmountsOnOpen(rawValue: raw) { return choice }
        return defaults.bool(forKey: Preference.hideAmounts) ? .hidden : .asLeft
    }
}
