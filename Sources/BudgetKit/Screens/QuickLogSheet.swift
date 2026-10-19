import SwiftUI

/// Everything Quick log knows about one spend.
struct LoggedSpend {
    var amount: Cents
    var category: Category
    var note: String
    var method: PaymentMethod
    var partner: PartnerShare?
    var paysBack: Bool
}

/// A spend in a few seconds: type the amount, say how it was paid, tap what it was for.
/// Return logs it under the category used last.
struct QuickLogSheet: View {
    /// The categories offered (not the retired ones).
    let categories: [Category]
    /// The category Return uses; lit among the chips.
    let last: Category
    let log: (LoggedSpend) -> Void
    let cancel: () -> Void
    @State private var amount = ""
    @State private var note = ""
    @State private var method = PaymentMethod.bank
    @State private var partner: PartnerShare?
    @State private var paysBack = false
    /// A double-click on a chip or a second Return must not log twice.
    @State private var sent = false
    @Environment(\.partnerName) private var partnerName

    private var cents: Cents? { Cents.parsePositive(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: "Spent", text: $amount, valid: amount.isEmpty || cents != nil, autofocus: true)
            // Above the categories: a tap on one logs at once, so everything else comes first.
            PaymentMethodPicker(method: $method)
            if !partnerName.isEmpty { PartnerChoice(name: partnerName, share: $partner, paysBack: $paysBack) }
            GlassField(label: "Note", text: $note, align: .leading, hint: "Note (optional)", secret: false)
            CategoryChips(categories: categories, chosen: last, tap: save)
                .disabled(cents == nil)
                .opacity(cents == nil ? 0.45 : 1)
            SheetFooter(cancel: cancel) {
                Button("Log \(last.name)") { save(last) }
                    .buttonStyle(.primary)
                    .disabled(cents == nil)
            }
        }
        .modal(close: cancel)
    }

    private func save(_ category: Category) {
        guard !sent, let cents else { return }
        sent = true
        log(LoggedSpend(amount: cents, category: category, note: note, method: method, partner: partner, paysBack: paysBack))
    }
}

/// Bank card, credit card or cash, as one glass bar. The credit card adds to what it owes; the other two come out of
/// the category's pot.
struct PaymentMethodPicker: View {
    @Binding var method: PaymentMethod

    var body: some View {
        GlassSegments(selection: $method, choices: [(.bank, "Bank Card", "creditcard"),
                                                    (.card, "Credit Card", "creditcard.and.123"),
                                                    (.cash, "Cash", "banknote")])
    }
}

/// The categories as chips, three to a row; the chosen one is lit.
struct CategoryChips: View {
    let categories: [Category]
    let chosen: Category
    let tap: (Category) -> Void

    var body: some View {
        // A plain grid, not a lazy one: lazy items are made after the sheet starts rising and pop in early.
        Grid(horizontalSpacing: Kit.Space.item, verticalSpacing: Kit.Space.item) {
            ForEach(Array(stride(from: 0, to: categories.count, by: 3)), id: \.self) { start in
                GridRow {
                    ForEach(categories[start..<min(start + 3, categories.count)]) { chip($0) }
                }
            }
        }
    }

    private func chip(_ category: Category) -> some View {
        Button { tap(category) } label: { Text(category.name).lineLimit(1).frame(maxWidth: .infinity) }
            .buttonStyle(.chip(chosen: category.id == chosen.id))
    }
}
