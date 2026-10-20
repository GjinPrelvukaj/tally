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
    /// The savings pots of the person's own, retired ones too, in their order.
    public var savings: [SavingsPot]
    /// What a pot is saving up to.
    public var goals: [Pot: Cents]

    public init(start: [Pot: Cents], startMonth: YearMonth, plan: [PlanItem], entries: [Entry], calendar: Calendar,
                categories: [Category] = Category.starters, savings: [SavingsPot] = SavingsPot.original, goals: [Pot: Cents] = [:]) {
        self.start = start
        self.startMonth = startMonth
        self.plan = plan
        self.entries = entries
        self.calendar = calendar
        self.categories = categories
        self.savings = savings
        self.goals = goals
    }

    /// The pots shown and offered: Main, each savings pot not retired, the card.
    public var pots: [Pot] { [.main] + savings.filter { !$0.retired }.map(\.id) + [.card] }

    /// Where a spend in a category can come out of: Main or a savings pot (the card is chosen per spend).
    public var spendingPots: [Pot] { pots.filter { $0 != .card } }

    /// "four pots": how many are shown, in words up to ten.
    public var potCount: String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        let n = pots.count
        return "\(n < words.count ? words[n] : String(n)) pot\(n == 1 ? "" : "s")"
    }

    /// A savings pot can be retired when nothing is left in it and nothing in the plan moves money into or out of it,
    /// so no money is ever hidden and nothing planned points at a pot no longer shown.
    public func canRetire(_ pot: Pot) -> Bool {
        pot.isSavings && balance(pot) == .zero && !plan.contains { $0.from == pot || $0.to == pot }
    }

    /// A savings pot's own name; Main's, the card's, or a pot no longer known by its id.
    public func name(_ pot: Pot) -> String {
        savings.first { $0.id == pot }?.name ?? pot.title
    }

    /// Its colour, of the app's few (`SavingsPot.colours`).
    public func colour(_ pot: Pot) -> Int {
        pot == .main ? SavingsPot.mainColour : pot == .card ? SavingsPot.cardColour : savings.first { $0.id == pot }?.colour ?? SavingsPot.colours[0]
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
        ([.main, .card] + savings.map(\.id)).reduce(.zero) { $0 + balance($1) }
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

    /// A balance set by hand stays as it was set. When `old` is deleted (`new` nil) or changed to `new` (another amount,
    /// pot or time), each balance set after it, in each pot it touches, takes up whatever no longer adds up before it, so
    /// every set balance still holds. Returns those adjustments as they must now be; a set balance itself changes nothing.
    public func setBalancesHeld(changing old: Entry, to new: Entry?) -> [Entry] {
        guard old.kind != .adjustment else { return [] }
        let pots = Set([old.from, old.to, new?.from, new?.to].compactMap { $0 })
        return pots.sorted { $0.rawValue < $1.rawValue }.flatMap { pot in
            // What changed before each set balance, less what an earlier one in the pot already took up.
            var taken = Cents.zero
            return entries.filter { $0.kind == .adjustment && $0.to == pot }.sorted { $0.date < $1.date }.compactMap { set -> Entry? in
                let before = (old.date < set.date ? effect(of: old, on: pot) : .zero)
                    - (new.map { $0.date < set.date ? effect(of: $0, on: pot) : .zero } ?? .zero)
                let needed = before - taken
                guard needed != .zero else { return nil }
                taken = taken + needed
                var set = set
                set.amount = set.amount + needed
                return set
            }
        }
    }

    /// What an entry did to a pot's balance.
    private func effect(of entry: Entry, on pot: Pot) -> Cents {
        guard entry.movesMoney else { return .zero }
        return (entry.to == pot ? entry.amount : .zero) - (entry.from == pot ? entry.amount : .zero)
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
