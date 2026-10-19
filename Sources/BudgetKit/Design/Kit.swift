import SwiftUI

/// The few sizes, buttons and switches every screen and sheet uses, so they all read as one app.
/// Change a look here, never inline in a screen.
enum Kit {
    /// Words in rows and sheets.
    static let body = Font.system(size: 13)
    /// The quiet line under a figure or a row.
    static let quiet = Font.system(size: 11.5)
    /// A question or a sheet's title.
    static let title = Font.system(size: 20, weight: .semibold)
    /// The amount being typed at the top of a sheet.
    static let amount = Font.system(size: 20, weight: .semibold)
    /// Every button and chip is this tall, so a row of them lines up.
    static let control: CGFloat = 28

    /// The only gaps used inside a sheet or screen, smallest to largest.
    enum Space {
        /// A label and what it labels.
        static let label: CGFloat = 6
        /// Rows or chips next to each other.
        static let item: CGFloat = 8
        /// One part of a sheet and the next.
        static let group: CGFloat = 16
        /// Round a sheet's edge, and above its buttons.
        static let edge: CGFloat = 20
    }
}

extension View {
    /// The small capital label over a screen or a sheet ("YOU CAN SPEND", "THE PLAN").
    func eyebrow() -> some View {
        font(Living.caption).tracking(0.8).textCase(.uppercase).opacity(0.45)
    }

    /// The label over a group inside a list ("Still to pay", "Comes in").
    func groupLabel() -> some View {
        font(Living.caption).opacity(0.45)
    }
}

/// The three buttons: the one action that records (green), a second choice (grey glass), and leaving (plain words).
enum KitButton {
    case primary, secondary, quiet
}

struct KitButtonStyle: ButtonStyle {
    var kind: KitButton
    /// A primary button may take a pot's own colour (Set Balance).
    var tint: Color = .arrived
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(kind == .primary ? .system(size: 13, weight: .medium) : Kit.body)
            .lineLimit(1)
        Group {
            switch kind {
            case .primary: label.modifier(Capsuled(fill: tint.opacity(0.32), padding: 16))
            case .secondary: label.modifier(Capsuled(fill: .white.opacity(0.1), padding: 14))
            case .quiet: label.opacity(0.55).frame(height: Kit.control).contentShape(Rectangle()).hoverLift()
            }
        }
        .opacity(configuration.isPressed ? 0.7 : enabled ? 1 : 0.4)
    }
}

/// A capsule button's body: one height everywhere, a faint hairline so it reads as glass.
private struct Capsuled: ViewModifier {
    var fill: Color
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, padding)
            .frame(height: Kit.control)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .contentShape(Capsule())
            .hoverLift()
    }
}

extension ButtonStyle where Self == KitButtonStyle {
    static var primary: KitButtonStyle { KitButtonStyle(kind: .primary) }
    static func primary(_ tint: Color) -> KitButtonStyle { KitButtonStyle(kind: .primary, tint: tint) }
    static var secondary: KitButtonStyle { KitButtonStyle(kind: .secondary) }
    static var quiet: KitButtonStyle { KitButtonStyle(kind: .quiet) }
}

/// A choice among a few (a category): light, with the chosen one brighter and outlined.
struct ChipStyle: ButtonStyle {
    var chosen = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .opacity(chosen ? 1 : 0.75)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(.white.opacity(chosen ? 0.14 : 0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(chosen ? 0.22 : 0.07), lineWidth: 1))
            .contentShape(Capsule())
            .hoverLift()
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == ChipStyle {
    static func chip(chosen: Bool = false) -> ChipStyle { ChipStyle(chosen: chosen) }
}

/// An on/off in the app's own glass: a small capsule whose knob slides and whose track lights green.
struct GlassSwitchStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                configuration.label.font(Kit.body)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? Color.arrived.opacity(0.55) : .white.opacity(0.12))
                    Circle().fill(.white).padding(2)
                }
                .frame(width: 30, height: 18)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change, value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

extension ToggleStyle where Self == GlassSwitchStyle {
    static var glass: GlassSwitchStyle { GlassSwitchStyle() }
}

extension View {
    /// A section's content in the pane right of the sidebar: the same room round every one.
    func pane() -> some View {
        padding(.horizontal, 40)
            .padding(.top, 36)
            .padding(.bottom, Kit.Space.edge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A list's rows on one quiet rounded panel (the plan's groups, the month's entries).
    func rowPanel() -> some View {
        background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
    }
}

/// A section in the sidebar: its symbol and name, a count on the right, the chosen one on a soft highlight.
struct SidebarItemStyle: ButtonStyle {
    var chosen: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Kit.body)
            .opacity(chosen ? 0.95 : 0.65)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(chosen ? 0.1 : configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == SidebarItemStyle {
    static func sidebarItem(chosen: Bool) -> SidebarItemStyle { SidebarItemStyle(chosen: chosen) }
}

/// The editor beside a list, on the pane's right: a hairline before it and a faint glass behind.
struct SidePanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
            content
                .padding(.horizontal, Kit.Space.edge)
                .padding(.top, 36)
                .padding(.bottom, Kit.Space.edge)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 320)
        .background(.white.opacity(0.025))
    }
}
