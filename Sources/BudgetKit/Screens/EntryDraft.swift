import Foundation

/// An entry as edited: the amount stays text until it reads as money. A spend can also change what it was for,
/// whether it went on the card, its note, and how the partner was part of it. `entry` is nil until it can be saved.
struct EntryDraft {
    let original: Entry
    var amount: String
    var category: Category
    var method: PaymentMethod
    var note: String
    var partner: PartnerShare?
    var paysBack: Bool

    /// `ledger` names the entry's category (and knows its pot).
    init(_ entry: Entry, ledger: Ledger) {
        original = entry
        amount = entry.amount.editable
        category = ledger.category(entry.category) ?? .other
        method = entry.method ?? (entry.from == .card ? .card : .bank)
        note = entry.note ?? ""
        partner = entry.partner
        paysBack = entry.owed != nil
    }

    var isSpend: Bool { original.kind == .spend }

    var amountCents: Cents? { Cents.parsePositive(amount) }

    var entry: Entry? {
        guard let cents = amountCents else { return nil }
        var entry = original
        entry.amount = cents
        if isSpend {
            entry.category = category.id
            entry.from = category.pot(paidWith: method)
            entry.method = method
            let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = note.isEmpty ? nil : note
            entry.partner = partner
            let theirs = partner?.theirs(of: cents) ?? .zero
            entry.owed = paysBack && theirs > .zero ? theirs : nil
        }
        return entry
    }
}
