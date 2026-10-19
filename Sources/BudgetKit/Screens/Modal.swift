import SwiftUI

/// A card in the middle of the window, over the blurred rest of it (its host draws the blur and closes it on a
/// click outside). Pulled down with the mouse or two fingers, it follows and closes, or springs back.
struct Modal<Content: View>: View {
    var light: [Color]
    let close: () -> Void
    @ViewBuilder let content: Content
    /// How far it has been pulled down.
    @State private var pull: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pulled further than this, or flicked, it closes; otherwise it springs back.
    static func closes(dragged: CGFloat, predicted: CGFloat) -> Bool { dragged > 90 || predicted > 220 }

    var body: some View {
        content
            .padding(Kit.Space.edge)
            .frame(maxWidth: .infinity)
            .sheetCard(light: light)
            .offset(y: pull)
            // Scrolling on a Mac is wheel or trackpad, not a drag, so a drag anywhere on the card is free to pull it.
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { pull = max(0, $0.translation.height) }
                    .onEnded { value in settle(dragged: value.translation.height, predicted: value.predictedEndTranslation.height) }
            )
            // Two fingers down on the trackpad do the same as a drag.
            .swipeToClose(.down, pull: $pull) { settle(dragged: $0, predicted: $0) }
    }

    private func settle(dragged: CGFloat, predicted: CGFloat) {
        if Self.closes(dragged: dragged, predicted: predicted) {
            close()
        } else {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { pull = 0 }
        }
    }
}

extension View {
    /// This view as a card in the middle of the window, that `close` takes away.
    func modal(close: @escaping () -> Void,
               light: [Color] = [.arrived, Pot.main.light, .arrived]) -> some View {
        Modal(light: light, close: close) { self }
    }
}
