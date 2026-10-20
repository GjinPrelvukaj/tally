import SwiftUI

/// The first run builds the person's own plan, a step a page: a welcome, the income, regular costs, saving and every
/// day, the pots, what is already paid this month, the partner. The steps sit on the left as the sidebar will;
/// a done one can be clicked to go back. Nothing is saved until Start.
struct FirstRunView: View {
    let store: Store
    let today: Date
    /// Keeps the partner's name (the demo's goes nowhere, so it never writes the real app's settings).
    let savePartner: (String) -> Void
    @State private var draft: FirstRunDraft
    @State private var step = FirstRunStep.welcome
    /// What has passed this month is ticked once, on first reaching that step; after that the ticks are the person's.
    @State private var ticked = false
    @State private var partner = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: Store, today: Date, savePartner: @escaping (String) -> Void) {
        self.store = store
        self.today = today
        self.savePartner = savePartner
        _draft = State(initialValue: FirstRunDraft(month: YearMonth(today, calendar: store.ledger().calendar)))
    }

    var body: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    FirstRunPage(step: step, draft: $draft, partner: $partner)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Kit.Space.group)
                }
                .scrollIndicators(.never)
                .id(step)
                .transition(.opacity)
                buttons
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 40)
            .padding(.top, 36)
            .padding(.bottom, Glass.lightRoom)
            .frame(maxWidth: .infinity)
        }
    }

    /// The steps, as the sidebar lists sections: the one shown lit, the done ones ticked.
    private var rail: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Setting up").groupLabel().padding(.leading, 10).padding(.bottom, 6)
            ForEach(FirstRunStep.allCases, id: \.self) { each in
                Button { if each < step { go(each) } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: each < step ? "checkmark.circle.fill" : each.symbol)
                            .foregroundStyle(each < step ? Color.arrived : .white)
                            .frame(width: 18)
                        Text(each.title)
                        Spacer()
                    }
                    .opacity(each > step ? 0.45 : 1)
                }
                .buttonStyle(.sidebarItem(chosen: each == step))
                .disabled(each > step)
                .accessibilityAddTraits(each == step ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 44)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(.white.opacity(0.025))
    }

    private var buttons: some View {
        HStack {
            if let back = FirstRunStep(rawValue: step.rawValue - 1) {
                Button("Back") { go(back) }
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            if let next = FirstRunStep(rawValue: step.rawValue + 1) {
                Button(step == .welcome ? "Begin" : "Next") { go(next) }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!ready)
            } else {
                Button("Start", action: start)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!ready)
            }
        }
        .padding(.top, Kit.Space.group)
    }

    /// Whether everything typed so far reads.
    private var ready: Bool {
        switch step {
        case .welcome: true
        case .income, .costs: draft.plan != nil
        case .saving: draft.plan != nil && draft.goals != nil
        case .pots: draft.balances != nil
        case .paid, .partner: draft.paidAmounts != nil
        }
    }

    private func go(_ to: FirstRunStep) {
        if to == .paid && !ticked {
            draft.tickWhatHasPassed(today: store.ledger().calendar.component(.day, from: today))
            ticked = true
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { step = to }
    }

    private func start() {
        guard let plan = draft.plan, let goals = draft.goals, let balances = draft.balances, let paid = draft.paidAmounts
        else { return }
        savePartner(partner.trimmingCharacters(in: .whitespaces))
        store.setUp(balances: balances, paid: paid, today: today, plan: plan, goals: goals, savings: draft.savingsPots)
    }
}

/// The first run's pages, in order.
enum FirstRunStep: Int, CaseIterable, Comparable {
    case welcome, income, costs, saving, pots, paid, partner

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .income: "Income"
        case .costs: "Regular Costs"
        case .saving: "Saving"
        case .pots: "Your Pots"
        case .paid: "Already Paid"
        case .partner: "Partner"
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "hand.wave"
        case .income: "arrow.down.left"
        case .costs: "arrow.up.right"
        case .saving: "building.columns"
        case .pots: "cylinder.split.1x2"
        case .paid: "checklist"
        case .partner: "person.2"
        }
    }
}
