import AppKit
import Combine
import SwiftUI

/// `--screen payday|log`: the card a demo opens on.
public enum OpenSheet: String, Sendable { case payday, log }

/// The cards that open in the middle of the window, apart from the payday one (which needs an income).
enum Sheet: Hashable { case log, balance(Pot), paidBack, money(Someone) }

/// The window's content: the sidebar, and the chosen section in the pane beside it.
/// Before the first run, the first run instead.
public struct RootView: View {
    let store: Store
    let today: () -> Date
    @State private var section: Screen
    /// The one day every section reads; it changes when the calendar day does, never on a timer.
    @State private var day: Date
    /// The income whose payday card is open.
    @State private var payday: Due?
    /// The quick log, set-balance or paid-back card, when one is open.
    @State private var sheet: Sheet?
    /// The category Return logs under in the quick log: the one used last.
    @State private var lastCategory = Category.food
    /// The partner's name from Settings; the demo has its own (`demoPartner`), so it never shows the real one.
    @AppStorage(Preference.partnerName) private var savedPartner = ""
    let demoPartner: String
    private var partnerName: String { real ? savedPartner : demoPartner }
    /// "Undo" is on offer for a few seconds after something is recorded.
    @State private var undoShown = false
    @State private var undoHide: Task<Void, Never>?
    /// Every amount shown as a soft bar; until clicked again or Tally closes.
    @State private var amountsHidden: Bool
    /// The real app, not the demo: only it locks (the demo must not ask for the Mac's Touch ID) and remembers
    /// whether amounts were hidden (the demo must not write the real app's settings).
    let real: Bool
    @AppStorage(Preference.lock) private var lockOn = false
    /// Nothing of the money is drawn until Touch ID says it is you.
    @State private var locked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// `sheet` opens that card at once (the payday one for the first income that is due, if one is).
    /// `hidden` starts with every amount hidden (the setting, or the demo's `--hidden`).
    /// `real` is false in the demo; when true, Tally starts locked if the setting is on.
    public init(store: Store, today: @escaping () -> Date, screen: Screen = .today, sheet: OpenSheet? = nil,
                hidden: Bool = false, real: Bool = false, demoPartner: String = "") {
        self.store = store
        self.demoPartner = demoPartner
        self.today = today
        self.real = real
        _amountsHidden = State(initialValue: hidden)
        _locked = State(initialValue: real && UserDefaults.standard.bool(forKey: Preference.lock))
        _section = State(initialValue: screen)
        _day = State(initialValue: today())
        _payday = State(initialValue: sheet == .payday ? store.ledger().stillToPay(today: today()).first(where: \.isIncome) : nil)
        _sheet = State(initialValue: sheet == .log ? .log : nil)
    }

    /// A card is open: the rest of the window is blurred and takes no clicks.
    private var modal: Bool { payday != nil || sheet != nil }

