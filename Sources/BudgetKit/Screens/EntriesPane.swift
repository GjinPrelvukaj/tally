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
    private let fade: CGFloat = 16
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
                    EntryEditor(draft: Binding { self.editing ?? editing } set: { self.editing = $0 },
                                title: editing.original.title(ledger: ledger),
                                categories: ledger.categories.filter { !$0.retired || $0.id == editing.category.id },
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
                    .padding(.top, Kit.Space.group)
                    .padding(.bottom, fade)
                }
                .scrollIndicators(.never)
                // Rows fade out at the bottom instead of being cut.
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: fade)
                    }
                }
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
                    Text(entry.title(ledger: ledger)).font(Kit.body).lineLimit(1)
                    Text(entry.detail(ledger: ledger, partner: partnerName)).font(Kit.quiet).opacity(0.4).lineLimit(1)
                }
                Spacer(minLength: Kit.Space.item)
                Text(entry.shownAmount).font(Kit.body).monospacedDigit().privacySensitive()
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
    /// What it was: a spend's note or category, a plan item's name, "Paid back" or "Balance set".
    func title(ledger: Ledger) -> String {
        switch kind {
        case .spend: note ?? ledger.category(category)?.name ?? "Spend"
        case .adjustment: "Balance set"
        case .repayment: "Paid back"
        default: ledger.plan.first { $0.id == planItem }?.name ?? kind.rawValue.capitalized
        }
    }

    /// "the 19th · Food · Credit card · with Ana" ("Cash" in place of the pot when paid in cash).
    func detail(ledger: Ledger, partner: String) -> String {
        let shownCategory = kind == .spend && note != nil ? ledger.category(category)?.name : nil
        let pot = kind == .income || kind == .adjustment || kind == .repayment ? to : from
        let paid = method == .cash ? "Cash" : pot?.title
        let together: String? = switch self.partner {
        case .with: "with \(partner)"
        case .half: "half \(partner)'s"
        case .forThem: "for \(partner)"
        case nil: nil
        }
        return (["the \(ordinal(ledger.calendar.component(.day, from: date)))", shownCategory, paid, partner.isEmpty ? nil : together] as [String?])
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Money that came in shows "+"; a balance set by hand keeps its sign.
    var shownAmount: String { kind == .income || kind == .repayment ? "+\(amount.formatted)" : amount.formatted }
}
