import SwiftUI

/// What moved money in a month, newest first. A row opens its editor, stacked on the list like Plan's.
struct EntriesSheet: View {
    let store: Store
    let month: YearMonth
    let close: () -> Void
    /// The entry being edited, over the list.
    @State private var editing: EntryDraft?
    private let fade: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            list
                .drawer(close: close, fill: true)
                // Under an open editor it sinks back: a little smaller, darker, out of reach.
                .scaleEffect(editing == nil ? 1 : 0.94, anchor: .top)
                .brightness(editing == nil ? 0 : -0.12)
                .allowsHitTesting(editing == nil)
            if let editing {
                Color.black.opacity(0.35)
                    .onTapGesture(perform: closeEditor)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                EntryEditor(draft: Binding { self.editing ?? editing } set: { self.editing = $0 },
                            save: { store.update($0); closeEditor() },
                            delete: { store.deleteEntry(editing.original.id); closeEditor() },
                            cancel: closeEditor)
                    .drawer(close: closeEditor)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
    }

    private func closeEditor() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { editing = nil }
    }

    private var list: some View {
        let ledger = store.ledger()
        let entries = ledger.entries(in: month)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(month.name) \(String(month.year))").eyebrow()
            if entries.isEmpty {
                Text("Nothing here yet").font(Kit.body).opacity(0.55).padding(.top, Kit.Space.group)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 12) }
                            row(entry, plan: ledger.plan, calendar: ledger.calendar)
                        }
                    }
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                    .padding(.top, Kit.Space.group)
                    .padding(.bottom, fade)
                }
                .scrollIndicators(.never)
                // Rows fade out above the button instead of running under it.
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: fade)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.top, Kit.Space.label)
        }
    }

    /// What it was, the day and where the money went or came from, the amount.
    private func row(_ entry: Entry, plan: [PlanItem], calendar: Calendar) -> some View {
        Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { editing = EntryDraft(entry) }
        } label: {
            HStack(spacing: Kit.Space.item) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title(entry, plan: plan)).font(Kit.body).lineLimit(1)
                    Text(detail(entry, calendar: calendar)).font(Kit.quiet).opacity(0.4).lineLimit(1)
                }
                Spacer(minLength: Kit.Space.item)
                Text(amount(entry)).font(Kit.body).monospacedDigit()
            }
            .opacity(0.9)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func title(_ entry: Entry, plan: [PlanItem]) -> String {
        switch entry.kind {
        case .spend: entry.note ?? entry.category?.title ?? "Spend"
        case .adjustment: "Balance set"
        default: plan.first { $0.id == entry.planItem }?.name ?? entry.kind.rawValue.capitalized
        }
    }

    /// "the 19th · Food · Credit card".
    private func detail(_ entry: Entry, calendar: Calendar) -> String {
        let category = entry.kind == .spend && entry.note != nil ? entry.category?.title : nil
        let pot = entry.kind == .income || entry.kind == .adjustment ? entry.to : entry.from
        return (["the \(ordinal(calendar.component(.day, from: entry.date)))", category, pot?.title] as [String?])
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Money that came in shows "+"; a balance set by hand keeps its sign.
    private func amount(_ entry: Entry) -> String {
        entry.kind == .income ? "+\(entry.amount.formatted)" : entry.amount.formatted
    }
}
