import SwiftUI

/// "Already paid in October?": this month's items of the plan just made, each ticked or not; a ticked one's amount
/// can be changed to what was really paid.
struct FirstRunPaid: View {
    @Binding var draft: FirstRunDraft

    var body: some View {
        if draft.items.isEmpty {
            Text("Nothing in your plan is due this month.").font(Kit.body).opacity(0.55)
        } else {
            SettingsCard {
                ForEach(draft.items) { row($0) }
            }
        }
    }

    private func row(_ item: PlanItem) -> some View {
        let ticked = draft.paid.contains(item.id)
        let text = Binding { draft.amounts[item.id] ?? item.amount.editable } set: { draft.amounts[item.id] = $0 }
        return HStack(spacing: Kit.Space.item) {
            Button {
                if ticked { draft.paid.remove(item.id) } else { draft.paid.insert(item.id) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ticked ? Color.arrived : .white.opacity(0.35))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(Kit.body).lineLimit(1).opacity(ticked ? 0.95 : 0.75)
                        Text(when(item)).font(Kit.quiet).opacity(0.4)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(ticked ? .isSelected : [])
            if ticked {
                GlassField(label: "\(item.name), paid", text: text, valid: Cents.parsePositive(text.wrappedValue) != nil)
                    .frame(width: Kit.rowAmount)
                Text("€").font(Kit.body).opacity(0.55)
            } else {
                Text(item.amount.formatted).font(Kit.body).monospacedDigit().opacity(0.4).privateAmount()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private func when(_ item: PlanItem) -> String {
        switch item.schedule {
        case .day(let day): item.kind == .income ? "comes the \(ordinal(day))" : "the \(ordinal(day))"
        case .withIncome: "when you're paid"
        default: "any day"
        }
    }
}
