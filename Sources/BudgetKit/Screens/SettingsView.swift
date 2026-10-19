import SwiftUI

/// Tally → Settings… (⌘,): privacy for now. Kept in the app's preferences on this Mac (`Preference`).
public struct SettingsView: View {
    @AppStorage(Preference.lock) private var lock = false
    /// Read through `saved(in:)`, so the old "always start hidden" switch shows as Hidden.
    @State private var amounts = AmountsOnOpen.saved(in: .standard)
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
            VStack(alignment: .leading, spacing: Kit.Space.item) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amounts when Tally opens").font(Kit.body)
                    Text("Click a big number or the eye, or press ⇧⌘H, to show or hide them.")
                        .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Kit.Space.item) {
                    ForEach(AmountsOnOpen.allCases, id: \.self) { choice in
                        Button(choice.title) { choose(choice) }
                            .buttonStyle(.chip(chosen: amounts == choice))
                            .accessibilityAddTraits(amounts == choice ? .isSelected : [])
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 440, alignment: .leading)
        .background { Glass(light: [Screen.plan.light], position: 0) }
    }

    private func choose(_ choice: AmountsOnOpen) {
        amounts = choice
        UserDefaults.standard.set(choice.rawValue, forKey: Preference.amountsOnOpen)
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
