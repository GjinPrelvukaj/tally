import SwiftUI

/// When an income arrives: its amount, then everything planned to go out with it, each amount editable, and
/// what is left in Main. "Add to Main" records it all in one go; Cancel or Escape closes without recording.
struct PaydaySheet: View {
    let income: Due
    let add: (Cents, [UUID: Cents]) -> Void
    let cancel: () -> Void
    @State private var draft: PaydayDraft

    init(income: Due, split: [PlanItem], add: @escaping (Cents, [UUID: Cents]) -> Void, cancel: @escaping () -> Void) {
        self.income = income
        self.add = add
        self.cancel = cancel
        _draft = State(initialValue: PaydayDraft(income: income.item, split: split))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: "\(income.item.name) arrived", text: $draft.amount, valid: Cents.parsePositive(draft.amount) != nil)
            VStack(spacing: 2) {
                ForEach(draft.items) { item in
                    row(item)
                }
            }
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.vertical, 10)
            HStack {
                Text("Left in Main").opacity(0.55)
                Spacer()
                Text(draft.left?.formatted ?? "—").monospacedDigit().privacySensitive()
                    .foregroundStyle(draft.left.map { $0 < .zero } == true ? Color.red : .white)
            }
            .font(.system(size: 13))
            SheetFooter(cancel: cancel) {
                Button("Add to Main", action: confirm)
                    .buttonStyle(.primary)
                    .disabled(!draft.canAdd)
            }
        }
        .drawer(close: cancel)
    }

    /// "Bills · 100,00 €", the amount a field. A name turns red while its amount doesn't read as money.
    private func row(_ item: PlanItem) -> some View {
        let text = Binding { draft.typed[item.id] ?? "" } set: { draft.typed[item.id] = $0 }
        return HStack(spacing: 6) {
            Text(item.name).lineLimit(1)
                .foregroundStyle(Cents.parse(text.wrappedValue) == nil ? Color.red : .white.opacity(0.88))
            Spacer(minLength: 8)
            GlassField(label: item.name, text: text, valid: Cents.parse(text.wrappedValue) != nil).frame(width: Kit.rowAmount)
            Text("€").opacity(0.55)
        }
        .font(.system(size: 13))
        .frame(height: 28)
    }

    private func confirm() {
        guard let amount = Cents.parsePositive(draft.amount), let split = draft.split else { return }
        add(amount, split)
    }
}
