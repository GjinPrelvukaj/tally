import SwiftUI

/// Under Today's ring and lists: three small cards, so a wide window holds a glance at the rest of the money.
/// The next pay, Main through the month, and each pot.
struct TodayCards: View {
    let ledger: Ledger
    let today: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            card("NEXT PAY") { nextPay }
            card("MAIN THIS MONTH") { mainLine }
            card("POTS") { pots }
        }
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            Text(title).eyebrow()
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .rowPanel()
    }

    @ViewBuilder private var nextPay: some View {
        if let next = ledger.nextIncome(today: today) {
            let calendar = ledger.calendar
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: next.date)).day ?? 0
            Text(next.item.amount.formatted).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6).privateAmount()
            Text(next.item.name).font(Kit.body).opacity(0.7).lineLimit(1)
            Text(next.late ? "late" : days <= 0 ? "today" : "the \(ordinal(calendar.component(.day, from: next.date))) · in \(days) day\(days == 1 ? "" : "s")")
                .font(Kit.quiet).opacity(0.45)
        } else {
            Text("Add your income in the plan").font(Kit.quiet).opacity(0.45)
        }
    }

    private var mainLine: some View {
        let calendar = ledger.calendar
        let month = YearMonth(today, calendar: calendar)
        let line = ledger.monthLine(month, today: today)
        return VStack(alignment: .leading, spacing: 4) {
            MonthLine(line: line, days: month.days(calendar: calendar), today: calendar.component(.day, from: today), paydays: [])
                .frame(height: 56)
            if let end = line.last {
                Text("ends at \(end.balance.formatted)").font(Kit.quiet).opacity(0.45).privateAmount()
            }
        }
    }

    private var pots: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Pot.allCases, id: \.self) { pot in
                HStack(spacing: 6) {
                    Circle().fill(pot.light).frame(width: 6, height: 6)
                    Text(pot.tubeName).font(Kit.quiet).opacity(0.7).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(ledger.balance(pot).short).font(Kit.quiet).monospacedDigit().privateAmount()
                }
            }
        }
    }
}
