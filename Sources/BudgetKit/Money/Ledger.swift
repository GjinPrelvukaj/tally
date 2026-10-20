import Foundation

/// Everything that is known: where each pot started, the plan, and what really happened.
/// A snapshot of plain values, so all the money logic can be tested without a database.
public struct Ledger: Sendable {
    public var start: [Pot: Cents]
    public var startMonth: YearMonth
    public var plan: [PlanItem]
    public var entries: [Entry]
    public var calendar: Calendar
    /// Every category, retired ones too, in the order they are offered.
    public var categories: [Category]

    public init(start: [Pot: Cents], startMonth: YearMonth, plan: [PlanItem], entries: [Entry], calendar: Calendar,
                categories: [Category] = Category.starters) {
        self.start = start
        self.startMonth = startMonth
        self.plan = plan
        self.entries = entries
        self.calendar = calendar
        self.categories = categories
    }

    /// The category a spend names. One whose key is no longer known still has a name: "Other".
    public func category(_ id: String?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id } ?? Category(id: id, name: Category.other.name)
    }

    /// Starting balance, plus what came in, minus what went out. Only entries that moved money count,
    /// and only what was written down: changing the plan later never changes a balance.
    public func balance(_ pot: Pot) -> Cents {
        balance(pot, counting: entries)
    }

    /// Everything in the pots, with the card's debt taken off.
    public var total: Cents {
        Pot.allCases.reduce(.zero) { $0 + balance($1) }
    }

    /// The category of the newest spend (by when it happened): where Quick log starts. Kept in the data, so it is the same
    /// after Tally is reopened, and Undo takes it back with the spend.
    public var lastSpendCategory: String? {
        entries.filter { $0.kind == .spend }.max { $0.date < $1.date }?.category
    }

    /// What moved money in the month, and what was owed with someone from before, newest first: the list to look
    /// through, edit or delete.
    public func entries(in month: YearMonth) -> [Entry] {
        entries.filter { ($0.movesMoney || $0.kind.isWithSomeone) && YearMonth($0.date, calendar: calendar) == month }
            .sorted { $0.date > $1.date }
    }

    /// The balance as it stood when the given day ended.
    public func balance(_ pot: Pot, endOf day: Date) -> Cents {
        let nextMorning = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))!
        return balance(pot, counting: entries.filter { $0.date < nextMorning })
    }

    private func balance(_ pot: Pot, counting entries: [Entry]) -> Cents {
        entries.filter(\.movesMoney).reduce(start[pot] ?? .zero) { sum, entry in
            var sum = sum
            if entry.to == pot { sum = sum + entry.amount }
            if entry.from == pot { sum = sum - entry.amount }
            return sum
        }
    }
}
