import SwiftUI

/// "Undo", for a few seconds after something is recorded. One delayed hide, so nothing runs while idle.
struct UndoPill: View {
    let undo: () -> Void

    var body: some View {
        Button(action: undo) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .semibold))
                Text("Undo")
            }
            .font(.system(size: 12))
        }
        .buttonStyle(.secondary)
        .accessibilityLabel("Undo the last thing you recorded")
    }
}
