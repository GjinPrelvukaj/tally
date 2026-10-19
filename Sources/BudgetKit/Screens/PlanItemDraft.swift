import Foundation

/// A plan item as edited: the amount stays text until it reads as money. `item` is nil until it can be saved.
struct PlanItemDraft {
    enum When: CaseIterable { case day, window, anyDay, withIncome }

    var id: UUID
    var name: String
    var amount: String
    /// Changing what it is picks the pots that usually go with it.
    var kind: PlanKind { didSet { if kind != oldValue { (from, to) = Self.pots(for: kind) } } }
    var from: Pot?
    var to: Pot?
    var when: When
    var day = 1
    var windowFrom = 1
    var windowTo = 28
    var income: UUID?
    var onlyIn: YearMonth?
    var paused: Bool

    init(_ item: PlanItem) {
        id = item.id
        name = item.name
        amount = item.amount.editable
        kind = item.kind
        from = item.from
        to = item.to
        onlyIn = item.onlyIn
        paused = item.paused
        switch item.schedule {
        case .day(let d): when = .day; day = d
        case .window(let a, let b): when = .window; windowFrom = a; windowTo = b
        case .anyDay: when = .anyDay
        case .withIncome(let id): when = .withIncome; income = id
        }
    }

    /// A new one: something paid, on any day.
    init() {
        self.init(PlanItem(name: "", amount: .zero, kind: .payment, from: .main, schedule: .anyDay))
        amount = ""
    }

    private static func pots(for kind: PlanKind) -> (from: Pot?, to: Pot?) {
        switch kind {
        case .income: (nil, .main)
        case .transfer: (.main, .emergency)
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
        return PlanItem(id: id, name: name, amount: cents, kind: kind, from: from, to: to, schedule: schedule,
                        onlyIn: onlyIn, paused: paused)
    }
}
