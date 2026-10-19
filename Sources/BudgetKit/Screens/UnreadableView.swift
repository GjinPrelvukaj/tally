import SwiftUI

/// What a screen shows when the ledger couldn't be read: never zero figures that look like real ones.
struct UnreadableView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Couldn't read your data").font(.system(size: 14, weight: .medium))
            Text("Your saved data is untouched. Try again in a moment.").font(.system(size: 12)).opacity(0.55)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
