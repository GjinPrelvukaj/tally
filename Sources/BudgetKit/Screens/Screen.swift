import SwiftUI

/// The three screens, left to right, one swipe or arrow key apart.
public enum Screen: Int, CaseIterable, Sendable {
    case today, pots, month

    /// From `--screen today|pots|month`; anything else is nil.
    public init?(named name: String) {
        guard let screen = Screen.allCases.first(where: { "\($0)" == name }) else { return nil }
        self = screen
    }

    /// The arrows stop at the ends rather than wrapping round.
    var next: Screen { Screen(rawValue: rawValue + 1) ?? self }
    var previous: Screen { Screen(rawValue: rawValue - 1) ?? self }

    var title: String {
        switch self {
        case .today: "Today"
        case .pots: "Pots"
        case .month: "Month"
        }
    }

    /// Its colour, as light along the window's bottom edge (the mockups' colours).
    var light: [Color] {
        switch self {
        case .today: [.arrived, .ahead]
        case .pots: Pot.allCases.map(\.light)
        case .month: [.hex(0xA78BFA), .hex(0xA78BFA), .ahead]
        }
    }
}

extension Pot {
    /// Each pot's own colour: its light on Pots, its tube.
    var light: Color {
        switch self {
        case .main: .hex(0x60A5FA)
        case .clothes: .hex(0xF472B6)
        case .emergency: .arrived
        case .card: .hex(0xFBBF24)
        }
    }
}

extension Color {
    /// Green: money that has come, a payday added, the days gone. Also the emergency fund's colour.
    static let arrived = Color.hex(0x34D399)
    /// Cyan: what is still ahead.
    static let ahead = Color.hex(0x22D3EE)

    static func hex(_ rgb: UInt32) -> Color {
        Color(red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}
