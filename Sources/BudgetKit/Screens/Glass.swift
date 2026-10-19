import AppKit
import SwiftUI

/// The window itself: black glass with continuous corners, a hairline round it, and colour only
/// as light from the bottom edge. `light` holds one set of colours per screen; `position` is
/// where the pager is (0 Today … 2 Month, fractions while swiping), so the light crossfades with the finger.
struct Glass: View {
    let light: [[Color]]
    let position: Double

    /// The window is 380 × 560 with its title bar hidden. The content sits under the title bar's
    /// height, so it is that much shorter; the glass behind it fills the whole window.
    static let contentSize = CGSize(width: 380, height: 560 - NSWindow.frameRect(forContentRect: .zero, styleMask: .titled).height)

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
