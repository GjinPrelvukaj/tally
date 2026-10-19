import SwiftUI

/// Main across the month, the days laid out from the 1st to the last: solid and lit where it happened,
/// dashed where it is still the plan. Paydays are small labelled dots, today the brightest, the lowest point
/// ringed. Resting the pointer on it reads a day out. Drawn once per change; nothing moves on its own.
struct MonthLine: View {
    let line: [LinePoint]
    let days: Int
    /// Today's day, when this is today's month.
    let today: Int?
    let paydays: [LinePayday]
    @State private var hovered: Int?
    /// While amounts are hidden the line keeps its shape but says no amounts.
    @Environment(\.amountsHidden) private var hidden

    /// Month's light, left to right.
    private static let light = Gradient(colors: [.hex(0xA78BFA), .ahead])

    var body: some View {
        GeometryReader { geo in
            let frame = MonthLineFrame(line: line, days: days, size: geo.size)
            Canvas { ctx, size in draw(in: &ctx, frame) }
                .onContinuousHover { phase in
                    let day: Int? = switch phase {
                    case .active(let at): frame.nearestDay(to: at.x)
                    case .ended: nil
                    }
                    if day != hovered { hovered = day }
                }
        }
        .accessibilityHidden(true)
    }

    private func draw(in ctx: inout GraphicsContext, _ frame: MonthLineFrame) {
        // The month's days as faint dots along zero, so the whole month is there before the line begins.
        for day in 1...max(1, days) {
            ctx.fill(Path(ellipseIn: circle(CGPoint(x: frame.x(day), y: frame.y(.zero)), radius: 1)), with: .color(.white.opacity(0.16)))
        }
        guard let first = line.first else { return }
        let solid = line.filter { !$0.projected }
        let dashed = (solid.last.map { [$0] } ?? []) + line.filter(\.projected)
        let shading = GraphicsContext.Shading.linearGradient(Self.light, startPoint: CGPoint(x: frame.x(1), y: 0),
                                                             endPoint: CGPoint(x: frame.x(days), y: 0))
        let path = frame.path(solid)
        // A soft glow under the lit part, so it reads as light rather than ink.
        ctx.drawLayer { glow in
            glow.addFilter(.blur(radius: 5))
            glow.opacity = 0.55
            glow.stroke(path, with: shading, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(path, with: shading, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        if dashed.count > 1 {
            ctx.stroke(frame.path(dashed), with: .color(.white.opacity(0.28)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [3, 5]))
        }
        if solid.isEmpty { dot(&ctx, frame.point(first), radius: 2, color: .white.opacity(0.4)) }

        if let lowest = line.lowest, lowest.day != today {
            ctx.stroke(Path(ellipseIn: circle(frame.point(lowest), radius: 4.5)), with: .color(.white.opacity(0.55)), lineWidth: 1.2)
        }
        for payday in paydays {
            guard let point = line.first(where: { $0.day == payday.day }) else { continue }
            let at = frame.point(point)
            dot(&ctx, at, radius: 3.5, color: payday.projected ? .white.opacity(0.4) : .hex(0xA78BFA), glows: !payday.projected)
            if hovered == nil, !hidden { label(&ctx, payday.amount.wholeEuros, at: CGPoint(x: at.x, y: at.y - 8), anchor: .bottom, opacity: 0.45) }
        }
        if let today, let point = line.first(where: { $0.day == today }) {
            let at = frame.point(point)
            ctx.fill(Path(ellipseIn: circle(at, radius: 12)), with: .color(.white.opacity(0.12)))
            dot(&ctx, at, radius: 5, color: .white, glows: true)
            label(&ctx, "today", at: CGPoint(x: at.x, y: max(at.y, frame.y(.zero)) + 10), anchor: .top, opacity: 0.8)
        }
        if let hovered, let point = line.first(where: { $0.day == hovered }) {
            readOut(&ctx, point, frame)
        }
    }

    /// The hovered day: a hairline down to it, its point, and "20th · 466,60 €" over it.
    private func readOut(_ ctx: inout GraphicsContext, _ point: LinePoint, _ frame: MonthLineFrame) {
        let at = frame.point(point)
        ctx.stroke(Path { $0.move(to: CGPoint(x: at.x, y: 14)); $0.addLine(to: at) }, with: .color(.white.opacity(0.15)), lineWidth: 1)
        dot(&ctx, at, radius: 3, color: .white)
        let words = hidden ? ordinal(point.day) : "\(ordinal(point.day)) · \(point.balance.formatted)"
        let text = ctx.resolve(Text(words).font(Living.caption).monospacedDigit()
            .foregroundStyle(.white.opacity(0.85)))
        let half = text.measure(in: frame.size).width / 2
        ctx.draw(text, at: CGPoint(x: min(max(at.x, half), frame.size.width - half), y: 0), anchor: .top)
    }

    private func dot(_ ctx: inout GraphicsContext, _ at: CGPoint, radius: CGFloat, color: Color, glows: Bool = false) {
        var ctx = ctx
        if glows { ctx.addFilter(.shadow(color: color.opacity(0.7), radius: 2.5)) }
        ctx.fill(Path(ellipseIn: circle(at, radius: radius)), with: .color(color))
    }

    private func label(_ ctx: inout GraphicsContext, _ words: String, at: CGPoint, anchor: UnitPoint, opacity: Double) {
        ctx.draw(Text(words).font(.system(size: 10)).monospacedDigit().foregroundStyle(.white.opacity(opacity)), at: at, anchor: anchor)
    }

    private func circle(_ at: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2)
    }
}

/// Where a day and a balance sit: the month from the 1st to the last across, the line's own lowest to highest
/// down, zero included, with room above for the payday labels and below for "today".
struct MonthLineFrame {
    let days: Int
    let size: CGSize
    private let line: [LinePoint]
    private let low: Double, high: Double
    private let inset = (side: CGFloat(14), top: CGFloat(34), bottom: CGFloat(30))

    init(line: [LinePoint], days: Int, size: CGSize) {
        self.line = line
        self.days = days
        self.size = size
        // Zero is always in view, so the height of the line is how far it is from nothing.
        low = Double(min(0, line.map(\.balance.value).min() ?? 0))
        high = Double(max(0, line.map(\.balance.value).max() ?? 0))
    }

    func x(_ day: Int) -> CGFloat {
        inset.side + (size.width - 2 * inset.side) * CGFloat(day - 1) / CGFloat(max(1, days - 1))
    }

    func y(_ balance: Cents) -> CGFloat {
        // A flat line sits in the middle.
        let share = high > low ? (high - Double(balance.value)) / (high - low) : 0.5
        return inset.top + (size.height - inset.top - inset.bottom) * share
    }

    func point(_ point: LinePoint) -> CGPoint { CGPoint(x: x(point.day), y: y(point.balance)) }

    func path(_ points: [LinePoint]) -> Path {
        Path { path in
            for (i, p) in points.enumerated() {
                if i == 0 { path.move(to: point(p)) } else { path.addLine(to: point(p)) }
            }
        }
    }

    /// The line's day nearest the pointer. Days before it starts (before Tally was set up) read nothing: Main isn't
    /// known then, and the first day's balance is what was left at its end.
    func nearestDay(to pointerX: CGFloat) -> Int? {
        guard let first = line.first, pointerX >= x(first.day) - (x(2) - x(1)) / 2 else { return nil }
        return line.min { abs(x($0.day) - pointerX) < abs(x($1.day) - pointerX) }?.day
    }
}
