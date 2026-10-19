import SwiftUI

/// The first run: what's in each pot right now (the card as what is owed), then which of this month's items
/// are already paid, then "Start". Nothing is saved until Start.
struct FirstRunView: View {
    let store: Store
    let today: Date
    @State private var draft: FirstRunDraft
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pots = Pot.allCases
    private var month: YearMonth { YearMonth(today, calendar: store.ledger().calendar) }

    init(store: Store, today: Date) {
        self.store = store
        self.today = today
        _draft = State(initialValue: FirstRunDraft(month: YearMonth(today, calendar: store.ledger().calendar)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(step == 0 ? "WELCOME" : "STEP \(step + 1) OF \(pots.count + 1)")
                .eyebrow()
            Group {
                if step < pots.count { balance(pots[step]) } else { paid }
            }
            .id(step)
            .transition(.opacity)
            Spacer(minLength: 8)
            buttons
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 30)
    }

    // MARK: A pot

    private func balance(_ pot: Pot) -> some View {
        let text = Binding { draft.typed[pot] ?? "" } set: { draft.typed[pot] = $0 }
        return VStack(alignment: .leading, spacing: 0) {
            Text(Self.question(pot))
                .font(Kit.title).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 70)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GlassField(label: pot.title, text: text, large: true, align: .leading,
                           valid: text.wrappedValue.isEmpty || Cents.parse(text.wrappedValue) != nil, autofocus: true)
                    .frame(width: 160)
                Text("€").font(.system(size: 17, weight: .semibold)).opacity(0.5)
            }
            .padding(.top, 22)
            if step == 0 {
                Text("You can correct any of these later: right-click a tube on Pots.").font(.system(size: 12)).opacity(0.45).padding(.top, 14)
            }
        }
    }

    // MARK: This month

    private var paid: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Already paid in \(month.name)?").font(Kit.title).padding(.top, 22)
            Text("Tick what is already out of the balances you typed.").font(.system(size: 12)).opacity(0.55).padding(.top, 4)
            ScrollView {
                VStack(spacing: 2) { ForEach(draft.items) { row($0) } }.padding(.vertical, 12)
            }
            .scrollIndicators(.never)
        }
    }

    private func row(_ item: PlanItem) -> some View {
        let ticked = draft.paid.contains(item.id)
        let text = Binding { draft.amounts[item.id] ?? "" } set: { draft.amounts[item.id] = $0 }
        return HStack(spacing: 8) {
            Button {
                if ticked { draft.paid.remove(item.id) } else { draft.paid.insert(item.id) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ticked ? Color.arrived : .white.opacity(0.35))
                    Text(item.name).lineLimit(1).opacity(ticked ? 0.95 : 0.7)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(ticked ? .isSelected : [])
            if ticked {
                GlassField(label: "\(item.name), paid", text: text, valid: Cents.parse(text.wrappedValue) != nil).frame(width: 90)
                Text("€").opacity(0.55)
            } else {
                Text(item.amount.formatted).monospacedDigit().opacity(0.4)
            }
        }
        .font(.system(size: 13))
        .frame(height: 28)
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack {
            if step > 0 {
                Button("Back") { go(step - 1) }
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            if step < pots.count {
                Button("Next") { go(step + 1) }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.balance(pots[step]) == nil)
            } else {
                Button("Start", action: start)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.paidAmounts == nil)
            }
        }
    }

    private func go(_ to: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { step = to }
    }

    private func start() {
        guard let balances = draft.balances, let paid = draft.paidAmounts else { return }
        store.setUp(balances: balances, paid: paid, today: today)
    }
}

extension FirstRunView {
    /// One plain question per pot.
    static func question(_ pot: Pot) -> String {
        switch pot {
        case .main: "How much is in your main account right now?"
        case .clothes: "How much is in your clothes pot?"
        case .emergency: "How much is in your emergency fund?"
        case .card: "How much do you owe on the card?"
        }
    }
}
