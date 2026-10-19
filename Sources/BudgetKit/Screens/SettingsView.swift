import SwiftUI

/// Tally → Settings… (⌘,): privacy for now. Kept in the app's preferences on this Mac (`Preference`).
public struct SettingsView: View {
    @AppStorage(Preference.lock) private var lock = false
    @AppStorage(Preference.hideAmounts) private var hideAmounts = false
    @State private var asking = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            Text("PRIVACY").eyebrow()
            setting(LockView.canUseTouchID ? "Lock with Touch ID" : "Lock with your Mac's password",
                    LockView.canLock ? "Asks when Tally opens and after your Mac sleeps."
                                     : "This Mac has no password or Touch ID to ask for.",
                    isOn: Binding { lock } set: { turnLock($0) })
                .disabled(!LockView.canLock || asking)
            setting("Hide amounts when Tally opens",
                    "Click a big number or the eye, or press ⇧⌘H, to show or hide them.",
                    isOn: $hideAmounts)
        }
        .padding(28)
        .frame(width: 440, alignment: .leading)
        .background { Glass(light: [Screen.plan.light], position: 0) }
    }

    /// Turning it on asks first, so a lock that can't be opened is never set.
    private func turnLock(_ on: Bool) {
        guard on else { lock = false; return }
        asking = true
        Task {
            lock = await LockView.authenticate(reason: "lock Tally")
            asking = false
        }
    }

    private func setting(_ title: String, _ detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: Kit.Space.group) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Kit.body)
                Text(detail).font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Kit.Space.item)
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.glass)
        }
        .accessibilityElement(children: .combine)
    }
}
