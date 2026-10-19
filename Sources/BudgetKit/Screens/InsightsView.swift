import SwiftUI

/// Insights: what is worth knowing about the money today, the most pressing first, each worked out exactly by
/// the ledger, with one line over them saying what needs a look.
struct InsightsView: View {
    let store: Store
    let today: Date
    @Environment(\.partnerName) private var partnerName

    var body: some View {
        if store.loadError != nil {
            UnreadableView()
        } else {
            let insights = store.ledger().insights(today: today, partnerName: partnerName)
            ScrollView {
                VStack(alignment: .leading, spacing: Kit.Space.item) {
                    Text("INSIGHTS").eyebrow().padding(.bottom, Kit.Space.label)
                    // Only on a Mac with Apple Intelligence: it reads the question, code answers it.
                    if AskReader.available { AskBox(store: store, today: today) }
                    if let headline = Insight.headline(insights) { summaryCard(headline) }
                    if insights.isEmpty {
                        Text("Nothing to point out yet. Insights come as you log what you spend.")
                            .font(Kit.body).opacity(0.55)
                    }
                    ForEach(insights) { InsightCard(insight: $0) }
                }
                .frame(maxWidth: Kit.readable, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 36)
                .padding(.bottom, Kit.Space.edge)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)
        }
    }

    private func summaryCard(_ headline: String) -> some View {
        VStack(alignment: .leading, spacing: Kit.Space.label) {
            Label("In short", systemImage: "sparkles").font(Living.caption).opacity(0.55)
            Text(headline).font(Kit.body).fixedSize(horizontal: false, vertical: true).privateAmount()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowPanel()
        .padding(.bottom, Kit.Space.item)
    }
}

/// One insight: a dot saying how much it matters, its title, and its one line.
private struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: 2.5)
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(Kit.body.weight(.medium))
                Text(insight.detail).font(Kit.quiet).opacity(0.55).fixedSize(horizontal: false, vertical: true)
            }
            // Titles and lines carry amounts: they hide with the rest.
            .privateAmount()
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rowPanel()
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch insight.level {
        case .warning: .hex(0xFBBF24)
        case .notice: .white.opacity(0.6)
        case .good: .arrived
        }
    }
}
