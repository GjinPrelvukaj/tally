// Copied from Brimlight (Sources/NotchKit/Design/Living.swift) on 2026-10-19; changes marked "Budget:".
import SwiftUI

/// Notch's panel language, after Libraries.dev: each panel has one living thing made of
/// dots, light, liquid or a bot; colour arrives as light from the panel's edge; numbers
/// are quiet and given room; nothing moves unless something is happening.
enum Living {
    /// Room between a graphic and its words.
    static let gap: CGFloat = 10
    /// The quiet second line under a figure.
    static let caption = Font.system(size: 10.5, weight: .medium)
}

/// The four motions everything inside a panel uses, so each kind of change feels the same
/// everywhere: springs, as the shape is, never a fixed-time ease.
enum Motion {
    /// The pointer's touch: a hover lighting, lifting or showing a button.
    static let hover = Animation.spring(response: 0.22, dampingFraction: 0.78)
    /// Something that changed: a value, a row, a list, a switch, a light coming on.
    static let change = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// A meter's fill moving to a new reading: a touch slower, so it is seen to travel, never bouncing past.
    static let fill = Animation.spring(response: 0.6, dampingFraction: 0.92)
    /// Something arriving: a panel's content, a card, a preview.
    static let appear = Animation.spring(response: 0.4, dampingFraction: 0.86)
    /// Something leaving: gone quickly and without a bounce, so it never lingers in the way.
    static let leave = Animation.spring(response: 0.18, dampingFraction: 1)
}

