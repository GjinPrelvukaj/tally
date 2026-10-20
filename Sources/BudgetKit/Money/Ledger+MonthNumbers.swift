import Foundation

/// An income on the month line: where Main jumps. `projected` ones haven't arrived yet.
public struct LinePayday: Sendable, Equatable {
    public var day: Int
    public var amount: Cents
    public var projected: Bool
}

extension [LinePoint] {
    /// The lowest balance on the line, on the first day it is reached; the day before the first run isn't one of them.
    public var lowest: LinePoint? { filter { !$0.opening }.min { $0.balance < $1.balance } }
}

extension Ledger {
    /// What went into Clothes and the Emergency fund during the month. Corrections (`adjustment`) aren't saving.
    /// Transfers ticked as paid before the first run count: they were saved that month, though they moved no money here.
    public func saved(in month: YearMonth) -> Cents {
        entries.filter { $0.kind == .transfer && $0.to?.isSavings == true
            && YearMonth($0.date, calendar: calendar) == month }
            .reduce(Cents.zero) { $0 + $1.amount }
    }

    /// The incomes on the month's line: those that arrived into Main on their day, and in this month
    /// those still expected, on the day the line expects them.
    public func linePaydays(_ month: YearMonth, today: Date) -> [LinePayday] {
        let arrived = entries.filter { $0.kind == .income && $0.movesMoney && $0.to == .main && YearMonth($0.date, calendar: calendar) == month }
            .map { LinePayday(day: calendar.component(.day, from: $0.date), amount: $0.amount, projected: false) }
        guard month == YearMonth(today, calendar: calendar) else { return arrived }
        return arrived + incomes(in: month).filter { !isDone($0.id, in: month) }
            .map { LinePayday(day: expectedDay(of: $0, in: month, today: today), amount: $0.amount, projected: true) }
    }
}

/// "1st", "2nd", "19th": a day of the month as it is said.
public func ordinal(_ day: Int) -> String {
    let suffix = switch (day % 10, day % 100) {
    case (_, 11...13): "th"
    case (1, _): "st"
    case (2, _): "nd"
    case (3, _): "rd"
    default: "th"
    }
    return "\(day)\(suffix)"
}
