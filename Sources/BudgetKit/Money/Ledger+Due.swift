import Foundation

/// One plan item that is waiting for a month: the line "still to pay" shows.
public struct Due: Identifiable, Hashable, Sendable {
    public var item: PlanItem
    public var month: YearMonth
    /// Its money is spoken for: it takes money out of Main and is ready to go, so the daily allowance must not spend it.
    public var heldBack: Bool
    public var isIncome: Bool

    public var id: String { "\(item.id.uuidString)-\(month.year)-\(month.month)" }

    /// The day of the month an income can first arrive ("from the 15th"); nil when it has no day.
    public var arrivesFrom: Int? {
        switch item.schedule {
        case .day(let day), .window(let day, _): day
        case .anyDay, .withIncome: nil
        }
    }
}

extension Ledger {
    /// Done means "something was written down for it that month", whatever the amount. Dismissing counts too.
    public func isDone(_ item: UUID, in month: YearMonth) -> Bool {
        entries.contains { $0.planItem == item && $0.forMonth == month }
    }

    /// What is paid out of an income when it arrives: that month's items planned "with" it, not yet done, in plan order.
    public func split(of income: Due) -> [PlanItem] {
        plan.filter { $0.schedule == .withIncome(income.item.id) && $0.applies(in: income.month) && !isDone($0.id, in: income.month) }
    }

    /// The items planned "with" this income: what an income's delete or change of kind would leave without one.
    public func waiting(on income: UUID) -> [PlanItem] {
        plan.filter { $0.schedule == .withIncome(income) }
    }

    /// Everything not yet done, oldest month first, so last month's unpaid items carry over until dealt with.
    /// Within a month incomes come first, then the rest in plan order.
    public func stillToPay(today: Date) -> [Due] {
        let thisMonth = YearMonth(today, calendar: calendar)
        var result: [Due] = []
        var month = startMonth
        while month <= thisMonth {
            let open = plan.filter { $0.kind != .daily && $0.applies(in: month) && !isDone($0.id, in: month) }
            let incomes = open.filter { $0.kind == .income && hasArrived($0, in: month, thisMonth: thisMonth, today: today) }
            let rest = open.filter { $0.kind != .income }
            result += (incomes + rest).map { Due(item: $0, month: month, heldBack: isHeldBack($0, in: month), isIncome: $0.kind == .income) }
            month = month.next
        }
        return result
    }

    /// This month's incomes that are not yet due (their day or window has not come), so one that arrives early can still be recorded.
    public func upcomingIncomes(today: Date) -> [Due] {
        let thisMonth = YearMonth(today, calendar: calendar)
        return incomes(in: thisMonth)
            .filter { !isDone($0.id, in: thisMonth) && !hasArrived($0, in: thisMonth, thisMonth: thisMonth, today: today) }
            .map { Due(item: $0, month: thisMonth, heldBack: false, isIncome: true) }
    }

    /// An income shows once its day (or the start of its window) has come; in a past month it always has.
    private func hasArrived(_ income: PlanItem, in month: YearMonth, thisMonth: YearMonth, today: Date) -> Bool {
        guard month == thisMonth else { return true }
        switch income.schedule {
        case .day(let day), .window(let day, _):
            return calendar.startOfDay(for: today) >= month.date(day: day, calendar: calendar)
        case .anyDay, .withIncome:
            return true
        }
    }

    private func isHeldBack(_ item: PlanItem, in month: YearMonth) -> Bool {
        guard item.kind != .income, item.from == .main else { return false }
        // Waiting on an income that is paused, limited to another month or gone would wait for ever.
        if case .withIncome(let income) = item.schedule,
           let waiting = plan.first(where: { $0.id == income }), waiting.applies(in: month) {
            return isDone(income, in: month)
        }
        return true
    }
}
