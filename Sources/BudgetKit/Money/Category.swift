import Foundation

/// What a spend was for, and the pot a spend in it comes out of (unless it went on the card).
/// The five Tally starts with keep the keys they always had, so entries saved before still point at them;
/// one added later has a fresh UUID for a key. Retired ones are no longer offered, but their spends keep them.
public struct Category: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var pot: Pot
    public var retired: Bool

    public init(id: String = UUID().uuidString, name: String, pot: Pot = .main, retired: Bool = false) {
        self.id = id
        self.name = name
        self.pot = pot
        self.retired = retired
    }

    /// Where a spend in it comes out of: the card when it went on the credit card, else its own pot.
    public func pot(paidWith method: PaymentMethod) -> Pot { method == .card ? .card : pot }

    public static let food = Category(id: "food", name: "Food")
    public static let goingOut = Category(id: "goingOut", name: "Going out")
    public static let clothes = Category(id: "clothes", name: "Clothes", pot: .clothes)
    public static let fragrance = Category(id: "fragrance", name: "Fragrance", pot: .clothes)
    public static let other = Category(id: "other", name: "Other")

    /// The categories every Tally starts with, in this order.
    public static let starters = [food, goingOut, clothes, fragrance, other]

    /// The pots a category can come out of: the card is chosen per spend, not per category.
    public static let pots: [Pot] = [.main, .clothes, .emergency]
}
