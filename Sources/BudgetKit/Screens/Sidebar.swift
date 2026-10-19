import SwiftUI

/// The window's left column: the seven sections (⌘1 to ⌘7) and Settings (⌘,), what can be spent a day, and Log a Spend.
struct Sidebar: View {
    let store: Store
    let today: Date
    let section: Screen
    let go: (Screen) -> Void
    let log: () -> Void
    @Environment(\.toggleAmounts) private var toggleAmounts
    @Environment(\.redactionReasons) private var redaction

    private var hidden: Bool { redaction.contains(.privacy) }

    var body: some View {
        let ledger = store.ledger()
        let month = YearMonth(today, calendar: ledger.calendar)
        VStack(alignment: .leading, spacing: 2) {
            item(.today, count: ledger.stillToPay(today: today).count)
            item(.pots)
            item(.month)
            // How many need looking at: the warnings, not every insight.
            item(.insights, count: store.loadError == nil ? ledger.insights(today: today, partnerName: "").filter { $0.level == .warning }.count : 0)
            Text("Records").groupLabel()
                .padding(.leading, 10).padding(.top, Kit.Space.group).padding(.bottom, 4)
            item(.entries, count: ledger.entries(in: month).count)
            item(.plan)
            item(.people)
            item(.settings).padding(.top, Kit.Space.group)
            Spacer()
            // Today says it already, larger.
            if section != .today, store.loadError == nil, let allowance = ledger.allowance(today: today) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU CAN SPEND").eyebrow()
                    Text(allowance.perDay.formatted).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                        .bigAmount()
                        .foregroundStyle(allowance.perDay < .zero ? Color.red : .white)
                    Text("a day until the \(allowance.until.item.amount.wholeEuros)").font(Kit.quiet).opacity(0.45).privacySensitive()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, Kit.Space.group)
                .accessibilityElement(children: .combine)
                .transition(.opacity)
            }
            HStack(spacing: Kit.Space.item) {
                Button(action: log) { Label("Log a Spend", systemImage: "plus").frame(maxWidth: .infinity) }
                    .buttonStyle(.primary(section.tint))
                Button(action: toggleAmounts) { Image(systemName: hidden ? "eye.slash" : "eye").frame(width: 14) }
                    .buttonStyle(.secondary)
                    .help(hidden ? "Show amounts (⇧⌘H)" : "Hide amounts (⇧⌘H)")
                    .accessibilityLabel(hidden ? "Show amounts" : "Hide amounts")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.025))
    }

    private func item(_ screen: Screen, count: Int = 0) -> some View {
        Button { go(screen) } label: {
            HStack(spacing: 10) {
                Image(systemName: screen.symbol).frame(width: 18)
                Text(screen.title)
                Spacer()
                if count > 0 { Text("\(count)").font(Kit.quiet).monospacedDigit().opacity(0.6) }
            }
        }
        .buttonStyle(.sidebarItem(chosen: screen == section))
        .accessibilityAddTraits(screen == section ? .isSelected : [])
    }
}
