import SwiftUI

/// The monthly plan, grouped as you think of it. A row opens its editor in a panel on the right, the plan still
/// beside it; "Add Item" opens a blank one.
struct PlanPane: View {
    let store: Store
    let month: YearMonth
    /// The item being edited, in the panel.
    @State private var editing: PlanItemDraft?
    @State private var isNew = false
    /// How tall the fade above the buttons is.
    private let fade: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            list.pane()
            if let editing {
                SidePanel {
                    PlanItemEditor(draft: Binding { self.editing ?? editing } set: { self.editing = $0 },
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
        let plan = store.ledger().plan
        return VStack(alignment: .leading, spacing: 0) {
            Text("THE PLAN").eyebrow()
            ScrollView {
                VStack(alignment: .leading, spacing: Kit.Space.group) {
                    ForEach(PlanGroup.allCases, id: \.self) { group in
                        let items = plan.filter { $0.group == group }
                        if !items.isEmpty { section(group, items, plan: plan) }
                    }
                }
                .padding(.top, Kit.Space.group)
                // Room past the last row, so scrolled to the end it sits clear of the fade below.
                .padding(.bottom, fade)
            }
            .scrollIndicators(.never)
            // Rows fade out above the buttons instead of running under them.
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: fade)
                }
            }
            Button("Add Item") { open(PlanItemDraft(), new: true) }
                .buttonStyle(.secondary)
                .padding(.top, Kit.Space.label)
        }
    }

    /// A group's heading with its monthly total, then its items on one quiet panel.
    private func section(_ group: PlanGroup, _ items: [PlanItem], plan: [PlanItem]) -> some View {
        VStack(alignment: .leading, spacing: Kit.Space.label) {
            HStack {
                Text(group.title).groupLabel()
                Spacer()
                if group != .everyDay {
                    let total = items.filter { !$0.paused }.reduce(Cents.zero) { $0 + $1.amount }
                    Text(total.short).font(Living.caption).monospacedDigit().opacity(0.45).privacySensitive()
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 12) }
                    row(item, plan: plan)
                }
            }
            .rowPanel()
        }
    }

    /// One line: the name, when it happens in a word or two, the amount.
    private func row(_ item: PlanItem, plan: [PlanItem]) -> some View {
        Button { open(PlanItemDraft(item), new: false) } label: {
            HStack(spacing: Kit.Space.item) {
                Text(item.name).font(Kit.body).lineLimit(1).layoutPriority(1)
                Spacer(minLength: Kit.Space.item)
                Text(when(item, plan: plan)).font(Kit.quiet).opacity(0.4).lineLimit(1)
                    .privacySensitive(item.schedule.waitsForIncome)
                Text(item.amount.short).font(Kit.body).monospacedDigit().privacySensitive()
            }
            .opacity(item.paused ? 0.4 : 0.9)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.white.opacity(editing?.id == item.id ? 0.06 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "1st", "15–20th", "with the 2 000", "any day": short, so the list stays calm.
    private func when(_ item: PlanItem, plan: [PlanItem]) -> String {
        var text = switch item.schedule {
        case .day(let day): ordinal(day)
        case .window(let from, let to): "\(from)–\(ordinal(to))"
        case .anyDay: item.kind == .daily ? "a day" : "any day"
        case .withIncome(let id): plan.first { $0.id == id }.map { "with the \($0.amount.wholeEuros)" } ?? "with an income"
        }
        if let only = item.onlyIn { text += " · \(only.shortName)" }
        if item.paused { text += " · paused" }
        return text
    }
}

private extension Schedule {
    /// "with the 2 000" says an income's amount, so it hides with the amounts.
    var waitsForIncome: Bool { if case .withIncome = self { true } else { false } }
}
