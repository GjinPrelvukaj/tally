import SwiftUI

/// Settings, a section of its own in the sidebar (⌘,): Privacy, Categories and the Partner, one under another.
/// Privacy and the partner's name are kept in the app's preferences on this Mac (`Preference`); categories in
/// the store, with the money.
struct SettingsView: View {
    let store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                group("Privacy") { PrivacySettings() }
                group("Categories") { CategorySettings(store: store) }
                group("Partner") { PartnerSettings() }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .padding(.bottom, Kit.Space.edge)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            Text(title.uppercased()).eyebrow()
            content()
        }
    }
}

/// Lock with Touch ID, and how amounts start.
private struct PrivacySettings: View {
    @AppStorage(Preference.lock) private var lock = false
    /// Read through `saved(in:)`, so the old "always start hidden" switch shows as Hidden.
    @State private var amounts = AmountsOnOpen.saved(in: .standard)
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
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

/// The partner's name; with none, nothing of the partner shows anywhere.
private struct PartnerSettings: View {
    @AppStorage(Preference.partnerName) private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            HStack {
                Text("Partner's name").font(Kit.body)
                Spacer(minLength: Kit.Space.item)
                GlassField(label: "Partner's name", text: $name, align: .leading, hint: "Name", secret: false)
                    .frame(width: Kit.field)
            }
            Text("Spends can then say you were with them, or what was theirs, and keep what they owe you. Leave it empty to turn this off.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
        }
    }
}
