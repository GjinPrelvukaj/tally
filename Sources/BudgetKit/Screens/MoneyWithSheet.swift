import SwiftUI

/// Money with someone: how much, who, what happened (I lent, they paid back, I borrowed, I paid back), and whether
/// it was from before Tally (owed already, so no money moves now). It starts on what is likely: paid back when
/// they owe you, I paid back when you owe them.
struct MoneyWithSheet: View {
    let people: [String?]
    let ledger: Ledger
    let save: (EntryKind, Cents, String?, Bool) -> Void
    let cancel: () -> Void
    @Environment(\.partnerName) private var partnerName
    @State private var amount = ""
    @State private var name: String
    @State private var kind: EntryKind
    @State private var before = false

    init(who: Someone, people: [String?], ledger: Ledger, partnerName: String,
         save: @escaping (EntryKind, Cents, String?, Bool) -> Void, cancel: @escaping () -> Void) {
        self.people = people
        self.ledger = ledger
        self.save = save
        self.cancel = cancel
        let start: String = switch who {
        case .new: ""
        case .partner: partnerName
        case .named(let name): name
        }
        _name = State(initialValue: start)
        let owes = who == .new ? Cents.zero : ledger.owes(who.person)
        _kind = State(initialValue: owes > .zero ? .repayment : owes < .zero ? .paidBack : .lent)
    }

    private var cents: Cents? { Cents.parsePositive(amount) }
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The partner's own name means the partner (nil), so their balance stays one.
    private var person: String? {
        !partnerName.isEmpty && trimmed.caseInsensitiveCompare(partnerName) == .orderedSame ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            AmountField(label: "Amount", text: $amount, valid: amount.isEmpty || cents != nil, autofocus: true)
            VStack(alignment: .leading, spacing: Kit.Space.item) {
                GlassField(label: "Who", text: $name, align: .leading, hint: "Who", secret: false)
                if !people.isEmpty {
                    HStack(spacing: Kit.Space.item) {
                        ForEach(people.filter { $0 != nil || !partnerName.isEmpty }.prefix(5), id: \.self) { someone in
                            let shown = someone ?? partnerName
                            Button(shown) { name = shown }
                                .buttonStyle(.chip(chosen: trimmed.caseInsensitiveCompare(shown) == .orderedSame))
                        }
                    }
                }
            }
            GlassSegments(selection: $kind, choices: [(.lent, "I Lent", "arrow.up.right"), (.repayment, "Paid Me Back", "arrow.down.left"),
                                                      (.borrowed, "I Borrowed", "arrow.down.left"), (.paidBack, "I Paid Back", "arrow.up.right")])
            SettingRow(title: "From before Tally", detail: "Already owed, so no money moves now: only what is owed is kept.") {
                Toggle("", isOn: $before).labelsHidden().toggleStyle(.glass)
            }
            .padding(.horizontal, -14)
            if !trimmed.isEmpty {
                // Only the amount hides with the rest: the words still say what saving will do.
                HStack(spacing: 4) {
                    Text(outcome.words)
                    if let amount = outcome.amount { Text(amount.formatted).monospacedDigit().privacySensitive() }
                }
                .font(Kit.quiet).opacity(0.55)
            }
            SheetFooter(cancel: cancel) {
                Button("Save") { if let cents { save(kind, cents, person, before) } }
                    .buttonStyle(.primary)
                    .disabled(cents == nil || trimmed.isEmpty)
            }
        }
        .modal(close: cancel, light: [.hex(0xF472B6), .arrived, .hex(0xF472B6)])
    }

    /// How it will stand after this, said before it is saved: the words, and the amount apart so it can hide alone.
    private var outcome: (words: String, amount: Cents?) {
        let now = ledger.owes(person)
        let change = cents ?? .zero
        let after = kind == .lent || kind == .paidBack ? now + change : now - change
        let who = trimmed
        if after > .zero { return ("Then \(who) owes you", after) }
        if after < .zero { return ("Then you owe \(who)", Cents(-after.value)) }
        return ("Then you're settled with \(who).", nil)
    }
}
