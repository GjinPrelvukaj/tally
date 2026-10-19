import Foundation

/// An entry as edited: the amount stays text until it reads as money. A spend can also change what it was for,
/// whether it went on the card, and its note. `entry` is nil until it can be saved.
struct EntryDraft {
    let original: Entry
    var amount: String
    var category: Category
    var onCard: Bool
    var note: String

    init(_ entry: Entry) {
        original = entry
        amount = entry.amount.editable
        category = entry.category ?? .other
        onCard = entry.from == .card
        note = entry.note ?? ""
    }

    var isSpend: Bool { original.kind == .spend }

    var amountCents: Cents? { Cents.parsePositive(amount) }

    var entry: Entry? {
        guard let cents = amountCents else { return nil }
        var entry = original
        entry.amount = cents
        if isSpend {
            entry.category = category
            entry.from = category.pot(onCard: onCard)
            let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = note.isEmpty ? nil : note
        }
        return entry
    }
}
