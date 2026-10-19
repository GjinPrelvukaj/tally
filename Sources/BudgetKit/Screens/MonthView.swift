import SwiftUI

/// Month: the Main account as a line through the month, its lowest point, and three quiet numbers.
/// Scrolling up goes back a month at a time, as far as the first month;
/// ⌘← and ⌘→ do the same while Month is showing.
struct MonthView: View {
    let store: Store
    let today: Date
    @State private var scroll = ScrollPosition(idType: YearMonth.self)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ledger = store.ledger()
        let thisMonth = YearMonth(today, calendar: ledger.calendar)
        let months = Array(sequence(first: ledger.startMonth) { $0.next }.prefix { $0 <= thisMonth })
        let shown = scroll.viewID(type: YearMonth.self) ?? thisMonth
        if store.loadError != nil {
            UnreadableView()
        } else {
            pages(ledger, months: months, thisMonth: thisMonth, shown: shown)
        }
    }

    private func pages(_ ledger: Ledger, months: [YearMonth], thisMonth: YearMonth, shown: YearMonth) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            title(shown, in: months)
            // Oldest at the top, this month at the bottom: scrolling up goes back in time.
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(months, id: \.self) { month in
                        MonthPage(ledger: ledger, month: month, today: today, goal: store.goal(.emergency))
                            .containerRelativeFrame(.vertical)
                            .id(month)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.paging)
            .scrollPosition($scroll)
        }
        .pane()
        .onAppear { scroll.scrollTo(id: thisMonth) }
        // A new month opens on itself.
        .onChange(of: thisMonth) { scroll.scrollTo(id: thisMonth) }
    }

    /// "MAIN ACCOUNT", and where you are: "‹ October 2026 ›".
    private func title(_ shown: YearMonth, in months: [YearMonth]) -> some View {
        let i = months.firstIndex(of: shown)
        let earlier = i.flatMap { months.indices.contains($0 - 1) ? months[$0 - 1] : nil }
        let later = i.flatMap { months.indices.contains($0 + 1) ? months[$0 + 1] : nil }
        return HStack(spacing: 6) {
            Text("MAIN ACCOUNT").eyebrow()
            Spacer(minLength: 8)
            turn("chevron.left", to: earlier, key: .leftArrow, label: "Earlier month")
            Text("\(shown.name) \(String(shown.year))").font(.system(size: 11)).monospacedDigit().opacity(0.55)
            turn("chevron.right", to: later, key: .rightArrow, label: "Later month")
        }
    }

    /// At the first or last month it stays, dimmed, and still takes the key so the pager doesn't move instead.
    private func turn(_ symbol: String, to month: YearMonth?, key: KeyEquivalent, label: String) -> some View {
        Button {
            guard let month else { return }
            withAnimation(reduceMotion ? nil : Motion.appear) { scroll.scrollTo(id: month) }
        } label: {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold)).frame(width: 16, height: 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(month == nil ? 0.15 : 0.55)
        .hoverLift()
        .keyboardShortcut(key, modifiers: .command)
        .accessibilityLabel(label)
    }
}

/// One month: its lowest point, the line, and three quiet numbers.
private struct MonthPage: View {
    let ledger: Ledger
    let month: YearMonth
    let today: Date
    let goal: Cents?

    var body: some View {
        let calendar = ledger.calendar
        let todayDay = month == YearMonth(today, calendar: calendar) ? calendar.component(.day, from: today) : nil
        let line = ledger.monthLine(month, today: today)
        VStack(alignment: .leading, spacing: 0) {
            lowest(line.lowest, todayDay: todayDay)
            MonthLine(line: line, days: month.days(calendar: calendar), today: todayDay, paydays: ledger.linePaydays(month, today: today))
                .frame(minHeight: 150, maxHeight: .infinity)
                .padding(.top, 10)
            VStack(spacing: 0) {
                if let end = line.last { row("Left at end of month", end.balance.formatted) }
                row(todayDay == nil ? "Saved" : "Saved this month", ledger.saved(in: month).formatted)
                // Where the fund is heading is about now, so only the current month says it.
                if todayDay != nil, let goal, let reached = ledger.goalMonth(.emergency, goal: goal, today: today) {
                    row("Emergency fund", reached.shortName)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    private func lowest(_ point: LinePoint?, todayDay: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let point {
                RollingDigits(text: point.balance.formatted, font: .system(size: 30, weight: .semibold))
                    .foregroundStyle(point.balance < .zero ? Color.red : .white)
                Text("lowest point · \(point.day == todayDay ? "today" : "the \(ordinal(point.day))")")
                    .font(.system(size: 12)).opacity(0.55)
            } else {
                Text("Nothing here yet").font(.system(size: 12)).opacity(0.55)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).opacity(0.55)
            Spacer(minLength: 8)
            Text(value).monospacedDigit().opacity(0.88)
        }
        .font(.system(size: 13))
        .frame(height: 26)
        .accessibilityElement(children: .combine)
    }
}
