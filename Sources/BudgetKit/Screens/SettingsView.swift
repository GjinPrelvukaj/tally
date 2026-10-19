import SwiftUI

/// Settings, a section of its own in the sidebar (⌘,): Privacy, Categories and the Partner, one at a time behind a
/// glass bar, each on quiet cards of rows. Privacy and the partner's name are kept in the app's preferences on this
/// Mac (`Preference`); categories in the store, with the money.
struct SettingsView: View {
    let store: Store
    @State private var tab = Tab.privacy

    enum Tab: Hashable { case privacy, categories, partner }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Kit.Space.edge) {
                Text("SETTINGS").eyebrow()
                GlassSegments(selection: $tab, choices: [(.privacy, "Privacy", "lock"), (.categories, "Categories", "tag"),
                                                         (.partner, "Partner", "person.2")])
                    .frame(maxWidth: 420)
                switch tab {
                case .privacy: PrivacySettings()
                case .categories: CategorySettings(store: store)
                case .partner: PartnerSettings()
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .padding(.bottom, Kit.Space.edge)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
    }
}

/// A setting's row on a card: what it is and a line about it on the left, its control on the right (or under).
struct SettingRow<Control: View>: View {
    let title: String
    var detail: String?
    /// The control under the words instead of beside them, for a wide one.
    var under = false
    @ViewBuilder let control: Control

    var body: some View {
        let words = VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Kit.body)
            if let detail { Text(detail).font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true) }
        }
        Group {
            if under {
                VStack(alignment: .leading, spacing: Kit.Space.item + 2) { words; control }
            } else {
                HStack(spacing: Kit.Space.group) { words; Spacer(minLength: Kit.Space.item); control }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rows on one card, a hairline between each.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 14) }
                    row
                }
            }
        }
        .rowPanel()
    }
}

/// Lock with Touch ID, and how amounts start.
private struct PrivacySettings: View {
    @AppStorage(Preference.lock) private var lock = false
    /// Read through `saved(in:)`, so the old "always start hidden" switch shows as Hidden.
    @State private var amounts = AmountsOnOpen.saved(in: .standard)
    @State private var asking = false

    var body: some View {
        SettingsCard {
            SettingRow(title: LockView.canUseTouchID ? "Lock with Touch ID" : "Lock with your Mac's password",
                       detail: LockView.canLock ? "Asks when Tally opens and after your Mac sleeps."
                                                : "This Mac has no password or Touch ID to ask for.") {
                Toggle("", isOn: Binding { lock } set: { turnLock($0) }).labelsHidden().toggleStyle(.glass)
                    .disabled(!LockView.canLock || asking)
            }
            SettingRow(title: "Amounts when Tally opens",
                       detail: "Click a big number or the eye, or press ⇧⌘H, to show or hide them.", under: true) {
                GlassSegments(selection: Binding { amounts } set: { choose($0) },
                              choices: [(.shown, AmountsOnOpen.shown.title, "eye"), (.hidden, AmountsOnOpen.hidden.title, "eye.slash"),
                                        (.asLeft, AmountsOnOpen.asLeft.title, "clock.arrow.circlepath")])
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
}

/// The partner's name; with none, nothing of the partner shows anywhere.
private struct PartnerSettings: View {
    @AppStorage(Preference.partnerName) private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            SettingsCard {
                SettingRow(title: "Partner's name") {
                    GlassField(label: "Partner's name", text: $name, align: .leading, hint: "Name", secret: false)
                        .frame(width: Kit.field)
                }
            }
            Text("Spends can then say you were with them, or what was theirs, and keep what they owe you. Leave it empty to turn this off.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
        }
    }
}
