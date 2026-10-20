import SwiftUI

/// One entry, opened from the month's list. A spend can change its amount, category, how it was paid and note;
/// a payment or income only its amount; a balance set by hand can only be deleted.
struct EntryEditor: View {
    @Binding var draft: EntryDraft
    /// What it is ("Rent", "coffee"), over its amount.
    let title: String
    /// The categories offered: the ones in use, and this entry's own even if it was retired.
    let categories: [Category]
    /// Balances set by hand after it, which deleting it leaves as they were: "Credit card stays at what you set on the 19th."
    var held: [String] = []
    let save: (Entry) -> Void
    let delete: () -> Void
    let cancel: () -> Void
    @State private var confirmingDelete = false
    @Environment(\.partnerName) private var partnerName

    private var isAdjustment: Bool { draft.original.kind == .adjustment }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            if isAdjustment {
                Text("BALANCE SET").eyebrow()
                Text("A balance set by hand. Delete it to take it back.").font(Kit.body).opacity(0.7)
            } else {
                AmountField(label: title, text: $draft.amount,
                            valid: draft.amountCents != nil)
                // When on its day it happened, for one logged later than that.
                HStack(spacing: Kit.Space.item) {
                    Text("Time").font(Kit.body).opacity(0.55)
                    GlassField(label: "Time", text: $draft.time, valid: TimeOfDay(draft.time) != nil, hint: "18:30", secret: false)
                        .frame(width: Kit.rowAmount)
                }
            }
            if draft.isSpend {
                // In Quick log's order: what it was for, how it was paid, who with, a note.
                CategoryChips(categories: categories, chosen: draft.category) { draft.category = $0 }
                PaymentMethodPicker(method: $draft.method)
                if !partnerName.isEmpty { PartnerChoice(name: partnerName, share: $draft.partner, paysBack: $draft.paysBack) }
                NoteField(text: $draft.note)
            }
            Spacer(minLength: 0)
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
        ([draft.original.planItem != nil ? "It will be due again." : "The money goes back as if it never happened."] + held)
            .joined(separator: " ")
    }
}
