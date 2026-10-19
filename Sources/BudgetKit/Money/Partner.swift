import Foundation

/// How the partner was part of a spend.
public enum PartnerShare: String, Codable, CaseIterable, Sendable {
    /// Together, and it was all yours (a coffee you'd have had anyway).
    case with
    /// Half of it was theirs.
    case half
    /// All of it was theirs.
    case forThem

    /// Their part of a spend of `amount`. Half rounds down, so their part is never more than half.
    public func theirs(of amount: Cents) -> Cents {
        switch self {
        case .with: .zero
        case .half: amount.dividedFloor(by: 2)
        case .forThem: amount
        }
    }
}

extension Ledger {
    /// What `person` owes you now, from everything open with them (negative: what you owe them). Nil is the partner:
    /// their parts of spends marked to be paid back count too. Owed from before Tally counts though it moved no money.
    public func owes(_ person: String?) -> Cents {
        entries.filter { Self.same($0.person, person) }.reduce(.zero) { sum, entry in
            switch entry.kind {
            case .spend: sum + (entry.owed ?? .zero)
            case .lent, .paidBack: sum + entry.amount
            case .repayment, .borrowed: sum - entry.amount
            default: sum
            }
        }
    }

    /// What the partner owes now.
    public var partnerOwes: Cents { owes(nil) }

    /// Everyone money has been open with, the partner first (nil), then by name in the first spelling written.
    public var people: [String?] {
        var named: [String] = []
        var partner = false
        for entry in entries where entry.kind.isWithSomeone || entry.owed != nil {
            if let name = entry.person {
                if !named.contains(where: { Self.same($0, name) }) { named.append(name) }
            } else {
                partner = true
            }
        }
        return (partner ? [nil] : []) + named.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// One person whatever the case or spaces round the name; nil (the partner) only matches nil.
    static func same(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): a.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(b.trimmingCharacters(in: .whitespaces)) == .orderedSame
        default: false
        }
    }
}

extension EntryKind {
    /// Money open with a person: lent, borrowed, or paid back either way.
    public var isWithSomeone: Bool { [.lent, .borrowed, .repayment, .paidBack].contains(self) }
}
