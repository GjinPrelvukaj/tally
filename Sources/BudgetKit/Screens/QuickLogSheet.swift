import SwiftUI

extension Category {
    var title: String {
        switch self {
        case .food: "Food"
        case .goingOut: "Going out"
        case .clothes: "Clothes"
        case .fragrance: "Fragrance"
        case .other: "Other"
        }
    }
}

/// A spend in a few seconds: type the amount, say how it was paid, tap what it was for.
/// Return logs it under the category used last.
struct QuickLogSheet: View {
    /// The category Return uses; lit among the chips.
    let last: Category
    let log: (Cents, Category, String?, Bool) -> Void
    let cancel: () -> Void
    @State private var amount = ""
    @State private var note = ""
    @State private var onCard = false
    /// A double-click on a chip or a second Return must not log twice.
    @State private var sent = false

    private var cents: Cents? { Cents.parsePositive(amount) }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: "Spent", text: $amount, valid: amount.isEmpty || cents != nil, autofocus: true)
            // Above the categories: a tap on one logs at once, so how it was paid and the note come first.
            PaidWith(onCard: $onCard)
            GlassField(label: "Note", text: $note, align: .leading, hint: "Note (optional)", secret: false)
            CategoryChips(chosen: last, tap: save)
                .disabled(cents == nil)
                .opacity(cents == nil ? 0.45 : 1)
            SheetFooter(cancel: cancel) {
                Button("Log \(last.title)") { save(last) }
                    .buttonStyle(.primary)
                    .disabled(cents == nil)
            }
        }
        .drawer(close: cancel)
    }

    private func save(_ category: Category) {
        guard !sent, let cents else { return }
        sent = true
        log(cents, category, note, onCard)
    }
}

/// Bank card or credit card, side by side; the chosen one is lit. A spend on the credit card adds to what is owed.
struct PaidWith: View {
    @Binding var onCard: Bool

    var body: some View {
        HStack(spacing: Kit.Space.item) {
            Text("Paid with").groupLabel()
            Spacer(minLength: Kit.Space.item)
            choice("Bank Card", card: false)
            choice("Credit Card", card: true)
        }
    }

    private func choice(_ title: String, card: Bool) -> some View {
        Button(title) { onCard = card }
            .buttonStyle(.chip(chosen: onCard == card))
            .accessibilityAddTraits(onCard == card ? .isSelected : [])
    }
}

/// The five categories as chips in two rows; the chosen one is lit.
struct CategoryChips: View {
    let chosen: Category
    let tap: (Category) -> Void

    var body: some View {
        // A plain grid, not a lazy one: lazy items are made after the sheet starts rising and pop in early.
        Grid(horizontalSpacing: Kit.Space.item, verticalSpacing: Kit.Space.item) {
            GridRow { ForEach(Category.allCases.prefix(3), id: \.self, content: chip) }
            GridRow { ForEach(Category.allCases.dropFirst(3), id: \.self, content: chip) }
        }
    }

    private func chip(_ category: Category) -> some View {
        Button { tap(category) } label: { Text(category.title).frame(maxWidth: .infinity) }
            .buttonStyle(.chip(chosen: category == chosen))
    }
}
