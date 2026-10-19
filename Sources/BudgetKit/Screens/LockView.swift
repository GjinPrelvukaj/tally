import LocalAuthentication
import SwiftUI

/// In place of everything while Tally is locked: nothing of the money is drawn until Touch ID (or the Mac's
/// password) says it is you. It asks at once, and again on a click.
struct LockView: View {
    let unlock: () -> Void
    @State private var asking = false

    var body: some View {
        VStack(spacing: Kit.Space.group) {
            Image(systemName: "lock.fill").font(.system(size: 28, weight: .medium)).opacity(0.7)
            Text("Tally is locked").font(Kit.title)
            Button(Self.canUseTouchID ? "Unlock with Touch ID" : "Unlock", action: ask)
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(asking)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: ask)
    }

    private func ask() {
        guard !asking else { return }
        asking = true
        Task {
            let ok = await Self.authenticate(reason: "show your money")
            asking = false
            if ok { unlock() }
        }
    }

    /// Touch ID, or the Mac's password when there is none or it fails.
    static func authenticate(reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    /// Whether the Mac can check it is you at all (a password is enough).
    static var canLock: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    static var canUseTouchID: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) }
}
