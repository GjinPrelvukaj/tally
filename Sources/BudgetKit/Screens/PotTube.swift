import SwiftUI

/// One pot as a glass tube of light: the fill rises from the bottom in the pot's colour, its surface a lit line
/// that glows as a `GlowMeter` does. A new level travels there on the meter's spring (the pour); under Reduce
/// Motion the old level fades into the new one without travelling.
struct PotTube: View {
    /// How full, 0 to 1.
    let level: Double
    /// Where the goal sits, 0 to 1, when the pot has one.
    let goal: Double?
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        GeometryReader { geo in
            // A full tube stops a little short of the top, so the goal line at the top still reads.
            let room = max(0, geo.size.height - 8)
            ZStack(alignment: .bottom) {
                shape.fill(.white.opacity(0.06))
                // A little money still shows as a sliver of light.
                light.frame(height: level > 0 ? max(6, room * level) : 0)
                    // Under Reduce Motion a new level is a new view, so it cross-fades instead of travelling.
                    .id(reduceMotion ? level : -1)
                    // Its glow reaches past an empty frame, so an empty tube hides it.
                    .opacity(level > 0 ? 1 : 0)
                    .transition(.opacity)
                if let goal {
                    Rectangle().fill(.white.opacity(0.5))
                        .frame(height: 1)
                        .padding(.horizontal, 6)
                        .offset(y: -room * min(1, goal))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : Motion.fill, value: level)
        .accessibilityHidden(true)
    }

    private var light: some View {
        VStack(spacing: 0) {
            Capsule().fill(tint)
                .frame(height: 2)
                .shadow(color: tint.opacity(0.8), radius: 5)
            LinearGradient(colors: [tint.opacity(0.38), tint.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        }
    }
}
