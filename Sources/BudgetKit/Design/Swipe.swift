import AppKit
import SwiftUI

/// Which way two fingers on the trackpad close something: the way it came. A card in the middle is pulled down;
/// a panel slid in from the right, so it goes right.
enum SwipeDirection {
    case down, right

    /// How far the fingers moved this way in one scroll event, whatever the Mac's scroll direction is set to.
    /// A move mostly the other way (scrolling a list) counts as nothing.
    func travel(deltaX: CGFloat, deltaY: CGFloat, natural: Bool) -> CGFloat {
        let (along, across) = self == .down ? (deltaY, deltaX) : (deltaX, deltaY)
        guard abs(along) >= abs(across) else { return 0 }
        // With natural scrolling the content follows the fingers, so the delta already points their way.
        return natural ? along : -along
    }
}

extension View {
    /// Two fingers pull it `direction`, `pull` following them; when they lift, `ended` gets how far they went.
    /// While it is open, a card takes the scroll so the pane behind doesn't scroll under it.
    func swipeToClose(_ direction: SwipeDirection, pull: Binding<CGFloat>, ended: @escaping (CGFloat) -> Void) -> some View {
        modifier(SwipeToClose(direction: direction, pull: pull, ended: ended))
    }
}

private struct SwipeToClose: ViewModifier {
    let direction: SwipeDirection
    @Binding var pull: CGFloat
    let ended: (CGFloat) -> Void
    @State private var monitor: Any?
    @State private var travel: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                // A local monitor: SwiftUI has no two-finger swipe on the Mac, and scroll events only come this way.
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    MainActor.assumeIsolated { handle(event) }
                    return direction == .down ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }

    @MainActor private func handle(_ event: NSEvent) {
        // Only a trackpad's own movement: not a mouse wheel, not the glide after the fingers lift.
        guard event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return }
        if event.phase.contains(.began) { travel = 0 }
        if event.phase.contains(.began) || event.phase.contains(.changed) {
            travel += direction.travel(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                                       natural: event.isDirectionInvertedFromDevice)
            pull = max(0, travel)
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            ended(travel)
            travel = 0
        }
    }
}
