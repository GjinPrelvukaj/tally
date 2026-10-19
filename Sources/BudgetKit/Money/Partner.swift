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
    /// What the partner owes now: their parts marked to be paid back, less what they paid back.
    public var partnerOwes: Cents {
        entries.reduce(.zero) { sum, entry in
            switch entry.kind {
            case .repayment: sum - entry.amount
            case .spend: sum + (entry.owed ?? .zero)
            default: sum
            }
        }
    }
}
