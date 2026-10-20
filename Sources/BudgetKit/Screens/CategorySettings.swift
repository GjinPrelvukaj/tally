import SwiftUI

/// Settings → Categories: yours on one card (name, the pot its spends come out of, and Retire or Bring Back in a
/// small menu), and adding one on another.
struct CategorySettings: View {
    let store: Store
    @State private var newName = ""
    @State private var newPot = Pot.main

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            SettingsCard {
                ForEach(store.ledger().categories) { CategoryRow(category: $0, pots: Self.choices(store.ledger()), save: store.update) }
            }
            Text("Moving one to another pot changes spends from now on; the ones saved stay where they were. A retired one isn't offered, but its spends keep it.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.bottom, Kit.Space.item)
            SettingsCard {
                HStack(spacing: Kit.Space.item) {
                    GlassField(label: "New category", text: $newName, align: .leading, hint: "New category", secret: false)
                        .frame(width: 200)
                        .onSubmit(add)
                    GlassPicker(selection: $newPot, choices: Self.choices(store.ledger()), width: 150)
                    Spacer(minLength: 0)
                    Button("Add", action: add)
                        .buttonStyle(.secondary)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func add() {
        guard store.addCategory(newName, pot: newPot) != nil else { return }
        newName = ""
    }

    /// Main and each savings pot, by name: where a category's spends can come out of.
    static func choices(_ ledger: Ledger) -> [(Pot, String)] { ledger.spendingPots.map { ($0, ledger.name($0)) } }
}

/// One category: its name (saved as it is typed, never empty), its pot, and a menu to retire it or bring it back.
private struct CategoryRow: View {
    let category: Category
    /// The pots a spend can come out of, named.
    let pots: [(Pot, String)]
    let save: (Category) -> Void
    @State private var name: String

    init(category: Category, pots: [(Pot, String)], save: @escaping (Category) -> Void) {
        self.category = category
        self.pots = pots
        self.save = save
        _name = State(initialValue: category.name)
    }

    var body: some View {
        HStack(spacing: Kit.Space.item) {
            GlassField(label: "Name", text: $name, align: .leading, valid: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                       hint: category.name, secret: false)
                .frame(width: 200)
                .onChange(of: name) { changed { $0.name = name } }
            GlassPicker(selection: Binding { category.pot } set: { pot in changed { $0.pot = pot } },
                        choices: pots, width: 150)
            Spacer(minLength: 0)
            if category.retired { Text("Retired").font(Kit.quiet).opacity(0.45) }
            Menu {
                Button(category.retired ? "Bring Back" : "Retire") { changed { $0.retired.toggle() } }
            } label: {
                Image(systemName: "ellipsis").font(Kit.body).frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(0.6)
            .accessibilityLabel(category.retired ? "Bring \(category.name) back" : "Retire \(category.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(category.retired ? 0.55 : 1)
    }

    private func changed(_ change: (inout Category) -> Void) {
        var category = category
        change(&category)
        save(category)
    }
}
