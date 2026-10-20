import SwiftUI

/// Puts one pot right: type what is really there, the difference is written down as an adjustment.
/// The card is asked as what is owed and kept as a debt.
struct SetBalanceSheet: View {
    let pot: Pot
    let name: String
    let light: Color
    let set: (Cents) -> Void
    let cancel: () -> Void
    @State private var amount: String

    /// Starts from today's figure, so a small change is a small edit.
    init(pot: Pot, name: String, light: Color, balance: Cents, set: @escaping (Cents) -> Void, cancel: @escaping () -> Void) {
        self.pot = pot
        self.name = name
        self.light = light
        self.set = set
        self.cancel = cancel
        _amount = State(initialValue: pot.figure(for: balance).editable)
    }

    /// Below zero is fine: an overdrawn account, or a card paid past what it owed.
    private var cents: Cents? { Cents.parseSigned(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: pot == .card ? "How much do you owe on the card?" : "What's in \(name) right now?", text: $amount, valid: cents != nil, autofocus: true)
            SheetFooter(cancel: cancel) {
                Button("Set Balance", action: confirm)
                    .buttonStyle(.primary(light))
                    .disabled(cents == nil)
            }
        }
        .modal(close: cancel, light: [light, light.opacity(0.5), light])
    }

    private func confirm() {
        guard let cents else { return }
        set(pot.balance(fromFigure: cents))
    }
}
