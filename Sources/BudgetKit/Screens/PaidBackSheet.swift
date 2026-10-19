import SwiftUI

/// The partner paid back: how much (starting from all they owe), into Main.
struct PaidBackSheet: View {
    let name: String
    let add: (Cents) -> Void
    let cancel: () -> Void
    @State private var amount: String

    init(name: String, owes: Cents, add: @escaping (Cents) -> Void, cancel: @escaping () -> Void) {
        self.name = name
        self.add = add
        self.cancel = cancel
        _amount = State(initialValue: owes.editable)
    }

    private var cents: Cents? { Cents.parsePositive(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: "\(name) paid back", text: $amount, valid: cents != nil, autofocus: true)
            SheetFooter(cancel: cancel) {
                Button("Add to Main") { if let cents { add(cents) } }
                    .buttonStyle(.primary)
                    .disabled(cents == nil)
            }
        }
        .modal(close: cancel)
    }
}
