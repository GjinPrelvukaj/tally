import Foundation

/// An amount of money in whole cents. Never a Double, so sums are always exact.
public struct Cents: Hashable, Comparable, Sendable, Codable, AdditiveArithmetic {
    public var value: Int

    public init(_ value: Int) { self.value = value }

    public static func euros(_ e: Int) -> Cents { Cents(e * 100) }

    public static let zero = Cents(0)
    public static func + (a: Cents, b: Cents) -> Cents { Cents(a.value + b.value) }
    public static func - (a: Cents, b: Cents) -> Cents { Cents(a.value - b.value) }
    public static func < (a: Cents, b: Cents) -> Bool { a.value < b.value }

    /// `2 450,17 €`: built by hand so it never follows the system locale.
    public var formatted: String {
        let cents = String(value.magnitude % 100)
        let sign = value < 0 ? "\u{2212}" : ""
        return sign + wholeEuros + "," + (cents.count == 1 ? "0" : "") + cents + "\u{00A0}€"
    }

    /// `2 400`: the euros alone, without sign or cents, as an income is named ("the 2 400").
    /// "250 €" for a round amount, "63,40 €" otherwise: quieter in a list of plans.
    public var short: String {
        value % 100 == 0 ? "\(value < 0 ? "\u{2212}" : "")\(wholeEuros)\u{00A0}€" : formatted
    }

    public var wholeEuros: String {
        var grouped = ""
        for (i, digit) in String(value.magnitude / 100).reversed().enumerated() {
            if i > 0 && i % 3 == 0 { grouped.append("\u{00A0}") }
            grouped.append(digit)
        }
        return String(grouped.reversed())
    }

    /// `2 450,17`: the amount without the euro sign, as a field starts from, so a small change is a small edit.
    public var editable: String {
        formatted.replacingOccurrences(of: "\u{00A0}€", with: "")
    }

    /// What a person types: `12,5`, `12.50`, `2 400`. Nil for anything else, so a typo is never saved as 0. Twelve digits at most, so the sum can't overflow.
    public static func parse(_ text: String) -> Cents? {
        let compact = text.filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".")
        let parts = compact.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = parts.first, !whole.isEmpty, whole.count <= 12, whole.allSatisfy(\.isASCIIDigit) else { return nil }
        var decimals = parts.count == 2 ? String(parts[1]) : ""
        guard decimals.count <= 2, decimals.allSatisfy(\.isASCIIDigit) else { return nil }
        if parts.count == 2 && decimals.isEmpty { return nil }
        decimals += String(repeating: "0", count: 2 - decimals.count)
        guard let euros = Int(whole), let cents = Int(decimals) else { return nil }
        return Cents(euros * 100 + cents)
    }

    /// What a payment, spend or income is typed as: money above 0, since a 0 would record nothing and still count as done.
    public static func parsePositive(_ text: String) -> Cents? {
        parse(text).flatMap { $0 > .zero ? $0 : nil }
    }

    /// Rounds towards the lower amount, so a daily allowance is never more than the money allows.
    public func dividedFloor(by days: Int) -> Cents {
        let quotient = value / days
        return Cents(value % days != 0 && value < 0 ? quotient - 1 : quotient)
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
