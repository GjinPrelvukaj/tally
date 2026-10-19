import SwiftUI

// Amounts can be hidden, all at once: every amount on screen is marked `.privateAmount()`, and while RootView says
// `amountsHidden` each shows as a soft glass shape, all in one style. One switch for all; Tally starts as Settings says (`AmountsOnOpen`),
// by default the way it was left.

extension EnvironmentValues {
    /// Hides every amount, or shows them again.
    @Entry var toggleAmounts: () -> Void = {}
    /// Whether amounts are hidden now.
    @Entry var amountsHidden = false
}

extension View {
    /// An amount (or words that give one away): while amounts are hidden, a soft glass shape the size of it instead.
    func privateAmount(_ hides: Bool = true) -> some View { modifier(PrivateAmount(hides: hides)) }

    /// A big number (what can be spent, the pots' total, the month's lowest point): hidden with the rest,
    /// and a click on it hides or shows every amount.
    func bigAmount() -> some View { modifier(BigAmount()) }
}

private struct BigAmount: ViewModifier {
    @Environment(\.toggleAmounts) private var toggle

    func body(content: Content) -> some View {
        content
            .privateAmount()
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
            .help("Click to hide or show amounts (⇧⌘H)")
    }
}

/// One look for every hidden amount: the faint fill and hairline of a field, round at the ends, with corners of 10
/// on a tall or many-line one (as a big field's), the size of what it hides.
private struct PrivateAmount: ViewModifier {
    let hides: Bool
    @Environment(\.amountsHidden) private var hidden

    func body(content: Content) -> some View {
        let masked = hides && hidden
        content
            .opacity(masked ? 0 : 1)
            .overlay {
                if masked {
                    GeometryReader { geo in
                        let shape = RoundedRectangle(cornerRadius: min(geo.size.height / 2, 10), style: .continuous)
                        shape.fill(.white.opacity(0.1)).overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }
                    .transition(.opacity)
                }
            }
            .accessibilityHidden(masked)
    }
}
