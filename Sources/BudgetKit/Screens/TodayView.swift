import SwiftUI

/// Today, the screen the app opens on: what you can spend each day until the next income, and what's still to pay.
struct TodayView: View {
    let store: Store
    let today: Date
    /// When an action is recorded: the real time, or the demo's pinned one.
    let now: () -> Date
    let onPayday: (Due) -> Void
    /// Asks what is owed on the card (Set Balance), from the card's own row.
    let onSetOwed: () -> Void
    /// The partner paid back: asks how much.
    let onPaidBack: () -> Void
    @Environment(\.partnerName) private var partnerName

    var body: some View {
        let ledger = store.ledger()
        let calendar = ledger.calendar
        let month = YearMonth(today, calendar: calendar)
        if store.loadError != nil {
            UnreadableView()
        } else {
            screen(ledger, month: month)
        }
    }

    /// The date, then the ring on the left and what's still to pay and spent today beside it, the cards under them,
    /// kept together in the middle. They grow with the window (`TodayLayout`), from the smallest window to a big one.
    private func screen(_ ledger: Ledger, month: YearMonth) -> some View {
        GeometryReader { geo in
            // A third of the room left above, two thirds below; with no room left it starts at the top.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content(ledger, month: month, layout: TodayLayout(width: geo.size.width - 80, height: geo.size.height - 36))
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    private func content(_ ledger: Ledger, month: YearMonth, layout: TodayLayout) -> some View {
        let calendar = ledger.calendar
        let spent = ledger.entries(in: month).filter { $0.kind == .spend && calendar.isDate($0.date, inSameDayAs: today) }
        return VStack(alignment: .leading, spacing: 0) {
            Text(dayTitle(today, calendar: calendar)).eyebrow()
            HStack(alignment: .top, spacing: TodayLayout.gap) {
                ZStack {
                    TodayRing(days: month.days(calendar: calendar), today: calendar.component(.day, from: today),
                              paydays: ledger.paydays(today: today))
                    AllowanceText(allowance: ledger.allowance(today: today), scale: layout.scale)
                }
                .frame(width: layout.ring, height: layout.ring)
                VStack(alignment: .leading, spacing: 28) {
                    StillToPayList(dues: ledger.stillToPay(today: today), upcoming: ledger.upcomingIncomes(today: today),
                                   thisMonth: month, store: store, now: now, onPayday: onPayday, onSetOwed: onSetOwed)
                    SpentToday(entries: spent, ledger: ledger)
                    if !partnerName.isEmpty, ledger.partnerOwes > .zero {
                        PartnerOwes(name: partnerName, owes: ledger.partnerOwes, paidBack: onPaidBack)
                    }
                }
                .frame(width: layout.column, alignment: .topLeading)
            }
            .padding(.top, 28 * layout.scale)
            // As wide as the ring and the lists above.
            TodayCards(ledger: ledger, today: today)
                .frame(width: layout.width)
                .padding(.top, 32 * layout.scale)
        }
        .padding(.top, 36 * layout.scale)
    }
}

/// Today's spends, newest first: what it was and how much.
private struct SpentToday: View {
    let entries: [Entry]
    let ledger: Ledger

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spent today").groupLabel()
            if entries.isEmpty {
                Text("Nothing yet").font(Kit.body).opacity(0.45)
            }
            ForEach(entries) { entry in
                HStack(spacing: 8) {
                    Text(entry.note ?? ledger.category(entry.category)?.name ?? "").lineLimit(1)
                    if entry.from == .card || entry.method == .cash {
                        Text(entry.method == .cash ? "Cash" : "Card").font(Kit.quiet).opacity(0.4)
                    }
                    Spacer(minLength: 8)
                    Text(entry.amount.formatted).monospacedDigit().privateAmount()
                }
                .font(Kit.body)
                .opacity(0.88)
                .frame(height: 28)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Ana owes you 34,00 €", and Paid Back for when they do.
private struct PartnerOwes: View {
    let name: String
    let owes: Cents
    let paidBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(name) owes you").opacity(0.7)
            Text(owes.formatted).monospacedDigit().privateAmount()
            Spacer(minLength: 8)
            Button("Paid Back", action: paidBack).buttonStyle(.secondary)
        }
        .font(Kit.body)
    }
}

/// The ring's centre: "YOU CAN SPEND", the amount a day, and what it lasts until.
private struct AllowanceText: View {
    let allowance: Allowance?
    /// Grows with the ring.
    var scale: CGFloat = 1

    var body: some View {
        if let allowance {
            let income = allowance.until.item.amount.wholeEuros
            VStack(spacing: 4) {
                Text("YOU CAN SPEND").eyebrow()
                amount(allowance.perDay)
                Text("a day until the \(income)").font(.system(size: 12)).opacity(0.55).privateAmount()
                if allowance.until.late {
                    Text("\(income) is late").font(Living.caption).opacity(0.4).privateAmount()
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("Add your income in the plan").font(.system(size: 12)).opacity(0.55)
        }
    }

    /// Rolls when it changes; an amount too wide to roll at full size shrinks instead.
    private func amount(_ perDay: Cents) -> some View {
        let font = Font.system(size: 40 * scale, weight: .semibold)
        return ViewThatFits(in: .horizontal) {
            RollingDigits(text: perDay.formatted, font: font)
            Text(perDay.formatted).font(font).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: 184 * scale)
        .foregroundStyle(perDay < .zero ? Color.red : .white)
        .bigAmount()
    }
}

/// How big Today is drawn for the space it has: the ring and the column beside it grow together with the window,
/// from the smallest window (a ring of 240) to a ring of 380 in a big one, the cards as wide as both.
struct TodayLayout {
    static let gap: CGFloat = 36
    let ring: CGFloat
    let column: CGFloat

    init(width: CGFloat, height: CGFloat) {
        // The ring takes about two fifths of the width and half the height, whichever is less.
        ring = min(380, max(240, min(width * 0.4, (height - 220) * 0.55)))
        column = min(460, max(300, width - ring - Self.gap))
    }

    var width: CGFloat { ring + Self.gap + column }
    /// The ring's size against the smallest one, for the type and gaps that grow with it.
    var scale: CGFloat { ring / 240 }
}
