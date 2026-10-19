import Foundation

public enum Payday {
    /// What stays in Main once everything that goes out with the income is paid; below zero if it doesn't cover it.
    public static func leftInMain(income: Cents, split: [Cents]) -> Cents {
        split.reduce(income, -)
    }
}
