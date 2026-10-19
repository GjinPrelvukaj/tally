import SwiftUI

/// The sections in the sidebar, top to bottom: ⌘1 to ⌘6, and Settings ⌘, at the foot.
public enum Screen: Int, CaseIterable, Sendable {
    case today, pots, month, insights, entries, plan, settings

    /// From `--screen today|pots|month|insights|entries|plan|settings`; anything else is nil.
    public init?(named name: String) {
        guard let screen = Screen.allCases.first(where: { "\($0)" == name }) else { return nil }
        self = screen
    }

    /// ⌘1 for the first, and so on; Settings is ⌘, as on every Mac.
    var key: Character { self == .settings ? "," : Character(String(rawValue + 1)) }

    var title: String {
        switch self {
        case .today: "Today"
        case .pots: "Pots"
        case .month: "Month"
        case .insights: "Insights"
        case .entries: "Entries"
        case .plan: "Plan"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .pots: "cylinder.split.1x2"
        case .month: "chart.xyaxis.line"
        case .insights: "sparkles"
        case .entries: "list.bullet"
        case .plan: "calendar"
        case .settings: "gearshape"
        }
    }

    /// The colour at the left of its light, right under the sidebar's Log a Spend, which takes it.
    var tint: Color { light[0] }

    /// Its colour, as light along the window's bottom edge (the mockups' colours).
    var light: [Color] {
        switch self {
        case .today, .entries: [.arrived, .ahead]
        case .plan: [Pot.main.light, .arrived, Pot.main.light]
        case .insights: [.hex(0xFBBF24), .hex(0xA78BFA), .hex(0xFBBF24)]
        case .settings: [.hex(0x94A3B8), Pot.main.light, .hex(0x94A3B8)]
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
