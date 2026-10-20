import SwiftUI

/// What moved money in a month, newest first, any month from the first one to this. A row opens its editor in a
/// panel on the right, the list still beside it.
struct EntriesPane: View {
    let store: Store
    let today: Date
    /// The month shown; nil is this month.
    @State private var chosen: YearMonth?
    /// The entry being edited, in the panel.
    @State private var editing: EntryDraft?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.partnerName) private var partnerName

    var body: some View {
        let ledger = store.ledger()
        let thisMonth = YearMonth(today, calendar: ledger.calendar)
        let month = chosen ?? thisMonth
        HStack(spacing: 0) {
            list(ledger, month: month, thisMonth: thisMonth).pane()
            if let editing {
                SidePanel(close: closeEditor) {
                    // A field losing focus as the panel leaves writes its text one last time: only into the entry
                    // still open, so it can never open a closed editor again (Cancel and the swipe did nothing).
                    EntryEditor(draft: Binding { self.editing ?? editing } set: { draft in
                                    if self.editing?.original.id == draft.original.id { self.editing = draft }
                                },
                                title: editing.original.title(ledger: ledger, partner: partnerName),
                                categories: ledger.categories.filter { !$0.retired || $0.id == editing.category.id },
                                held: ledger.setBalancesHeld(changing: editing.original, to: nil).compactMap { set in
                                    set.to.map { "\(ledger.name($0)) stays at what you set on the \(ordinal(ledger.calendar.component(.day, from: set.date)))." }
                                },
                                save: { store.update($0); closeEditor() },
                                delete: { store.deleteEntry(editing.original.id); closeEditor() },
                                cancel: closeEditor)
                        // Another row clicked starts afresh, its amount focused.
                        .id(editing.original.id)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func closeEditor() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { editing = nil }
    }

    private func list(_ ledger: Ledger, month: YearMonth, thisMonth: YearMonth) -> some View {
        let entries = ledger.entries(in: month)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("ENTRIES").eyebrow()
                Spacer(minLength: 8)
                turn("chevron.left", to: month > ledger.startMonth ? month.previous : nil, label: "Earlier month")
                Text("\(month.name) \(String(month.year))").font(.system(size: 11)).monospacedDigit().opacity(0.55)
                turn("chevron.right", to: month < thisMonth ? month.next : nil, label: "Later month")
            }
            // Clear room under the header, above where the rows fade out.
            .padding(.bottom, Kit.Space.item)
            if entries.isEmpty {
                Text("Nothing here yet").font(Kit.body).opacity(0.55).padding(.top, Kit.Space.group)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 12) }
                            row(entry, ledger: ledger)
                        }
                    }
                    .rowPanel()
                    .padding(.vertical, Kit.fade)
                }
                .scrollIndicators(.never)
                .edgeFade()
            }
        }
    }

    /// At the first or this month it stays, dimmed.
    private func turn(_ symbol: String, to month: YearMonth?, label: String) -> some View {
        Button {
            guard let month else { return }
            editing = nil
            chosen = month
        } label: {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold)).frame(width: 16, height: 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(month == nil ? 0.15 : 0.55)
        .hoverLift()
        .accessibilityLabel(label)
    }

    /// What it was, the day and where the money went or came from, the amount. The one being edited is lit.
    private func row(_ entry: Entry, ledger: Ledger) -> some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { editing = EntryDraft(entry, ledger: ledger) }
        } label: {
            HStack(spacing: Kit.Space.item) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title(ledger: ledger, partner: partnerName)).font(Kit.body).lineLimit(1)
                    Text(entry.detail(ledger: ledger, partner: partnerName)).font(Kit.quiet).opacity(0.4).lineLimit(1)
                }
                Spacer(minLength: Kit.Space.item)
                Text(entry.shownAmount).font(Kit.body).monospacedDigit().privateAmount()
            }
            .opacity(0.9)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.white.opacity(editing?.original.id == entry.id ? 0.06 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Entry {
    /// What it was: a spend's note or category, a plan item's name, money with someone ("Lent to Ben"), or
    /// "Balance set". `partner` names a person who is the partner.
    func title(ledger: Ledger, partner: String) -> String {
        let who = person ?? (partner.isEmpty ? "your partner" : partner)
        return switch kind {
        case .spend: note ?? ledger.category(category)?.name ?? "Spend"
        case .adjustment: "Balance set"
        case .lent: "Lent to \(who)"
        case .repayment: "\(capitalised(who)) paid back"
        case .borrowed: "Borrowed from \(who)"
        case .paidBack: "Paid back \(who)"
        default: ledger.plan.first { $0.id == planItem }?.name ?? kind.rawValue.capitalized
        }
    }

    /// "the 19th, 18:13 · Food · Credit card · with Ana" ("Cash" in place of the pot when paid in cash).
    func detail(ledger: Ledger, partner: String) -> String {
        let shownCategory = kind == .spend && note != nil ? ledger.category(category)?.name : nil
        let pot = kind == .income || kind == .adjustment || kind == .repayment || kind == .borrowed ? to : from
        // Owed from before Tally moved no money: no pot to name.
        let paid = !movesMoney && kind.isWithSomeone ? "from before" : method == .cash ? "Cash" : pot.map(ledger.name)
        let together: String? = switch self.partner {
        case .with: "with \(partner)"
        case .half: "half \(partner)'s"
        case .forThem: "for \(partner)"
        case nil: nil
        }
        let when = "the \(ordinal(ledger.calendar.component(.day, from: date))), \(TimeOfDay(date, calendar: ledger.calendar).formatted)"
        return ([when, shownCategory, paid, partner.isEmpty ? nil : together] as [String?])
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Money that came in shows "+"; a balance set by hand keeps its sign.
    var shownAmount: String {
        kind == .income || ((kind == .repayment || kind == .borrowed) && movesMoney) ? "+\(amount.formatted)" : amount.formatted
    }
}
