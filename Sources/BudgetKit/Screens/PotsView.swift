import SwiftUI

/// Pots: each real account as a tube of light, the month's total over them. The card is a tube of what's owed,
/// emptying as it is paid. While an income is due, a quiet "2 000 arrived?" opens the payday sheet from here too.
struct PotsView: View {
    let store: Store
    let today: Date
    let onPayday: (Due) -> Void
    let onSetBalance: (Pot) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ledger = store.ledger()
        let income = ledger.stillToPay(today: today).first(where: \.isIncome)
        if store.loadError != nil {
            UnreadableView()
        } else {
            pots(ledger, income: income)
        }
    }

    private func pots(_ ledger: Ledger, income: Due?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                header(ledger)
                Spacer(minLength: 8)
                if let income { arrived(income) }
            }
            // Not the pane's full height and width: four tall slabs would read as walls, not tubes.
            tubes(ledger)
                .frame(maxWidth: 560, maxHeight: 360)
                .padding(.top, 26)
        }
        .pane()
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change, value: income?.id)
    }

    private func header(_ ledger: Ledger) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(YearMonth(today, calendar: ledger.calendar).name.uppercased())
                .eyebrow()
            RollingDigits(text: ledger.total.formatted, font: .system(size: 30, weight: .semibold))
                .bigAmount()
            Text("across four pots").font(.system(size: 12)).opacity(0.55)
        }
        .accessibilityElement(children: .combine)
    }

    private func arrived(_ income: Due) -> some View {
        Button { onPayday(income) } label: {
            HStack(spacing: 6) {
                Circle().fill(Color.arrived).frame(width: 6, height: 6).shadow(color: .arrived.opacity(0.7), radius: 2.5)
                Text("\(income.item.amount.wholeEuros) arrived?").privateAmount()
            }
            .font(.system(size: 12))
        }
        .buttonStyle(.secondary)
        .padding(.top, 14)
        .transition(.opacity)
    }

    /// One scale for all four, so a taller tube really holds more: the largest goal or amount.
    private func tubes(_ ledger: Ledger) -> some View {
        let goals = Dictionary(uniqueKeysWithValues: Pot.allCases.compactMap { pot in store.goal(pot).map { (pot, $0) } })
        let scale = Tubes.scale(balances: Dictionary(uniqueKeysWithValues: Pot.allCases.map { ($0, ledger.balance($0)) }), goals: goals)
        return HStack(spacing: 14) {
            ForEach(Pot.allCases, id: \.self) { pot in
                let balance = ledger.balance(pot)
                let paidOff = pot == .card && balance == .zero
                VStack(spacing: 8) {
                    Text(paidOff ? "Paid off" : balance.formatted)
                        .privateAmount(!paidOff)
                        .font(.system(size: 12)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .opacity(paidOff ? 0.45 : 0.88)
                    PotTube(level: Tubes.level(Tubes.held(balance, in: pot), of: scale),
                            goal: goals[pot].map { Tubes.level($0, of: scale) }, tint: pot.light)
                    VStack(spacing: 2) {
                        Text(pot.tubeName).opacity(0.55)
                        // Kept even when empty, so every tube is the same height.
                        Text(goals[pot].flatMap { ledger.goalMonth(pot, goal: $0, today: today)?.shortName } ?? " ").opacity(0.4)
                    }
                    .font(.system(size: 11))
                }
                .accessibilityElement(children: .combine)
                .contextMenu { Button("Set Balance…") { onSetBalance(pot) } }
                .accessibilityAction(named: "Set Balance") { onSetBalance(pot) }
            }
        }
    }
}

extension Pot {
    /// Short enough to sit under a tube.
    var tubeName: String {
        switch self {
        case .main: "Main"
        case .clothes: "Clothes"
        case .emergency: "Emergency"
        case .card: "Card"
        }
    }
}
