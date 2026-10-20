import Foundation

/// A plan item as edited: the amount stays text until it reads as money. `item` is nil until it can be saved.
struct PlanItemDraft {
    enum When: CaseIterable { case day, window, anyDay, withIncome }
    /// How often: every month, every few months or every year from `repeatMonth`, or once in it.
    enum Repeats: Hashable { case everyMonth, every(Int), once }

    var id: UUID
    var name: String
    var amount: String
    /// Changing what it is picks the pots that usually go with it.
    var kind: PlanKind { didSet { if kind != oldValue { (from, to) = pots(for: kind) } } }
    /// Where a transfer goes unless chosen: the first savings pot (set as the editor opens), else paying off the card.
    var savingsPot: Pot = .card
    var from: Pot?
    var to: Pot?
    var when: When
    var day = 1
    var windowFrom = 1
    var windowTo = 28
    var income: UUID?
    var repeats: Repeats
    /// The month it starts in (every few months, every year) or happens in (once).
    var repeatMonth: YearMonth
    /// When it repeats every month: the month it began (nil: always), kept as it was.
    var startsIn: YearMonth?
    var paused: Bool

    init(_ item: PlanItem) {
        id = item.id
        name = item.name
        amount = item.amount.editable
        kind = item.kind
        from = item.from
        to = item.to
        paused = item.paused
        startsIn = item.startsIn
        repeats = item.onlyIn != nil ? .once : item.repeatEvery > 1 ? .every(item.repeatEvery) : .everyMonth
        repeatMonth = item.onlyIn ?? item.startsIn ?? YearMonth(.now, calendar: .current)
        switch item.schedule {
        case .day(let d): when = .day; day = d
        case .window(let a, let b): when = .window; windowFrom = a; windowTo = b
        case .anyDay: when = .anyDay
        case .withIncome(let id): when = .withIncome; income = id
        }
    }

    /// A new one: something paid, on any day, every month from `month` (so it is never owed for months before it).
    init(startingIn month: YearMonth) {
        self.init(PlanItem(name: "", amount: .zero, kind: .payment, from: .main, schedule: .anyDay, startsIn: month))
        amount = ""
        repeatMonth = month
    }

    private func pots(for kind: PlanKind) -> (from: Pot?, to: Pot?) {
        switch kind {
        case .income: (nil, .main)
        case .transfer: (.main, savingsPot)
        case .payment, .daily: (.main, nil)
        }
    }

    var schedule: Schedule? {
        if kind == .daily { return .anyDay }
        switch when {
        case .day: return .day(day)
        case .window: return windowFrom <= windowTo ? .window(from: windowFrom, to: windowTo) : nil
        case .anyDay: return .anyDay
        case .withIncome: return income.map(Schedule.withIncome)
        }
    }

    var amountCents: Cents? { Cents.parse(amount) }

    var item: PlanItem? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let cents = amountCents, let schedule, from != to || kind == .income else { return nil }
        return switch repeats {
        case .everyMonth: PlanItem(id: id, name: name, amount: cents, kind: kind, from: from, to: to, schedule: schedule,
                                   paused: paused, startsIn: startsIn)
        case .every(let months): PlanItem(id: id, name: name, amount: cents, kind: kind, from: from, to: to, schedule: schedule,
                                          paused: paused, repeatEvery: months, startsIn: repeatMonth)
        case .once: PlanItem(id: id, name: name, amount: cents, kind: kind, from: from, to: to, schedule: schedule,
                             onlyIn: repeatMonth, paused: paused)
        }
    }
}
