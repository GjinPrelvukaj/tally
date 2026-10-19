import Foundation

/// Main at the end of one day. `projected` days have not happened yet.
public struct LinePoint: Sendable, Equatable {
    public var day: Int
    public var balance: Cents
    public var projected: Bool
    /// The day before the first run: the balance typed then. Drawn, but not one of Tally's own days (not the lowest point).
    public var opening = false
}

extension Ledger {
    /// Main at the end of each day of the month: what happened, then today, then a plan-based guess.
    /// The line starts the day before the first run, at the balance typed then (what Main held as that day began), so
    /// the first day's own spending shows; it never makes up a balance from further back. Months after this one have no line yet.
    public func monthLine(_ month: YearMonth, today: Date) -> [LinePoint] {
        guard month >= startMonth else { return [] }
        let firstRun = calendar.startOfDay(for: entries.map(\.date).min() ?? startMonth.date(day: 1, calendar: calendar))
        let opening = calendar.date(byAdding: .day, value: -1, to: firstRun) ?? firstRun
        return wholeMonthLine(month, today: today).compactMap { point in
            let date = month.date(day: point.day, calendar: calendar)
            guard date >= opening else { return nil }
            var point = point
            point.opening = date < firstRun
            return point
        }
    }

    private func wholeMonthLine(_ month: YearMonth, today: Date) -> [LinePoint] {
        let thisMonth = YearMonth(today, calendar: calendar)
        guard month <= thisMonth else { return [] }
        let days = month.days(calendar: calendar)
        let todayDay = month == thisMonth ? calendar.component(.day, from: today) : days + 1
        var points = (1..<todayDay).map {
            LinePoint(day: $0, balance: balance(.main, endOf: month.date(day: $0, calendar: calendar)), projected: false)
        }
        guard month == thisMonth else { return points }
        points.append(LinePoint(day: todayDay, balance: balance(.main), projected: false))
        guard todayDay < days else { return points }

        // The same dues the allowance holds back, so the line and the allowance never disagree.
        let held = stillToPay(today: today).filter { $0.heldBack && $0.item.from == .main }
        let dailySpend = plan.filter { $0.kind == .daily && $0.applies(in: month) }.reduce(Cents.zero) { $0 + $1.amount }
        let arriving = incomes(in: month).filter { !isDone($0.id, in: month) }
        var running = balance(.main)
        for day in (todayDay + 1)...days {
            running = running - dailySpend
            for due in held where landing(of: due, in: month, todayDay: todayDay) == day { running = running - due.item.amount }
            for income in arriving where expectedDay(of: income, in: month, today: today) == day {
                running = running + income.amount - splitOut(of: income, in: month)
            }
            points.append(LinePoint(day: day, balance: running, projected: true))
        }
        return points
    }

    /// The day an income that hasn't arrived lands on the line. One whose day has passed is expected tomorrow, the first projected day.
    func expectedDay(of income: PlanItem, in month: YearMonth, today: Date) -> Int {
        max(calendar.component(.day, from: incomeDate(income, in: month, today: today)), calendar.component(.day, from: today) + 1)
    }

    /// A due dated later this month goes out on its day (a window on its last); every other one is already owed, so it goes out on the first projected day.
    private func landing(of due: Due, in month: YearMonth, todayDay: Int) -> Int {
        guard due.month == month else { return todayDay + 1 }
        switch due.item.schedule {
        case .day(let day), .window(_, let day): return max(calendar.component(.day, from: month.date(day: day, calendar: calendar)), todayDay + 1)
        case .anyDay, .withIncome: return todayDay + 1
        }
    }

    /// What the income's own undone items take out of Main when it arrives.
    private func splitOut(of income: PlanItem, in month: YearMonth) -> Cents {
        plan.filter { $0.schedule == .withIncome(income.id) && $0.from == .main && $0.applies(in: month) && !isDone($0.id, in: month) }
            .compactMap(asked)
            .reduce(Cents.zero) { $0 + $1.amount }
    }
}
