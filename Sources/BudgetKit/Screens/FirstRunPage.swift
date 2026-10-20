import SwiftUI

/// One page of the first run: a question, a line on what it is for, and its fields on cards.
struct FirstRunPage: View {
    let step: FirstRunStep
    @Binding var draft: FirstRunDraft
    @Binding var partner: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(question).font(Kit.title).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(Kit.body).opacity(0.55).fixedSize(horizontal: false, vertical: true)
                .padding(.top, Kit.Space.label)
            Group {
                switch step {
                case .welcome: welcome
                case .income: income
                case .costs: FirstRunCosts(draft: $draft)
                case .saving: saving
                case .pots: pots
                case .paid: FirstRunPaid(draft: $draft)
                case .partner: partnerName
                }
            }
            .padding(.top, 24)
        }
    }

    private var question: String {
        switch step {
        case .welcome: "Welcome to Tally"
        case .income: "What comes in each month?"
        case .costs: "What do you pay regularly?"
        case .saving: "Saving, and every day"
        case .pots: "What's in your pots right now?"
        case .paid: "Already paid in \(draft.month.name)?"
        case .partner: "Anyone you share costs with?"
        }
    }

    private var detail: String {
        switch step {
        case .welcome: "A few questions about your month, and Tally makes your plan from the answers. Every answer can be changed later."
        case .income: "Your pay, or whatever comes in regularly. Leave it empty if nothing does."
        case .costs: "Rent, bills, subscriptions: what goes out every month or once a year. Pick the usual ones or add your own."
        case .saving: "What you put aside when you're paid, and about what everything else costs a day. All of it can stay empty."
        case .pots: "Empty is 0. You can set any of them again later on Pots."
        case .paid: "Tick what's already gone out of the money you typed. What has most likely happened is ticked for you."
        case .partner: "Their name, so a spend can be shared and Tally keeps what they owe you. Leave it empty if not."
        }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            line("calendar", "Your month as a plan: what comes in, what goes out, what you put aside.")
            line("circle.dotted", "What you can spend each day until you're paid next.")
            line("cylinder.split.1x2", "Your money in four pots: Main, Clothes, the emergency fund and the card.")
            line("lock", "Everything stays on this Mac.")
        }
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 20).opacity(0.7)
            Text(text).font(Kit.body).opacity(0.85)
        }
    }

    private var income: some View {
        SettingsCard {
            SettingRow(title: "Name") {
                GlassField(label: "Income name", text: $draft.incomeName, align: .leading, hint: "Salary", secret: false)
                    .frame(width: Kit.field)
            }
            SettingRow(title: "How much", detail: "After tax, as it arrives") {
                money("Income", $draft.incomeAmount)
            }
            SettingRow(title: "When", detail: "The day of the month it comes") {
                GlassPicker(selection: $draft.incomeDay, choices: Self.days)
            }
        }
    }

    private var saving: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            SettingsCard {
                SettingRow(title: "Into the emergency fund", detail: "Each month, when you're paid") { money("Emergency fund", $draft.toEmergency) }
                SettingRow(title: "Into the clothes pot", detail: "Each month, when you're paid") { money("Clothes pot", $draft.toClothes) }
                SettingRow(title: "Emergency fund goal", detail: "Tally says the month you'll reach it") { money("Goal", $draft.goal) }
            }
            SettingsCard {
                SettingRow(title: "Everything else, a day", detail: "Food, coffee, going out: about what a day costs") { money("A day", $draft.daily) }
            }
        }
    }

    private var pots: some View {
        SettingsCard {
            ForEach(Pot.allCases, id: \.self) { pot in
                SettingRow(title: pot == .card ? "Owed on the card" : pot.title) {
                    money(pot.title, Binding { draft.typed[pot, default: ""] } set: { draft.typed[pot] = $0 }, signed: true)
                }
            }
        }
    }

    private var partnerName: some View {
        VStack(alignment: .leading, spacing: Kit.Space.group) {
            SettingsCard {
                SettingRow(title: "Their name") {
                    GlassField(label: "Partner's name", text: $partner, align: .leading, hint: "Name", secret: false)
                        .frame(width: Kit.field)
                }
            }
            Text("Your spending categories (Food, Going out, Clothes, Fragrance, Other) and the partner can be changed in Settings.")
                .font(Kit.quiet).opacity(0.45).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// An amount in a row: the field and €, red while it doesn't read. Empty is always fine; a balance (`signed`) can be 0 or below.
    private func money(_ label: String, _ text: Binding<String>, signed: Bool = false) -> some View {
        let typed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
        let reads = typed.isEmpty || (signed ? Cents.parseSigned(typed) : Cents.parsePositive(typed)) != nil
        return HStack(spacing: 6) {
            GlassField(label: label, text: text, valid: reads).frame(width: Kit.rowAmount)
            Text("€").font(Kit.body).opacity(0.55)
        }
    }

    /// "the 1st" to "the 31st".
    static let days: [(Int, String)] = (1...31).map { ($0, "the \(ordinal($0))") }
}
