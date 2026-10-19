import SwiftUI

/// The monthly plan, grouped as you think of it. A row opens its editor in a panel on the right, the plan still
/// beside it; "Add Item" opens a blank one.
struct PlanPane: View {
    let store: Store
    let month: YearMonth
    /// The item being edited, in the panel.
    @State private var editing: PlanItemDraft?
    @State private var isNew = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            list.pane()
            if let editing {
                SidePanel(close: closeEditor) {
                    // A field losing focus as the panel leaves writes one last time: only into the item still open.
                    PlanItemEditor(draft: Binding { self.editing ?? editing } set: { draft in
                                       if self.editing?.id == draft.id { self.editing = draft }
                                   },
                                   incomes: store.ledger().plan.filter { $0.kind == .income && $0.id != editing.id },
                                   month: month, isNew: isNew,
                                   wasIncome: store.ledger().plan.first { $0.id == editing.id }?.kind == .income,
                                   waiting: store.ledger().waiting(on: editing.id).count,
                                   save: { store.save($0); closeEditor() },
                                   delete: { store.delete(editing.id); closeEditor() },
                                   cancel: closeEditor)
                        // Another row clicked starts afresh.
                        .id(editing.id)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func open(_ draft: PlanItemDraft, new: Bool) {
        isNew = new
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { editing = draft }
    }

    private func closeEditor() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { editing = nil }
    }

    private var list: some View {
        let ledger = store.ledger()
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THE PLAN").eyebrow()
                Spacer()
                Button { open(PlanItemDraft(startingIn: month), new: true) } label: { Label("Add Item", systemImage: "plus") }
                    .buttonStyle(.secondary)
            }
            // Clear room under the header, above where the rows fade out.
            .padding(.bottom, Kit.Space.item)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary(ledger.planSummary(for: month))
                    ForEach(PlanGroup.allCases, id: \.self) { group in
                        let items = ledger.plan.filter { $0.group == group }.sorted { $0.sortDay < $1.sortDay }
                        if !items.isEmpty { section(group, items, plan: ledger.plan) }
                    }
                }
                // Room at both ends, so at rest the first and last rows sit clear of the fades.
                .padding(.vertical, Kit.fade)
            }
            .scrollIndicators(.never)
            .edgeFade()
        }
    }

    /// The month at a glance: what comes in, goes to savings, goes out, every day takes, and what is left over.
    private func summary(_ sum: PlanSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In \(month.name)").groupLabel()
            // Four across where they fit; two by two beside an open editor.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Kit.Space.item) {
                    figure("Comes in", sum.comesIn); figure("To savings", sum.toSavings)
                    figure("Goes out", sum.goesOut); figure("Every day", sum.everyDay)
                }
                Grid(alignment: .leading, horizontalSpacing: Kit.Space.item, verticalSpacing: 10) {
                    GridRow { figure("Comes in", sum.comesIn); figure("To savings", sum.toSavings) }
                    GridRow { figure("Goes out", sum.goesOut); figure("Every day", sum.everyDay) }
                }
            }
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            HStack {
                Text(sum.left < .zero ? "Short each month" : "Left over").font(Kit.body)
                Spacer()
                Text(Cents(abs(sum.left.value)).formatted).font(Kit.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(sum.left < .zero ? Color.red : .arrived)
                    .privateAmount()
            }
        }
        .padding(14)
        .rowPanel()
    }

    private func figure(_ label: String, _ amount: Cents) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Kit.quiet).opacity(0.5).lineLimit(1).fixedSize()
            Text(amount.short).font(Kit.body.weight(.medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7).privateAmount()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A group on its own card: its symbol, name and what it comes to this month, then its items.
    private func section(_ group: PlanGroup, _ items: [PlanItem], plan: [PlanItem]) -> some View {
        VStack(alignment: .leading, spacing: Kit.Space.label) {
            HStack(spacing: 6) {
                Image(systemName: group.symbol).font(Kit.quiet).opacity(0.5)
                Text(group.title).groupLabel()
                Spacer()
                if group != .everyDay {
                    let total = items.filter { $0.applies(in: month) }.reduce(Cents.zero) { $0 + $1.amount }
                    Text(total.short).font(Living.caption).monospacedDigit().opacity(0.45).privateAmount()
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 14) }
                    row(item, plan: plan)
                }
            }
            .rowPanel()
        }
    }

    /// Two lines: the name and the amount; under them, when, how often and from where, and what a rarer one comes to a month.
    private func row(_ item: PlanItem, plan: [PlanItem]) -> some View {
        Button { open(PlanItemDraft(item), new: false) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Kit.Space.item) {
                    Text(item.name).font(Kit.body).lineLimit(1)
                    Spacer(minLength: Kit.Space.item)
                    Text(item.kind == .daily ? "\(item.amount.short) a day" : item.amount.short)
                        .font(Kit.body).monospacedDigit().privateAmount()
                }
                HStack(spacing: Kit.Space.item) {
                    Text(detail(item, plan: plan)).font(Kit.quiet).opacity(0.45).lineLimit(1)
                        .privateAmount(item.schedule.waitsForIncome)
                    Spacer(minLength: Kit.Space.item)
                    if item.repeatEvery > 1, let perMonth = item.perMonth {
                        Text("≈ \(perMonth.formatted) a month").font(Kit.quiet).monospacedDigit().opacity(0.45).privateAmount()
                    }
                }
            }
            .opacity(item.paused ? 0.4 : 0.95)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.white.opacity(editing?.id == item.id ? 0.06 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "the 1st · every year in March · from Main": when, how often, and where the money goes.
    private func detail(_ item: PlanItem, plan: [PlanItem]) -> String {
        var parts: [String] = []
        switch item.schedule {
        case .day(let day): parts.append("the \(ordinal(day))")
        case .window(let from, let to): parts.append("the \(from)–\(ordinal(to))")
        case .anyDay: if item.kind != .daily { parts.append("any day") }
        case .withIncome(let id): parts.append(plan.first { $0.id == id }.map { "with the \($0.amount.wholeEuros)" } ?? "with an income")
        }
        if let once = item.onlyIn {
            parts.append("once, in \(once.name) \(String(once.year))")
        } else if item.repeatEvery == 12, let start = item.startsIn {
            parts.append("every year in \(start.name)")
        } else if item.repeatEvery > 1, let start = item.startsIn {
            parts.append("every \(item.repeatEvery) months from \(start.shortName)")
        }
        switch item.kind {
        case .income: if let to = item.to { parts.append("into \(to.title)") }
        case .transfer: if let from = item.from, let to = item.to { parts.append("\(from.title) → \(to.title)") }
        case .payment, .daily: if let from = item.from { parts.append("from \(from.title)") }
        }
        if item.paused { parts.append("paused") }
        return parts.joined(separator: " · ")
    }
}

private extension Schedule {
    /// "with the 2 000" says an income's amount, so it hides with the amounts.
    var waitsForIncome: Bool { if case .withIncome = self { true } else { false } }
}

private extension PlanItem {
    /// Listed by the day it comes: with an income first, then by date, then any day.
    var sortDay: Int {
        switch schedule {
        case .withIncome: 0
        case .day(let day), .window(let day, _): day
        case .anyDay: 32
        }
    }
}

private extension PlanGroup {
    var symbol: String {
        switch self {
        case .comesIn: "arrow.down.left"
        case .savings: "building.columns"
        case .goesOut: "arrow.up.right"
        case .everyDay: "cup.and.saucer"
        }
    }
}
