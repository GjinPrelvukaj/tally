import SwiftUI

/// Today, the screen the app opens on: what you can spend each day until the next income, and what's still to pay.
struct TodayView: View {
    let store: Store
    let today: Date
    /// When an action is recorded: the real time, or the demo's pinned one.
    let now: () -> Date
    let onPayday: (Due) -> Void

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

    private func screen(_ ledger: Ledger, month: YearMonth) -> some View {
        let calendar = ledger.calendar
        return VStack(spacing: 0) {
            ZStack {
                TodayRing(days: month.days(calendar: calendar), today: calendar.component(.day, from: today),
                          paydays: ledger.paydays(today: today))
                AllowanceText(allowance: ledger.allowance(today: today))
            }
            .frame(width: 240, height: 240)
            .padding(.top, 18)
            StillToPayList(dues: ledger.stillToPay(today: today), upcoming: ledger.upcomingIncomes(today: today), thisMonth: month, store: store, now: now, onPayday: onPayday)
                .padding(.top, 26)
                .padding(.horizontal, 30)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// The ring's centre: "YOU CAN SPEND", the amount a day, and what it lasts until.
private struct AllowanceText: View {
    let allowance: Allowance?

    var body: some View {
        if let allowance {
            let income = allowance.until.item.amount.wholeEuros
            VStack(spacing: 4) {
                Text("YOU CAN SPEND").eyebrow()
                amount(allowance.perDay)
                Text("a day until the \(income)").font(.system(size: 12)).opacity(0.55)
                if allowance.until.late {
                    Text("\(income) is late").font(Living.caption).opacity(0.4)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("Add your income in the plan").font(.system(size: 12)).opacity(0.55)
        }
    }

    /// Rolls when it changes; an amount too wide to roll at full size shrinks instead.
    private func amount(_ perDay: Cents) -> some View {
        let font = Font.system(size: 40, weight: .semibold)
        return ViewThatFits(in: .horizontal) {
            RollingDigits(text: perDay.formatted, font: font)
            Text(perDay.formatted).font(font).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: 184)
        .foregroundStyle(perDay < .zero ? Color.red : .white)
    }
}