    public var body: some View {
        Group {
            if locked {
                LockView { withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { locked = false } }
            } else if store.isSetUp {
                ZStack {
                    HStack(spacing: 0) {
                        Sidebar(store: store, today: day, section: section, go: go, log: { show(.log) })
                        Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
                        pane
                    }
                    // Under Reduce Transparency a darker dim instead of the blur.
                    .blur(radius: modal && !reduceTransparency ? 14 : 0)
                    .allowsHitTesting(!modal)
                    .accessibilityHidden(modal)
                    modals
                }
                .environment(\.amountsHidden, amountsHidden)
                .environment(\.toggleAmounts, toggleAmounts)
                .environment(\.partnerName, partnerName)
            } else {
                FirstRunView(store: store, today: today()).frame(width: 380, height: 520)
            }
        }
        // Opens at the standard size; never smaller than the minimum.
        .frame(minWidth: WindowSize.minimum.width, idealWidth: WindowSize.standard.width, maxWidth: .infinity,
               minHeight: WindowSize.minimum.height, idealHeight: WindowSize.standard.height, maxHeight: .infinity)
        .background { if !locked { shortcuts } }
        .background {
            Glass(light: store.isSetUp ? Screen.allCases.map(\.light) : [Screen.today.light],
                  position: store.isSetUp ? Double(section.rawValue) : 0)
        }
        .onChange(of: store.recordings) { offerUndo() }
        // Locks again when the Mac sleeps or its screen locks, so it is never left open on a Mac someone else wakes.
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in lockAgain() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)) { _ in lockAgain() }
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsLocked"))) { _ in lockAgain() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            day = today()
        }
    }

    /// Every section, and what shows over it, ends above the light along the bottom edge (`Glass.lightRoom`):
    /// nothing touches it; a list scrolls within.
    private var pane: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            if let problem { Text(problem).font(Living.caption).opacity(0.5).padding(.top, 6) }
        }
        .padding(.bottom, Glass.lightRoom)
        .overlay(alignment: .bottom) {
            if undoShown && !modal {
                UndoPill(undo: undo).padding(.bottom, Glass.lightRoom).transition(.opacity)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .today: TodayView(store: store, today: day, now: today, onPayday: open, onSetOwed: { show(.balance(.card)) },
                               onPaidBack: { show(.paidBack) })
        case .pots: PotsView(store: store, today: day, onPayday: open, onSetBalance: { show(.balance($0)) })
        case .month: MonthView(store: store, today: day)
        case .insights: InsightsView(store: store, today: day)
        case .settings: SettingsView(store: store)
        case .people: PeopleView(store: store) { show(.money($0)) }
        case .entries: EntriesPane(store: store, today: day)
        case .plan: PlanPane(store: store, month: YearMonth(day, calendar: store.ledger().calendar))
        }
    }

    /// ⌘N logs a spend, ⌘1 to ⌘6 go to a section, ⌘, to Settings, ⇧⌘H hides amounts; hidden buttons, as the window has no menu of its own.
    @ViewBuilder private var shortcuts: some View {
        if store.isSetUp {
            Group {
                Button("Log a Spend") { show(.log) }.keyboardShortcut("n")
                ForEach(Screen.allCases, id: \.self) { screen in
                    Button(screen.title) { if !modal { go(screen) } }.keyboardShortcut(KeyEquivalent(screen.key))
                }
                Button("Hide Amounts") { toggleAmounts() }.keyboardShortcut("h", modifiers: [.command, .shift])
                // Not while a card is open: there ⌘Z belongs to the text being typed.
                Button("Undo") { if !modal { undo() } }.keyboardShortcut("z")
            }
            .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
    }

    /// The window blurred and dimmed behind a card in its middle.
    @ViewBuilder private var modals: some View {
        if modal {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(reduceTransparency ? 0.7 : 0.35))
                .ignoresSafeArea()
                // Clicking anywhere round the card closes it.
                .onTapGesture { close() }
                .accessibilityHidden(true)
                .transition(.opacity)
            Group {
                if let payday {
                    PaydaySheet(income: payday, split: store.ledger().split(of: payday),
                                add: { record(payday, amount: $0, split: $1) }, cancel: close)
                        .id(payday.id)
                } else if let sheet {
                    card(sheet).id(sheet)
                }
            }
            // As wide as a phone, not the window: its rows stay close to their amounts.
            .frame(maxWidth: 440)
            // Clear of the window's light at the bottom, like everything else.
            .padding(.vertical, Glass.lightRoom)
            // The card and everything in it move as one piece, so nothing inside arrives before it.
            .geometryGroup()
            .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }
    }

    @ViewBuilder private func card(_ sheet: Sheet) -> some View {
        switch sheet {
        case .log:
            let ledger = store.ledger()
            let offered = ledger.categories.filter { !$0.retired }
            // The one used last, unless it has since been retired.
            QuickLogSheet(categories: offered, last: offered.first { $0.id == lastCategory.id } ?? offered.first ?? .other,
                          log: log, cancel: close)
        case .balance(let pot):
            SetBalanceSheet(pot: pot, balance: store.ledger().balance(pot),
                            set: { store.setBalance(pot, to: $0, at: today()); close() }, cancel: close)
        case .money(let who):
            let ledger = store.ledger()
            MoneyWithSheet(who: who, people: ledger.people, ledger: ledger, partnerName: partnerName,
                           save: { kind, amount, person, before in
                               store.record(kind, amount, with: person, before: before, at: today()); close()
                           }, cancel: close)
        case .paidBack:
            PaidBackSheet(name: partnerName, owes: store.ledger().partnerOwes,
                          add: { store.record(.repayment, $0, with: nil, at: today()); close() }, cancel: close)
        }
    }

    private func lockAgain() {
        guard real, lockOn else { return }
        payday = nil
        sheet = nil
        locked = true
    }

    private func toggleAmounts() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { amountsHidden.toggle() }
        // Kept for "As I Left Them": the next launch starts the way this one was left.
        if real { UserDefaults.standard.set(amountsHidden, forKey: Preference.amountsHidden) }
    }

    private func go(_ target: Screen) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { section = target }
    }

    private func open(_ income: Due) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { payday = income }
    }

    /// Only one card at a time, and none before the first run is done.
    private func show(_ next: Sheet) {
        guard store.isSetUp, !modal else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { sheet = next }
    }

    /// Shows the pill and hides it after a few seconds, or when the next action comes first.
    private func offerUndo() {
        undoHide?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { undoShown = true }
        undoHide = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { undoShown = false }
        }
    }

    private func undo() {
        guard store.canUndo else { return }
        store.undo()
        undoHide?.cancel()
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { undoShown = false }
    }

    private func close() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.leave) { payday = nil; sheet = nil }
    }

    private func log(_ spend: LoggedSpend) {
        store.logSpend(spend.amount, category: spend.category, note: spend.note, paidWith: spend.method, at: today(),
                       partner: spend.partner, paysBack: spend.paysBack)
        lastCategory = spend.category
        close()
    }

    /// Records it, then shows Pots under the leaving card, so the money is seen pouring into the tubes.
    private func record(_ income: Due, amount: Cents, split: [UUID: Cents]) {
        store.payday(income, amount: amount, split: split, at: today())
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { section = .pots }
        close()
    }

    /// A read that failed or a save that didn't land, said once, quietly. The ledger is read first
    /// because a failed read is only known once something has read.
    private var problem: String? {
        _ = store.ledger()
        if store.loadError != nil { return "Tally couldn't read your data just now" }
        if store.saveError != nil { return "Tally couldn't save the last change" }
        return nil
    }
}
