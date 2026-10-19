import SwiftUI

/// One entry, opened from the month's list. A spend can change its amount, category, how it was paid and note;
/// a payment or income only its amount; a balance set by hand can only be deleted.
struct EntryEditor: View {
    @Binding var draft: EntryDraft
    let save: (Entry) -> Void
    let delete: () -> Void
    let cancel: () -> Void
    @State private var confirmingDelete = false

    private var isAdjustment: Bool { draft.original.kind == .adjustment }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            if isAdjustment {
                Text("BALANCE SET").eyebrow()
                Text("A balance set by hand. Delete it to take it back.").font(Kit.body).opacity(0.7)
            } else {
                AmountField(label: draft.isSpend ? "Spent" : "Amount", text: $draft.amount,
                            valid: draft.amountCents != nil, autofocus: true)
            }
            if draft.isSpend {
                PaidWith(onCard: $draft.onCard)
                GlassField(label: "Note", text: $draft.note, align: .leading, hint: "Note (optional)")
                CategoryChips(chosen: draft.category) { draft.category = $0 }
            }
            Button(isAdjustment ? "Delete…" : "Delete Entry…") { confirmingDelete = true }
                .buttonStyle(.plain).font(Kit.body).foregroundStyle(.red.opacity(0.85))
                .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete) {
                    Button("Delete", role: .destructive, action: delete)
                } message: { Text(deleteNote) }
            SheetFooter(cancel: cancel) {
                if !isAdjustment {
                    Button("Save") { if let entry = draft.entry { save(entry) } }
                        .buttonStyle(.primary)
                        .disabled(draft.entry == nil)
                }
            }
        }
    }

    /// Said before, so nothing comes as a surprise.
    private var deleteNote: String {
        draft.original.planItem != nil ? "It will be due again." : "The money goes back as if it never happened."
    }
}
