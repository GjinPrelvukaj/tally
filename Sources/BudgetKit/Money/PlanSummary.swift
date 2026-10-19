import Foundation

/// What the plan comes to in one month: what comes in, goes to savings, goes out and every day takes, and what that
/// leaves over (below 0 when the plan spends more than comes in).
public struct PlanSummary: Equatable, Sendable {
    public var comesIn: Cents
    public var toSavings: Cents
    public var goesOut: Cents
    public var everyDay: Cents
    public var left: Cents
}

extension Ledger {
    /// Only what is due that month: a yearly item in its month, nothing paused; every day as many times as the month has days.
    public func planSummary(for month: YearMonth) -> PlanSummary {
        let due = plan.filter { $0.applies(in: month) }
        func sum(_ group: PlanGroup) -> Cents { due.filter { $0.group == group }.reduce(.zero) { $0 + $1.amount } }
        let everyDay = Cents(sum(.everyDay).value * month.days(calendar: calendar))
        let comesIn = sum(.comesIn), toSavings = sum(.savings), goesOut = sum(.goesOut)
        return PlanSummary(comesIn: comesIn, toSavings: toSavings, goesOut: goesOut, everyDay: everyDay,
                           left: comesIn - toSavings - goesOut - everyDay)
    }
}
