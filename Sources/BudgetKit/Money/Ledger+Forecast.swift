import Foundation

/// The income the month is waiting for. `late` means its day has passed without it arriving; its date is then today.
public struct NextIncome: Sendable, Equatable {
    public var item: PlanItem
    public var date: Date
    public var late: Bool
}

/// What you can spend each day until the next income. May be negative; it is shown in red, never hidden.
public struct Allowance: Sendable, Equatable {
    public var perDay: Cents
    public var days: Int
    public var until: NextIncome
}

extension Ledger {
    /// The first income of this month that has not arrived yet; with none left, next month's first.
    public func nextIncome(today: Date) -> NextIncome? {
        let now = calendar.startOfDay(for: today)
        let thisMonth = YearMonth(today, calendar: calendar)
        let waiting = incomes(in: thisMonth).filter { !isDone($0.id, in: thisMonth) }
        if let first = earliest(waiting, in: thisMonth, today: today) {
            return NextIncome(item: first.item, date: max(first.date, now), late: first.date < now)
        }
        guard let first = earliest(incomes(in: thisMonth.next), in: thisMonth.next, today: today) else { return nil }
        return NextIncome(item: first.item, date: first.date, late: false)
    }

    /// Main now, minus what is already spoken for, shared over the days until the income (today counts).
    public func allowance(today: Date) -> Allowance? {
        guard let until = nextIncome(today: today) else { return nil }
        let spoken = stillToPay(today: today).filter(\.heldBack).reduce(Cents.zero) { $0 + $1.item.amount }
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: until.date)).day ?? 1)
        return Allowance(perDay: (balance(.main) - spoken).dividedFloor(by: days), days: days, until: until)
    }

    /// The month the pot reaches its goal: today's balance plus what is still planned into it.
    /// Nil when nothing is planned into it, or it would take more than ten years.
    public func goalMonth(_ pot: Pot, goal: Cents, today: Date) -> YearMonth? {
        let thisMonth = YearMonth(today, calendar: calendar)
        let stillThisMonth = plan.filter { $0.to == pot && $0.applies(in: thisMonth) && !isDone($0.id, in: thisMonth) }
        var reached = stillThisMonth.reduce(balance(pot)) { $0 + $1.amount }
        if reached >= goal { return thisMonth }
        var month = thisMonth
        for _ in 0..<120 {
            month = month.next
            reached = plan.filter { $0.to == pot && $0.applies(in: month) }.reduce(reached) { $0 + $1.amount }
            if reached >= goal { return month }
        }
        return nil
    }

    /// The days of this month an income is planned for, for the Today ring.
    public func paydays(today: Date) -> Set<Int> {
        let month = YearMonth(today, calendar: calendar)
        return Set(incomes(in: month).map { calendar.component(.day, from: incomeDate($0, in: month, today: today)) })
    }

    func incomes(in month: YearMonth) -> [PlanItem] {
        plan.filter { $0.kind == .income && $0.applies(in: month) }
    }

    /// A window counts at its last day, so the allowance is careful. An income with no day is taken as today.
    func incomeDate(_ income: PlanItem, in month: YearMonth, today: Date) -> Date {
        switch income.schedule {
        case .day(let day), .window(_, let day): month.date(day: day, calendar: calendar)
        case .anyDay, .withIncome: month == YearMonth(today, calendar: calendar) ? calendar.startOfDay(for: today) : month.date(day: 1, calendar: calendar)
        }
    }

    private func earliest(_ items: [PlanItem], in month: YearMonth, today: Date) -> (item: PlanItem, date: Date)? {
        items.map { (item: $0, date: incomeDate($0, in: month, today: today)) }.min { $0.date < $1.date }
    }
}
