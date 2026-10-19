import Foundation

/// The four headings the plan is listed under.
public enum PlanGroup: CaseIterable, Sendable {
    case comesIn, savings, goesOut, everyDay

    public var title: String {
        switch self {
        case .comesIn: "Comes in"
        case .savings: "Goes to savings"
        case .goesOut: "Goes out"
        case .everyDay: "Every day"
        }
    }
}

extension PlanItem {
    /// Paying off the card is money going out, not saving.
    public var group: PlanGroup {
        switch kind {
        case .income: .comesIn
        case .daily: .everyDay
        case .payment: .goesOut
        case .transfer: to == .card ? .goesOut : .savings
        }
    }
}
