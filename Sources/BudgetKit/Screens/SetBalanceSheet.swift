import SwiftUI

/// Puts one pot right: type what is really there, the difference is written down as an adjustment.
/// The card is asked as what is owed and kept as a debt.
struct SetBalanceSheet: View {
    let pot: Pot
    let set: (Cents) -> Void
    let cancel: () -> Void
    @State private var amount: String

    /// Starts from today's figure, so a small change is a small edit.
    init(pot: Pot, balance: Cents, set: @escaping (Cents) -> Void, cancel: @escaping () -> Void) {
        self.pot = pot
        self.set = set
        self.cancel = cancel
        _amount = State(initialValue: pot.figure(for: balance).editable)
    }

    private var cents: Cents? { Cents.parse(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: pot == .card ? "How much do you owe on the card?" : "What's in \(pot.title) right now?", text: $amount, valid: cents != nil, autofocus: true)
            SheetFooter(cancel: cancel) {
                Button("Set Balance", action: confirm)
                    .buttonStyle(.primary(pot.light))
                    .disabled(cents == nil)
            }
        }
        .modal(close: cancel, light: [pot.light, pot.light.opacity(0.5), pot.light])
    }

    private func confirm() {
        guard let cents else { return }
        set(pot.balance(fromFigure: cents))
    }
}
