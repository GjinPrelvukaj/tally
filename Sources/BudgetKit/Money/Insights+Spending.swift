import Foundation

// Insights about spending: running short before payday (or the good news that it won't), a pace faster than the
// allowance, small spends that add up, and each category against the same days of last month.

extension Ledger {
    /// Where Main's line first goes below 0 before the next income; if it never does, what it reaches the income with.
    func shortfall(today: Date) -> [Insight] {
        guard let allowance = allowance(today: today) else { return [] }
        let month = YearMonth(today, calendar: calendar)
        let income = allowance.until
        let incomeDay = YearMonth(income.date, calendar: calendar) == month ? calendar.component(.day, from: income.date) : Int.max
        let ahead = monthLine(month, today: today).filter { $0.projected && $0.day < incomeDay }
        let named = "the \(income.item.amount.wholeEuros)"
        if let short = ahead.first(where: { $0.balance < .zero }) {
            let daily = plan.filter { $0.kind == .daily && $0.applies(in: month) }.reduce(Cents.zero) { $0 + $1.amount }
            let pace = daily > .zero ? "At the plan's \(daily.formatted) a day" : "At the plan's pace"
            let fix = allowance.perDay > .zero
                ? "Keep to \(allowance.perDay.formatted) a day to reach it."
                : "What is still to pay before it already takes more than Main holds."
            return [Insight(id: "runningShort", kind: .runningShort, level: .warning,
                            title: "Main runs out on the \(ordinal(short.day))",
                            detail: "\(pace) it goes below 0 before \(named). \(fix)")]
        }
        guard let last = ahead.last else { return [] }
        return [Insight(id: "onTrack", kind: .onTrack, level: .good,
                        title: "Main reaches \(named) with \(last.balance.formatted) to spare",
                        detail: "At the plan's pace. Keep to \(allowance.perDay.formatted) a day to be sure of it.")]
    }

    /// The last 7 days' spends out of Main a day, when that is more than the allowance: how long Main lasts at it.
    /// Fewer than 3 days written down is too soon to tell.
    func pace(today: Date) -> [Insight] {
        guard let allowance = allowance(today: today) else { return [] }
        let start = max(firstDay, calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: today))!)
        let days = (calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: today)).day ?? 0) + 1
        guard days >= 3 else { return [] }
        let spent = spends(from: start, through: dayAfter(today)).filter { $0.from == .main }.reduce(Cents.zero) { $0 + $1.amount }
        let perDay = spent.dividedFloor(by: days)
        // A little over is noise: a fifth more, and at least a euro.
        guard perDay > allowance.perDay + max(.euros(1), allowance.perDay.dividedFloor(by: 5)) else { return [] }
        let lasts = balance(.main) > .zero && perDay > .zero ? balance(.main).value / perDay.value : 0
        return [Insight(id: "pace", kind: .pace, level: lasts < allowance.days ? .warning : .notice,
                        title: "This week you spent \(perDay.formatted) a day",
                        detail: "The plan allows \(allowance.perDay.formatted) a day until the \(allowance.until.item.amount.wholeEuros). "
                            + "At this pace Main lasts \(lasts) more day\(lasts == 1 ? "" : "s").")]
    }

    /// A spend repeated at least 4 times in 30 days (same note; or, with no note, the same category of your own),
    /// with what it costs a year at that rate. The three most frequent.
    func habits(today: Date) -> [Insight] {
        let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: today))!
        let starters = Set(Category.starters.map(\.id))
        let groups = Dictionary(grouping: spends(from: start, through: dayAfter(today))) { entry -> String? in
            if let note = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !note.isEmpty { return note }
            guard let id = entry.category, !starters.contains(id) else { return nil }
            return category(id)?.name.lowercased()
        }
        return groups.compactMap { key, spends -> (String, [Entry])? in key.map { ($0, spends) } }
            .filter { $0.1.count >= 4 }
            .sorted { ($0.1.count, $0.0) > ($1.1.count, $1.0) }
            .prefix(3)
            .map { key, spends in
                let total = spends.reduce(Cents.zero) { $0 + $1.amount }
                return Insight(id: "habit-\(key)", kind: .habit, level: .notice,
                               title: "\(capitalised(key)): \(spends.count) times in 30 days",
                               detail: "\(total.formatted) in 30 days; about \(Cents(total.value * 365 / 30).formatted) a year.")
            }
    }

    /// Each category's spending by today's day of the month against the same days of last month: the two that moved
    /// most, when by at least 10 € and a quarter of last month's. Up is news; down is good news.
    func monthAgainstLast(today: Date) -> [Insight] {
        let month = YearMonth(today, calendar: calendar)
        let last = month.previous
        guard last >= startMonth else { return [] }
        let day = calendar.component(.day, from: today)
        func byCategory(_ m: YearMonth) -> [String: Cents] {
            let start = m.date(day: 1, calendar: calendar)
            let end = dayAfter(m.date(day: min(day, m.days(calendar: calendar)), calendar: calendar))
            return Dictionary(grouping: spends(from: start, through: end)) { $0.category ?? Category.other.id }
                .mapValues { $0.reduce(Cents.zero) { $0 + $1.amount } }
        }
        let now = byCategory(month), before = byCategory(last)
        let lastDay = min(day, last.days(calendar: calendar))
        return Set(now.keys).union(before.keys)
            .map { ($0, now[$0] ?? .zero, before[$0] ?? .zero) }
            .filter { _, this, then in
                let change = abs(this.value - then.value)
                return change >= 1000 && change * 4 >= then.value
            }
            .sorted { (abs($0.1.value - $0.2.value), $0.0) > (abs($1.1.value - $1.2.value), $1.0) }
            .prefix(2)
            // Typed out, and the title in parts: the compiler on GitHub's runners gave up working it out.
            .map { (id: String, this: Cents, then: Cents) -> Insight in
                let name = category(id)?.name ?? Category.other.name
                let up = this > then
                let change = Cents(abs(this.value - then.value)).formatted
                let way = up ? "up" : "down"
                return Insight(id: "month-\(id)", kind: .month, level: up ? .notice : .good,
                               title: "\(name) is \(way) \(change) on last month",
                               detail: "\(this.formatted) by the \(ordinal(day)), against \(then.formatted) by the \(ordinal(lastDay)) of \(last.name).")
            }
    }
}
