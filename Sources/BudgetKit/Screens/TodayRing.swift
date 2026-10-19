import SwiftUI

/// The month as a ring of dots, one a day clockwise from the top: the days gone lit, paydays larger, today the brightest.
/// Its own view rather than `DotRing`: that one counts time down in one colour, the month needs four kinds of day.
struct TodayRing: View {
    let days: Int
    /// Today's day of the month.
    let today: Int
    let paydays: Set<Int>

    var body: some View {
        GeometryReader { geo in
            // 5 pt on the smallest ring (240), growing with it.
            let dot = min(geo.size.width, geo.size.height) / 48
            let r = min(geo.size.width, geo.size.height) / 2 - dot
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ForEach(1...max(1, days), id: \.self) { day in
                let a = Double(day - 1) / Double(max(1, days)) * 2 * .pi - .pi / 2
                let look = look(day, dot: dot)
                Circle()
                    .fill(look.color)
                    .frame(width: look.size, height: look.size)
                    .shadow(color: look.glow, radius: 2.5)
                    .position(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
        }
        // Drawn once into one image per change, as DotRing is.
        .drawingGroup()
        .accessibilityHidden(true)
    }

    /// Paydays take Today's two edge colours: green once they've come, cyan while still ahead.
    private func look(_ day: Int, dot: CGFloat) -> (color: Color, size: CGFloat, glow: Color) {
        if day == today { return (.white, dot * 1.9, .white.opacity(0.7)) }
        if paydays.contains(day) {
            let tint: Color = day < today ? .arrived : .ahead
            return (tint, dot * 1.4, tint.opacity(0.65))
        }
        return (.white.opacity(day < today ? 0.7 : 0.1), dot, .clear)
    }
}
