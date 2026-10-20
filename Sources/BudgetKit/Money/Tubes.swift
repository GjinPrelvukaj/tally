import Foundation

/// The sums behind the tubes on Pots; the drawing is in `PotTube`.
public enum Tubes {
    /// What a tube holds: the balance, or for the card what is owed.
    public static func held(_ balance: Cents, in pot: Pot) -> Cents {
        pot.figure(for: balance)
    }

    /// One scale for all four, so a taller tube really holds more: the largest goal or held amount.
    public static func scale(balances: [Pot: Cents], goals: [Pot: Cents]) -> Cents {
        let amounts = balances.map { Self.held($0.value, in: $0.key) }
        return (amounts + goals.values).max() ?? .zero
    }

    /// The amount over the shared scale, 0 to 1; empty for nothing or a debt.
    public static func level(_ amount: Cents, of scale: Cents) -> Double {
        guard scale > .zero, amount > .zero else { return 0 }
        return min(1, Double(amount.value) / Double(scale.value))
    }
}
