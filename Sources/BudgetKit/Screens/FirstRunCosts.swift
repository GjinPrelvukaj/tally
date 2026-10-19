import SwiftUI

/// The first run's regular costs: the usual ones as chips to pick, then each picked one on a card with its amount, its
/// day (or with the pay) and how often; "Add Your Own" for the rest.
struct FirstRunCosts: View {
    @Binding var draft: FirstRunDraft

    private static let usual = ["Rent", "Bills", "Phone", "Internet", "Insurance", "Subscriptions", "Gym", "Transport"]

    var body: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            // Wraps in a narrow window, one row in a wide one.
            ViewThatFits(in: .horizontal) {
                chips(Self.usual)
                VStack(alignment: .leading, spacing: Kit.Space.item) {
                    chips(Array(Self.usual.prefix(4)))
                    chips(Array(Self.usual.suffix(4)))
                }
            }
            if !draft.costs.isEmpty {
                SettingsCard {
                    ForEach($draft.costs) { $cost in row($cost) }
                }
            }
            Button { draft.addCost("") } label: { Label("Add Your Own", systemImage: "plus") }
                .buttonStyle(.secondary)
        }
    }

    private func chips(_ names: [String]) -> some View {
        HStack(spacing: Kit.Space.item) {
            ForEach(names, id: \.self) { name in
                let picked = draft.costs.contains { $0.name == name }
                Button(name) { draft.addCost(name) }
                    .buttonStyle(.chip(chosen: picked))
                    .disabled(picked)
            }
        }
    }

    /// Name, amount and a way to take it off; under them when it comes and how often.
    private func row(_ cost: Binding<FirstRunCost>) -> some View {
        let typed = cost.wrappedValue.amount.trimmingCharacters(in: .whitespaces)
        let named = !cost.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(alignment: .leading, spacing: Kit.Space.item) {
            HStack(spacing: Kit.Space.item) {
                GlassField(label: "Name", text: cost.name, align: .leading, valid: named || typed.isEmpty, hint: "Name", secret: false)
                    .frame(width: Kit.field)
                Spacer(minLength: Kit.Space.item)
                GlassField(label: "\(cost.wrappedValue.name) amount", text: cost.amount,
                           valid: typed.isEmpty || Cents.parsePositive(typed) != nil)
                    .frame(width: Kit.rowAmount)
                Text("€").font(Kit.body).opacity(0.55)
                Button { draft.costs.removeAll { $0.id == cost.wrappedValue.id } } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.quiet)
                .accessibilityLabel("Remove \(cost.wrappedValue.name)")
            }
            HStack(spacing: Kit.Space.item) {
                GlassPicker(selection: cost.yearly, choices: [(false, "Every month"), (true, "Every year")])
                if cost.wrappedValue.yearly {
                    GlassPicker(selection: cost.inMonth, choices: (1...12).map { ($0, "in \(YearMonth(2026, $0).name)") })
                }
                GlassPicker(selection: cost.day, choices: [(nil, withPay)] + FirstRunPage.days.map { (Optional($0.0), $0.1) })
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// No day: paid when the pay comes, or any day without one.
    private var withPay: String {
        draft.incomeAmount.trimmingCharacters(in: .whitespaces).isEmpty ? "Any day" : "When I'm paid"
    }
}
