import SwiftUI

// Amounts can be hidden, all at once: every amount on screen is marked `privacySensitive`, and RootView redacts
// them for privacy, so each shows as a soft bar. One switch for all; it is not saved, only started hidden or not.

extension EnvironmentValues {
    /// Hides every amount, or shows them again.
    @Entry var toggleAmounts: () -> Void = {}
}

extension View {
    /// A big number (what can be spent, the pots' total, the month's lowest point): hidden with the rest,
    /// and a click on it hides or shows every amount.
    func bigAmount() -> some View { modifier(BigAmount()) }
}

private struct BigAmount: ViewModifier {
    @Environment(\.toggleAmounts) private var toggle

    func body(content: Content) -> some View {
        content
            .privacySensitive()
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
            .help("Click to hide or show amounts (⇧⌘H)")
    }
}
