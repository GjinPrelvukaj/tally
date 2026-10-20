import SwiftUI

/// One plan item: what it is, how much, when, and whether it counts. Delete keeps its past payments.
struct PlanItemEditor: View {
    @Binding var draft: PlanItemDraft
    /// The other incomes an item can wait for.
    let incomes: [PlanItem]
    /// Every pot shown, named, for where money comes from and goes to.
    let potChoices: [(Pot, String)]
    let month: YearMonth
    let isNew: Bool
    /// Whether it is an income now, and how many items wait for it: changing or deleting it moves them to "any day".
    let wasIncome: Bool
    let waiting: Int
    let save: (PlanItem) -> Void
    let delete: () -> Void
    let cancel: () -> Void
    @State private var confirmingDelete = false
    @State private var confirmingChange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "NEW ITEM" : "EDIT ITEM").eyebrow()
            VStack(spacing: 8) {
                line("Name") {
                    GlassField(label: "Name", text: $draft.name, align: .trailing, hint: "Name", autofocus: isNew, secret: false).frame(width: Kit.field)
                }
                line(draft.kind == .daily ? "A day" : "Amount") {
                    HStack(spacing: 6) {
                        GlassField(label: "Amount", text: $draft.amount, valid: draft.amountCents != nil)
                        Text("€").opacity(0.55)
                    }
                    .frame(width: Kit.field)
                }
                line("Kind") {
                    pick($draft.kind, [(.income, "Comes in"), (.transfer, "Moves to a pot"), (.payment, "Goes out"), (.daily, "Every day")])
                }
                if draft.kind != .income { line("From") { pots($draft.from) } }
                if draft.kind == .income || draft.kind == .transfer { line("To") { pots($draft.to) } }
                if draft.kind != .daily { when }
                line("Repeats") {
                    pick($draft.repeats, [(.everyMonth, "Every month"), (.every(2), "Every 2 months"), (.every(3), "Every 3 months"),
                                          (.every(6), "Every 6 months"), (.every(12), "Every year"), (.once, "Once")])
                }
                if draft.repeats != .everyMonth {
                    line(draft.repeats == .once ? "In" : "Starting") { pick($draft.repeatMonth, months) }
                }
                line("Paused") {
                    Toggle("", isOn: $draft.paused).labelsHidden().toggleStyle(.glass)
                }
            }
            .font(.system(size: 13))
            .padding(.top, 14)
            Spacer(minLength: 8)
            if !isNew {
                Button("Delete Item…") { confirmingDelete = true }
                    .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(.red.opacity(0.85))
                    .padding(.bottom, 10)
                    .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmingDelete) {
                        Button("Delete", role: .destructive, action: delete)
                    } message: { Text("Its past payments stay. \(waitingNote)") }
            }
            HStack {
                Button("Cancel", action: cancel)
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { if losesItems { confirmingChange = true } else if let item = draft.item { save(item) } }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.item == nil)
                    .confirmationDialog("Stop \(draft.name) being an income?", isPresented: $confirmingChange) {
                        Button("Change") { if let item = draft.item { save(item) } }
                    } message: { Text(waitingNote) }
            }
        }
    }

    private var losesItems: Bool { wasIncome && draft.kind != .income && waiting > 0 }

    /// Said before the change, so it is no surprise: the items paid from this income lose their "when".
    private var waitingNote: String {
        waiting == 0 ? "" : "\(waiting) item\(waiting == 1 ? "" : "s") paid from it will become 'any day'."
    }

    // MARK: When

    @ViewBuilder private var when: some View {
        line("When") {
            pick($draft.when, [(.day, "A day"), (.window, "A window"), (.anyDay, "Any day"), (.withIncome, "When an income arrives")])
        }
        switch draft.when {
        case .day:
            line("Day") { pick($draft.day, days) }
        case .window:
            line("From") { pick($draft.windowFrom, days) }
            line("To") { pick($draft.windowTo, days) }
        case .withIncome:
            line("Income") {
                pick(Binding { draft.income } set: { draft.income = $0 }, incomes.map { ($0.id as UUID?, $0.name) })
            }
        case .anyDay: EmptyView()
        }
    }

    private var days: [(Int, String)] { (1...31).map { ($0, "the \(ordinal($0))") } }

    /// A year back to two years ahead, and whatever month it already holds.
    private var months: [(YearMonth, String)] {
        var all = [month]
        for _ in 0..<12 { all.insert(all[0].previous, at: 0) }
        for _ in 0..<24 { all.append(all[all.count - 1].next) }
        if !all.contains(draft.repeatMonth) { all = (all + [draft.repeatMonth]).sorted() }
        return all.map { ($0, $0.shortName) }
    }

    // MARK: Pieces

    private func line<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            Text(label).opacity(0.55)
            Spacer(minLength: 8)
            content()
        }
        .frame(minHeight: 24)
    }

    private func pots(_ pot: Binding<Pot?>) -> some View {
        pick(pot, potChoices.map { ($0.0 as Pot?, $0.1) })
    }

    /// A pop-up of named choices, in the order given.
    private func pick<Value: Hashable>(_ selection: Binding<Value>, _ choices: [(Value, String)]) -> some View {
        GlassPicker(selection: selection, choices: choices)
    }
}
