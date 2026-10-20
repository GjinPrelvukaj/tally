import SwiftUI

/// The first run's savings pots: the usual ones as chips to pick, each picked one on a card with its name, what goes in
/// each month when paid, and its goal; "Add Your Own" for the rest. An emergency fund is there to begin with.
struct FirstRunSavings: View {
    @Binding var draft: FirstRunDraft

    private static let usual = ["Emergency fund", "Holiday", "Clothes", "Car", "Gifts", "Home"]

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            // One row in a wide window, two in a narrow one.
            ViewThatFits(in: .horizontal) {
                chips(Self.usual)
                VStack(alignment: .leading, spacing: Kit.Space.item) {
                    chips(Array(Self.usual.prefix(3)))
                    chips(Array(Self.usual.suffix(3)))
                }
            }
            if !draft.savings.isEmpty {
                SettingsCard {
                    ForEach($draft.savings) { $saving in row($saving) }
                }
            }
            Button { draft.addPot("") } label: { Label("Add Your Own", systemImage: "plus") }
                .buttonStyle(.secondary)
        }
    }

    private func chips(_ names: [String]) -> some View {
        HStack(spacing: Kit.Space.item) {
            ForEach(names, id: \.self) { name in
                let picked = draft.savings.contains { $0.pot.name == name }
                Button(name) { draft.addPot(name) }
                    .buttonStyle(.chip(chosen: picked))
                    .disabled(picked)
            }
        }
    }

    /// Its colour, its name and a way to take it off; under them what goes in each month and its goal.
    private func row(_ saving: Binding<FirstRunSaving>) -> some View {
        let named = !saving.wrappedValue.pot.name.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(alignment: .leading, spacing: Kit.Space.item) {
            HStack(spacing: Kit.Space.item) {
                Circle().fill(Pot.palette[saving.wrappedValue.pot.colour % Pot.palette.count]).frame(width: 8, height: 8)
                GlassField(label: "Pot name", text: saving.pot.name, align: .leading, valid: named, hint: "Name", secret: false)
                    .frame(width: Kit.field)
                Spacer(minLength: Kit.Space.item)
                Button { draft.savings.removeAll { $0.id == saving.wrappedValue.id } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.quiet)
                .accessibilityLabel("Remove \(saving.wrappedValue.pot.name)")
            }
            HStack(spacing: Kit.Space.group) {
                amount("Each month", saving.monthly, label: "\(saving.wrappedValue.pot.name) each month")
                amount("Goal", saving.goal, label: "\(saving.wrappedValue.pot.name) goal")
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func amount(_ title: String, _ text: Binding<String>, label: String) -> some View {
        let typed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
        return HStack(spacing: 6) {
            Text(title).font(Kit.quiet).opacity(0.55)
            GlassField(label: label, text: text, valid: typed.isEmpty || Cents.parsePositive(typed) != nil)
                .frame(width: Kit.rowAmount)
            Text("€").font(Kit.body).opacity(0.55)
        }
    }
}
