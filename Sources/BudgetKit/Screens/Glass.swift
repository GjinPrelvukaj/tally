import AppKit
import SwiftUI

/// The window itself: black glass with continuous corners, a hairline round it, and colour only
/// as light from the bottom edge. `light` holds one set of colours per screen; `position` is
/// where the pager is (0 Today … 2 Month, fractions while swiping), so the light crossfades with the finger.
struct Glass: View {
    let light: [[Color]]
    let position: Double

    /// How far up from the bottom edge its light reaches (its 22 pt and its blur): content stays above it.
    static let lightRoom: CGFloat = 48

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        ZStack {
            shape.fill(.black)
            ForEach(light.indices, id: \.self) { i in
                EdgeLight(colors: light[i], strength: EdgeLight.panel)
                    .opacity(max(0, 1 - abs(position - Double(i))))
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .ignoresSafeArea()
    }
}

/// The window's sizes: it opens at `standard`, can be made larger, and never smaller than `minimum`
/// (the sidebar beside Today's ring and its list).
public enum WindowSize {
    public static let standard = CGSize(width: 940, height: 620)
    public static let minimum = CGSize(width: 880, height: 560)
}
