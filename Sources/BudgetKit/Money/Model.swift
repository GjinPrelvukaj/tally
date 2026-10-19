import Foundation

/// A place the money sits. Only Main is spent from day to day.
public enum Pot: String, Codable, CaseIterable, Sendable {
    case main, clothes, emergency, card

    public var title: String {
        switch self {
        case .main: "Main"
        case .clothes: "Clothes"
        case .emergency: "Emergency fund"
        case .card: "Credit card"
        }
    }
}

extension Pot {
    /// What a field shows for a stored balance: the card is asked as what is owed, though it is kept as a debt.
    public func figure(for balance: Cents) -> Cents { self == .card ? .zero - balance : balance }

    /// What is stored for a figure typed in (the same turn, backwards).
    public func balance(fromFigure figure: Cents) -> Cents { self == .card ? .zero - figure : figure }
}

/// When in the month a plan item is due.
public enum Schedule: Codable, Hashable, Sendable {
    case day(Int)
    case window(from: Int, to: Int)
    case anyDay
    case withIncome(UUID)
}

public enum PlanKind: String, Codable, Sendable {
    case income, transfer, payment, daily

    /// What an entry for this item is called. Daily life is only an amount held back, so it has none.
    public var entryKind: EntryKind? {
        switch self {
        case .income: .income
        case .transfer: .transfer
        case .payment: .payment
        case .daily: nil
        }
    }
}

/// One line of the monthly plan. `onlyIn` makes it a one-off for that month.
public struct PlanItem: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var amount: Cents
    public var kind: PlanKind
    public var from: Pot?
    public var to: Pot?
    public var schedule: Schedule
    public var onlyIn: YearMonth?
    public var paused: Bool

    public init(id: UUID = UUID(), name: String, amount: Cents, kind: PlanKind, from: Pot? = nil, to: Pot? = nil,
                schedule: Schedule, onlyIn: YearMonth? = nil, paused: Bool = false) {
        self.id = id
        self.name = name
        self.amount = amount
        self.kind = kind
        self.from = from
        self.to = to
        self.schedule = schedule
        self.onlyIn = onlyIn
        self.paused = paused
    }

    public func applies(in month: YearMonth) -> Bool {
        !paused && (onlyIn == nil || onlyIn == month)
    }
}

/// How a spend was paid. The credit card adds to what it owes; the bank card and cash come out of the category's pot
/// (cash is money taken out of it before), the spend remembering it was cash.
public enum PaymentMethod: String, Codable, CaseIterable, Sendable { case bank, card, cash }

/// `repayment`: the partner paid back what they owed, into `to`.
public enum EntryKind: String, Codable, Sendable { case income, transfer, payment, spend, adjustment, dismissed, repayment }

/// Something that happened. `movesMoney` is false for "paid before you started" and for `dismissed`.
/// An adjustment has `from == nil`, `to == pot` and a signed amount.
/// A spend names its category by key (`Category.id`), so renaming a category never rewrites history; it may say
/// how the partner was part of it, and what of it they owe back.
public struct Entry: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var amount: Cents
    public var kind: EntryKind
    public var from: Pot?
    public var to: Pot?
    public var category: String?
    public var note: String?
    public var planItem: UUID?
    public var forMonth: YearMonth?
    public var movesMoney: Bool
    public var partner: PartnerShare?
    /// What of it the partner will pay back; nil when nothing.
    public var owed: Cents?
    /// How a spend was paid; nil on one saved before this was kept (its pot says card or not).
    public var method: PaymentMethod?

    public init(id: UUID = UUID(), date: Date, amount: Cents, kind: EntryKind, from: Pot? = nil, to: Pot? = nil,
                category: String? = nil, note: String? = nil, planItem: UUID? = nil, forMonth: YearMonth? = nil,
                movesMoney: Bool = true, partner: PartnerShare? = nil, owed: Cents? = nil, method: PaymentMethod? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.kind = kind
        self.from = from
        self.to = to
        self.category = category
        self.note = note
        self.planItem = planItem
        self.forMonth = forMonth
        self.movesMoney = movesMoney
        self.partner = partner
        self.owed = owed
        self.method = method
    }
}
