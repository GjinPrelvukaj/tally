import SwiftUI

/// A drawer: it rises from the window's bottom edge with a handle on top, and closes when dragged down
/// (or when the dimmed space above it is clicked, which its host handles).
struct Drawer<Content: View>: View {
    var light: [Color]
    let close: () -> Void
    @ViewBuilder let content: Content
    /// How far it has been pulled down.
    @State private var pull: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pulled further than this, or flicked, it closes; otherwise it springs back.
    static func closes(dragged: CGFloat, predicted: CGFloat) -> Bool { dragged > 90 || predicted > 220 }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 5)
                .padding(.top, Kit.Space.item)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, Kit.Space.edge)
                .padding(.top, Kit.Space.item)
                .padding(.bottom, Kit.Space.edge)
        }
        .frame(maxWidth: .infinity)
        .sheetCard(light: light)
        .offset(y: pull)
        // Scrolling on a Mac is wheel or trackpad, not a drag, so a drag anywhere on the drawer is free to pull it.
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { pull = max(0, $0.translation.height) }
                .onEnded { value in
                    if Self.closes(dragged: value.translation.height, predicted: value.predictedEndTranslation.height) {
                        close()
                    } else {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { pull = 0 }
                    }
                }
        )
    }
}

extension View {
    /// This view as a drawer that `close` takes away.
    func drawer(close: @escaping () -> Void,
                light: [Color] = [.arrived, Pot.main.light, .arrived]) -> some View {
        Drawer(light: light, close: close) { self }
    }
}
