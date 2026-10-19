import AppKit
import SwiftUI

/// What is still waiting this month, and anything carried over. A click marks one paid at its planned amount;
/// ⌥-click or Edit changes the amount first; right-click says "Not This Month". An income asks if it arrived.
/// Paying off the card is asked at what is owed; its row says "Set Owed" instead of Edit, as a payment typed there
/// was taken for a correction of what is owed.
struct StillToPayList: View {
    let dues: [Due]
    /// This month's incomes that are not due yet, dimmed at the end; one that arrives early can still be recorded.
    let upcoming: [Due]
    let thisMonth: YearMonth
    let store: Store
    let now: () -> Date
    let onPayday: (Due) -> Void
    let onSetOwed: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Still to pay").groupLabel()
            if dues.isEmpty && upcoming.isEmpty {
                Text("Nothing left to pay this month").font(.system(size: 12)).opacity(0.55).transition(.opacity)
            }
            // Scrolls only when it must, so a short list never takes the pager's swipe.
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }.scrollIndicators(.never)
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 2) {
            ForEach(dues) { due in
                DueRow(due: due, from: due.month < thisMonth ? due.month : nil,
                       pay: { amount in change { store.markPaid(due, amount: amount, at: now()) } },
                       dismiss: { change { store.dismiss(due, at: now()) } },
                       payday: { onPayday(due) }, setOwed: onSetOwed)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity,
                                                                     removal: .move(edge: .trailing).combined(with: .opacity)))
            }
            ForEach(upcoming) { due in
                DueRow(due: due, from: nil, early: true, pay: { _ in }, dismiss: {}, payday: { onPayday(due) }, setOwed: {})
            }
        }
    }

    /// A row leaving and the rest closing up, on a spring; under Reduce Motion only a short fade.
    private func change(_ action: () -> Void) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change, action)
    }
}

/// One line: "Gym · 35,00 €", "2 000 arrived?", or with "· from October" when it is carried over.
private struct DueRow: View {
    let due: Due
    /// The month it is from, when that isn't this one.
    let from: YearMonth?
    /// An income that has not come due yet: dimmed, "650 · from the 15th".
    var early = false
    let pay: (Cents) -> Void
    let dismiss: () -> Void
    let payday: () -> Void
    let setOwed: () -> Void
    @State private var hovering = false
    /// The amount being typed, while the row is being edited.
    @State private var typed: String?
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            let title = early ? "\(due.item.amount.wholeEuros) · from the \(ordinal(due.arrivesFrom ?? 1))"
                : due.isIncome ? "\(due.item.amount.wholeEuros) arrived?" : due.item.name
            let month = Text(from.map { " · from \($0.name)" } ?? "").foregroundStyle(.white.opacity(0.4))
            Text("\(title)\(month)").lineLimit(1)
            Spacer(minLength: 8)
            if typed != nil {
                editor
            } else if early {
                EmptyView()
            } else if due.isIncome {
                // Money on its way: say what a click does, in Today's green.
                Text("Add").font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10).frame(height: 20)
                    .background(Color.arrived.opacity(0.3), in: Capsule())
            } else {
                if hovering {
                    Button(paysOffCard ? "Set Owed" : "Edit", action: paysOffCard ? setOwed : edit)
                        .buttonStyle(.plain).font(Kit.quiet).opacity(0.55).transition(.opacity)
                }
                Text(due.item.amount.formatted).monospacedDigit()
            }
        }
        .font(Kit.body)
        .foregroundStyle(.white.opacity(early ? 0.45 : 0.88))
        .frame(height: 28)
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        .onHover { hovering = $0 }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Motion.hover, value: hovering)
        .hoverLift()
        .contextMenu { if !early { Button("Not This Month", action: dismiss) } }
        // While editing, the field stays its own element so it can be reached.
        .accessibilityElement(children: typed == nil ? .combine : .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tap() }
        .accessibilityAction(named: "Not This Month") { if !early { dismiss() } }
    }

    private var editor: some View {
        HStack(spacing: 6) {
            TextField("", text: Binding { typed ?? "" } set: { typed = $0 })
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 72)
                .focused($fieldFocused)
                .onSubmit(save)
                .onExitCommand { typed = nil }
            Text("€").opacity(0.55)
            Button("Paid", action: save)
                .buttonStyle(.pill(fill: .white.opacity(0.14), height: 22, padding: 10))
                .disabled(typed.flatMap(Cents.parsePositive) == nil)
        }
        .onAppear { fieldFocused = true }
    }

    private var paysOffCard: Bool { due.item.to == .card }

    private func tap() {
        guard typed == nil else { return }
        if due.isIncome { return payday() }
        if NSEvent.modifierFlags.contains(.option) { return edit() }
        pay(due.item.amount)
    }

    /// Starts from the planned amount.
    private func edit() {
        typed = due.item.amount.editable
    }

    /// A typo is never paid: only an amount that reads as money, and above 0, is.
    private func save() {
        guard let amount = typed.flatMap(Cents.parsePositive) else { return }
        typed = nil
        pay(amount)
    }
}
