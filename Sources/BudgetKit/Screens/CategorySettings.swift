import SwiftUI

/// Settings → Categories: each one's name and the pot its spends come out of; retire one you no longer use
/// (its spends keep it), bring it back, or add your own.
struct CategorySettings: View {
    let store: Store
    @State private var newName = ""
    @State private var newPot = Pot.main

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            HStack {
                Text("Name").groupLabel().frame(width: Kit.field, alignment: .leading)
                Text("Comes out of").groupLabel()
            }
            ForEach(store.ledger().categories) { CategoryRow(category: $0, save: store.update) }
            HStack(spacing: Kit.Space.item) {
                GlassField(label: "New category", text: $newName, align: .leading, hint: "New category", secret: false)
                    .frame(width: Kit.field)
                    .onSubmit(add)
                GlassPicker(selection: $newPot, choices: Category.pots.map { ($0, $0.title) }, width: 140)
                Spacer(minLength: 0)
                Button("Add", action: add)
                    .buttonStyle(.secondary)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, Kit.Space.label)
            Text("Moving a category to another pot changes spends from now on; the ones saved stay where they were.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func add() {
        guard store.addCategory(newName, pot: newPot) != nil else { return }
        newName = ""
    }
}

/// One category: its name (saved as it is typed, never empty), its pot, and Retire or Bring Back.
private struct CategoryRow: View {
    let category: Category
    let save: (Category) -> Void
    @State private var name: String

    init(category: Category, save: @escaping (Category) -> Void) {
        self.category = category
        self.save = save
        _name = State(initialValue: category.name)
    }

    var body: some View {
        HStack(spacing: Kit.Space.item) {
            GlassField(label: "Name", text: $name, align: .leading, valid: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                       hint: category.name, secret: false)
                .frame(width: Kit.field)
                .onChange(of: name) { changed { $0.name = name } }
            GlassPicker(selection: Binding { category.pot } set: { pot in changed { $0.pot = pot } },
                        choices: Category.pots.map { ($0, $0.title) }, width: 140)
            Spacer(minLength: 0)
            Button(category.retired ? "Bring Back" : "Retire") { changed { $0.retired.toggle() } }
                .buttonStyle(.quiet)
        }
        .opacity(category.retired ? 0.5 : 1)
    }

    private func changed(_ change: (inout Category) -> Void) {
        var category = category
        change(&category)
        save(category)
    }
}
