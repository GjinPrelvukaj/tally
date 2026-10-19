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
    /// The widest a section's content gets: a list's name and amount stay close however wide the window.
    static let readable: CGFloat = 820

    /// The three widths a field or pop-up comes in, so none is a third of the one beside it.
    /// Every control in a form (a field, an amount with its "€", a pop-up): their right edges line up.
    static let field: CGFloat = 170
    /// An amount typed in a list's row: a payday's split, the first run, a row of Still to pay.
    static let rowAmount: CGFloat = 96
    /// The big amount at the top of a card, a panel or the first run.
    static let largeField: CGFloat = 160

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
    /// A section's content in the pane right of the sidebar: the same room round every one, no wider than
    /// `Kit.readable` and centred in a wide window, so rows never stretch apart. The pane itself already ends above
    /// the window's light, so no room is added at the bottom.
    func pane() -> some View {
        frame(maxWidth: Kit.readable, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
/// Two fingers to the right push it away, as it came in; it gives its width back as it goes, so the list
/// beside it widens with the fingers, not only once it has closed.
struct SidePanel<Content: View>: View {
    let close: () -> Void
    @ViewBuilder let content: Content
    @State private var pull: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static var width: CGFloat { 320 }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
            content
                .padding(.horizontal, Kit.Space.edge)
                .padding(.top, 36)
                .padding(.bottom, Kit.Space.edge)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: Self.width)
        .background(.white.opacity(0.025))
        // Laid out narrower as it is pushed, its content running off the window's edge.
        .frame(width: max(0, Self.width - pull), alignment: .leading)
        .clipped()
        .swipeToClose(.right, pull: $pull) { travel in
            if Modal<EmptyView>.closes(dragged: travel, predicted: travel) {
                close()
            } else {
                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { pull = 0 }
            }
        }
    }
}

/// A choice of a few, as one glass bar: each with its symbol and name, the chosen one lit, the light sliding to a
/// new choice (cross-fading under Reduce Motion). Each keeps its whole name and the room left is shared; where even
/// that doesn't fit it drops the symbols, and where the names don't fit it shows the symbols alone.
struct GlassSegments<Value: Hashable>: View {
    @Binding var selection: Value
    /// Each choice: its value, its name and its SF Symbol.
    let choices: [(Value, String, String)]
    @Namespace private var lit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Look { case both, names, symbols }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(.both)
            bar(.names)
            bar(.symbols)
        }
    }

    private func bar(_ look: Look) -> some View {
        HStack(spacing: 2) {
            ForEach(choices, id: \.0) { value, title, symbol in
                let chosen = value == selection
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { selection = value }
                } label: {
                    Group {
                        switch look {
                        case .both: Label(title, systemImage: symbol)
                        case .names: Text(title)
                        case .symbols: Image(systemName: symbol)
                        }
                    }
                    .font(Kit.body)
                    .lineLimit(1)
                    // Never shortened: the bar picks a smaller look instead.
                    .fixedSize()
                    // Room at the ends, so a choice never touches the light round it.
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: Kit.control)
                    .opacity(chosen ? 1 : 0.6)
                    .background {
                        if chosen {
                            Capsule().fill(.white.opacity(0.14))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                                .matchedGeometryEffect(id: "lit", in: lit)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(title)
                .accessibilityLabel(title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.white.opacity(0.05), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
    }
}
