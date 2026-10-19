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

/// A spend in a few seconds: type the amount, tap what it was for. Return logs it under the category used last.
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
            // A plain grid, not a lazy one: lazy items are made after the sheet starts rising and pop in early.
            Grid(horizontalSpacing: Kit.Space.item, verticalSpacing: Kit.Space.item) {
                GridRow { ForEach(Category.allCases.prefix(3), id: \.self, content: chip) }
                GridRow { ForEach(Category.allCases.dropFirst(3), id: \.self, content: chip) }
            }
            .disabled(cents == nil)
            .opacity(cents == nil ? 0.45 : 1)
            GlassField(label: "Note", text: $note, align: .leading, hint: "Note (optional)")
            Toggle("On Card", isOn: $onCard)
                .toggleStyle(.glass)
            SheetFooter(cancel: cancel) {
                Button("Log \(last.title)") { save(last) }
                    .buttonStyle(.primary)
                    .disabled(cents == nil)
            }
        }
        .drawer(close: cancel)
    }

    private func chip(_ category: Category) -> some View {
        Button { save(category) } label: { Text(category.title).frame(maxWidth: .infinity) }
            .buttonStyle(.chip(chosen: category == last))
    }

    private func save(_ category: Category) {
        guard !sent, let cents else { return }
        sent = true
        log(cents, category, note, onCard)
    }
}