/// Colour as light: soft lobes along the panel's bottom edge, in the voice glow's manner,
/// but still, so it costs nothing to keep on screen.
struct EdgeLight: View {
    /// Left to right; three to five reads best.
    let colors: [Color]
    /// Every panel's glow is this bright, so none reads louder than another; the Settings header
    /// and the welcome set their own.
    var strength: Double = EdgeLight.panel
    static let panel = 0.7

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            // One colour as three lobes of it: one wide lobe read brighter than a sky's three.
            let lobes = colors.count == 1 ? Array(repeating: colors[0], count: 3) : colors
            ZStack {
                ForEach(Array(lobes.enumerated()), id: \.offset) { i, color in
                    let x = w * (CGFloat(i) + 0.5) / CGFloat(lobes.count)
                    Ellipse()
                        .fill(RadialGradient(colors: [color.opacity(0.75 * strength), color.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: w / CGFloat(lobes.count)))
                        .frame(width: w / CGFloat(lobes.count) * 2, height: min(h, 76))
                        .position(x: x, y: h + 16)
                }
            }
            .blendMode(.plusLighter)
            .blur(radius: 12)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A slim meter that glows in its colour: the light way to say "this much of it".
struct GlowMeter: View {
    let fraction: Double
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let filled = geo.size.width * min(1, max(0, fraction))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule().fill(tint)
                    .frame(width: max(geo.size.height, filled))
                    .shadow(color: tint.opacity(0.8), radius: 5)
                    .opacity(fraction > 0.001 ? 1 : 0)
            }
            // A new reading travels there; still under Reduce Motion.
            .animation(reduceMotion ? nil : Motion.fill, value: fraction)
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// Where things fall on the calendar's day line: an hour back and seven ahead of now.
struct DayLine {
    static let before: TimeInterval = 3600
    static let after: TimeInterval = 7 * 3600
    let now: Date
    let width: CGFloat

    func x(_ date: Date) -> CGFloat {
        CGFloat((date.timeIntervalSince(now) + DayLine.before) / (DayLine.before + DayLine.after)) * width
    }

    /// Budget: what sits on the line, in place of Brimlight's calendar event.
    struct Event {
        var start: Date
        var end: Date
        var colorHex: String?
    }

    struct Stop: Equatable {
        var location: CGFloat
        var colorHex: String?
    }

    /// Where the liquid takes each event's colour, in order along the line (events can overlap).
    func stops(_ events: [DayLine.Event]) -> [Stop] {
        guard width > 0 else { return [] }
        return events.compactMap { e in span(e).map { (e, $0) } }
            .flatMap { e, s in [Stop(location: s.lowerBound / width, colorHex: e.colorHex), Stop(location: s.upperBound / width, colorHex: e.colorHex)] }
            .sorted { $0.location < $1.location }
    }

    /// The stretch of the line an event covers, at least a blob wide; nil when it is off the line.
    func span(_ event: Event) -> ClosedRange<CGFloat>? {
        let (a, b) = (max(0, x(event.start)), min(width, x(event.end)))
        guard b > 0, a < width, b >= a else { return nil }
        let grow = max(0, 8 - (b - a)) / 2
        return max(0, a - grow)...min(width, b + grow)
    }
}

/// The day as liquid: a thin line with the coming events as blobs in their colours and
/// now as a white droplet. Drawn through blur and threshold, so the droplet runs into an
/// event as it begins. Still: it is redrawn when the minute changes, not every frame.
struct LiquidDayLine: View {
    let events: [DayLine.Event]
    let now: Date
    let color: (String?) -> Color

    var body: some View {
        GeometryReader { geo in
            let line = DayLine(now: now, width: geo.size.width)
            let mid = geo.size.height / 2
            let spans = events.compactMap { e in line.span(e).map { (e, $0) } }
            // The colour the liquid takes at each point along it.
            let stops = line.stops(events).map { Gradient.Stop(color: color($0.colorHex), location: $0.location) }
            let nowX = line.x(now)
            ZStack {
                LinearGradient(stops: [.init(color: .white.opacity(0.35), location: 0)] + stops
                               + [.init(color: .white.opacity(0.35), location: 1)],
                               startPoint: .leading, endPoint: .trailing)
                    .mask {
                        Canvas { ctx, size in
                            ctx.addFilter(.alphaThreshold(min: 0.5))
                            ctx.addFilter(.blur(radius: 3))
                            ctx.drawLayer { layer in
                                layer.fill(Path(roundedRect: CGRect(x: 0, y: mid - 2, width: size.width, height: 4), cornerRadius: 2), with: .color(.white))
                                for (_, s) in spans {
                                    layer.fill(Path(roundedRect: CGRect(x: s.lowerBound, y: mid - 5, width: s.upperBound - s.lowerBound, height: 10),
                                                    cornerRadius: 5), with: .color(.white))
                                }
                                layer.fill(Path(ellipseIn: CGRect(x: nowX - 6, y: mid - 6, width: 12, height: 12)), with: .color(.white))
                            }
                        }
                    }
                // Now is white whatever it sits in.
                Circle().fill(.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.8), radius: 4)
                    .position(x: nowX, y: mid)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

/// Time as a ring of dots that go out one by one, clockwise from the top.
struct DotRing: View {
    /// 0 at the start, 1 when time is up.
    let progress: Double
    let tint: Color
    var count = 60
    var dot: CGFloat = 3.2
    /// Lit from the top clockwise (a dial), rather than lit up to the top (time running out).
    var fromStart = false

    static func lit(progress: Double, count: Int) -> Int {
        Int((Double(count) * (1 - min(1, max(0, progress)))).rounded(.up))
    }

    var body: some View {
        let lit = DotRing.lit(progress: progress, count: count)
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 - dot
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ForEach(0..<count, id: \.self) { i in
                // Dots go out from the top, clockwise, so the lit ones are the time left.
                let on = fromStart ? i < lit : i >= count - lit
                let edge = fromStart ? i == lit - 1 : i == count - lit
                let a = Double(i) / Double(count) * 2 * .pi - .pi / 2
                Circle()
                    .fill(on ? tint : .white.opacity(0.1))
                    .frame(width: edge ? dot * 1.6 : dot, height: edge ? dot * 1.6 : dot)
                    .shadow(color: on ? tint.opacity(0.6) : .clear, radius: 2)
                    .position(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
        }
        // Drawn once into one image per change: sixty glowing dots redrawn every frame of
        // a neighbour's animation cost a large share of a core.
        .drawingGroup()
        .accessibilityHidden(true)
    }
}

/// A button in a capsule, clickable all over it, not only on its words.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = .white.opacity(0.14)
    var text: Color = .white
    var height: CGFloat = 24
    var padding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.horizontal, padding)
            .frame(height: height)
            .background(fill, in: Capsule())
            .contentShape(Capsule())
            .pointerStyle(.link) // Budget: a normal window can show the hand itself
            .opacity(configuration.isPressed ? 0.7 : 1)
            .hoverLift()
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static func pill(fill: Color, text: Color = .white, height: CGFloat = 24, padding: CGFloat = 12) -> PillButtonStyle {
        PillButtonStyle(fill: fill, text: text, height: height, padding: padding)
    }
}

/// Lifts what it is on while the pointer rests there: brighter, slightly larger.
struct HoverLift: ViewModifier {
    /// Off for pictures: brightening washes artwork out grey.
    var brightens = true
    @State private var hovering = false
    @State private var width: CGFloat = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// About the same few points of growth for an icon and for a row as wide as the panel.
    static func scale(width: CGFloat) -> CGFloat { 1 + min(0.07, 3 / max(width, 1)) }

    func body(content: Content) -> some View {
        content
            .brightness(hovering && brightens ? 0.12 : 0)
            .scaleEffect(hovering && !reduceMotion ? HoverLift.scale(width: width) : 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onHover { hovering = $0 }
            .pointerStyle(.link) // Budget: a normal window can show the hand itself
            .animation(Motion.hover, value: hovering)
    }
}

extension View {
    /// The sign something can be clicked: it lifts under the pointer.
    func hoverLift(brightens: Bool = true) -> some View { modifier(HoverLift(brightens: brightens)) }
}

/// A time that rolls as it changes: each character on its own, and only the ones that change
/// move, the new one dropping in from above as the old slides out below. Cheap: one or two
/// small texts slide once a second, nothing is blurred.
struct RollingDigits: View {
    let text: String
    let font: Font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion // Budget: no rolling under Reduce Motion
    @Environment(\.redactionReasons) private var redaction // Budget: amounts can be hidden

    var body: some View {
        // Budget: hidden, one bar the same width whatever the amount, so not even its number of digits shows.
        if redaction.contains(.privacy) {
            Text("0 000,00 €").font(font).monospacedDigit().accessibilityLabel("Hidden")
        } else {
            digits
        }
    }

    private var digits: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, character in
                Text(String(character))
                    .font(font)
                    .monospacedDigit()
                    .id("\(i)-\(character)")
                    // Budget: under Reduce Motion a changed character only cross-fades.
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                                      removal: .move(edge: .bottom).combined(with: .opacity)))
            }
        }
        .clipped()
        .animation(Motion.change, value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
