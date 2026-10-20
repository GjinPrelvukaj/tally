import SwiftUI

/// Settings → Pots: your savings pots on one card (colour, name, goal, and Retire or Bring Back in a small menu), adding
/// one on another. Main and the card are always there, so they aren't listed.
struct PotSettings: View {
    let store: Store
    @State private var newName = ""

    var body: some View {
        let ledger = store.ledger()
        VStack(alignment: .leading, spacing: Kit.Space.item) {
            if ledger.savings.isEmpty {
                Text("No savings pots yet.").font(Kit.body).opacity(0.55).padding(.horizontal, 14)
            } else {
                SettingsCard {
                    // Retired ones last.
                    ForEach(ledger.savings.filter { !$0.retired } + ledger.savings.filter(\.retired)) { pot in
                        PotRow(pot: pot, goal: ledger.goals[pot.id], canRetire: ledger.canRetire(pot.id), store: store)
                    }
                }
            }
            Text("A pot can be retired once it's empty and nothing in the plan moves money into or out of it. Its entries keep it.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.bottom, Kit.Space.item)
            SettingsCard {
                HStack(spacing: Kit.Space.item) {
                    GlassField(label: "New pot", text: $newName, align: .leading, hint: "New pot", secret: false)
                        .frame(width: 200)
                        .onSubmit(add)
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
        guard store.addPot(newName) != nil else { return }
        newName = ""
    }
}

/// One savings pot: its colour, its name (saved as it is typed, never empty), its goal (saved once it reads; empty for
/// none), and a menu to retire it or bring it back.
private struct PotRow: View {
    let pot: SavingsPot
    let canRetire: Bool
    let store: Store
    @State private var name: String
    @State private var goal: String

    init(pot: SavingsPot, goal: Cents?, canRetire: Bool, store: Store) {
        self.pot = pot
        self.canRetire = canRetire
        self.store = store
        _name = State(initialValue: pot.name)
        _goal = State(initialValue: goal?.editable ?? "")
    }

    var body: some View {
        let goalReads = goal.trimmingCharacters(in: .whitespaces).isEmpty || Cents.parsePositive(goal) != nil
        HStack(spacing: Kit.Space.item) {
            Circle().fill(Pot.palette[pot.colour % Pot.palette.count]).frame(width: 8, height: 8)
            GlassField(label: "Name", text: $name, align: .leading, valid: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                       hint: pot.name, secret: false)
                .frame(width: 200)
                .onChange(of: name) { store.rename(pot.id, to: name) }
            Spacer(minLength: Kit.Space.item)
            if pot.retired {
                Text("Retired").font(Kit.quiet).opacity(0.45)
            } else {
                Text("Goal").font(Kit.quiet).opacity(0.55)
                GlassField(label: "\(pot.name) goal", text: $goal, valid: goalReads, hint: "none")
                    .frame(width: Kit.rowAmount)
                    .onChange(of: goal) {
                        let typed = goal.trimmingCharacters(in: .whitespaces)
                        if typed.isEmpty { store.setGoal(nil, for: pot.id) } else if let cents = Cents.parsePositive(typed) { store.setGoal(cents, for: pot.id) }
                    }
                Text("€").font(Kit.body).opacity(0.55)
            }
            Menu {
                if pot.retired {
                    Button("Bring Back") { store.bringBack(pot.id) }
                } else {
                    Button(canRetire ? "Retire" : "Retire (empty it and take it out of the plan first)") { store.retire(pot.id) }
                        .disabled(!canRetire)
                }
            } label: {
                Image(systemName: "ellipsis").font(Kit.body).frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("More for \(pot.name)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
