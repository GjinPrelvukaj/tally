import AppKit
import Combine
import SwiftUI

/// `--screen payday|log`: the drawer a demo opens on.
public enum OpenSheet: String, Sendable { case payday, log }

/// The drawers that rise over the pane, apart from the payday one (which needs an income).
enum Sheet: Hashable { case log, balance(Pot) }

/// The window's content: the sidebar, and the chosen section in the pane beside it.
/// Before the first run, the first run instead.
public struct RootView: View {
    let store: Store
    let today: () -> Date
    @State private var section: Screen
    /// The one day every section reads; it changes when the calendar day does, never on a timer.
    @State private var day: Date
    /// The income whose payday drawer is open.
    @State private var payday: Due?
    /// The quick log or set-balance drawer, when one is open.
    @State private var sheet: Sheet?
    /// The category Return logs under in the quick log: the one used last.
    @State private var lastCategory = Category.food
    /// "Undo" is on offer for a few seconds after something is recorded.
    @State private var undoShown = false
    @State private var undoHide: Task<Void, Never>?
    /// Every amount shown as a soft bar; until clicked again or Tally closes.
    @State private var amountsHidden: Bool
    /// Never in the demo, which must not ask for the real Mac's Touch ID.
    let canLock: Bool
    @AppStorage(Preference.lock) private var lockOn = false
    /// Nothing of the money is drawn until Touch ID says it is you.
    @State private var locked: Bool
    /// `--screen settings` in the demo: the Settings window opens too, for a picture.
    let showsSettings: Bool
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `sheet` opens that drawer at once (the payday one for the first income that is due, if one is).
    /// `hidden` starts with every amount hidden (the setting, or the demo's `--hidden`).
    /// `canLock` is false in the demo; when true, Tally starts locked if the setting is on.
    public init(store: Store, today: @escaping () -> Date, screen: Screen = .today, sheet: OpenSheet? = nil,
                hidden: Bool = false, canLock: Bool = false, showsSettings: Bool = false) {
        self.store = store
        self.today = today
        self.canLock = canLock
        self.showsSettings = showsSettings
        _amountsHidden = State(initialValue: hidden)
        _locked = State(initialValue: canLock && UserDefaults.standard.bool(forKey: Preference.lock))
        _section = State(initialValue: screen)
        _day = State(initialValue: today())
        _payday = State(initialValue: sheet == .payday ? store.ledger().stillToPay(today: today()).first(where: \.isIncome) : nil)
        _sheet = State(initialValue: sheet == .log ? .log : nil)
    }

    /// A drawer is open: the rest of the window takes no clicks.
    private var modal: Bool { payday != nil || sheet != nil }

    public var body: some View {
        Group {
            if locked {
                LockView { withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { locked = false } }
            } else if store.isSetUp {
                HStack(spacing: 0) {
                    Sidebar(store: store, today: day, section: section, go: go, log: { show(.log) })
                        .allowsHitTesting(!modal)
                    Rectangle().fill(.white.opacity(0.06)).frame(width: 1)
                    pane
                }
                .redacted(reason: amountsHidden ? .privacy : [])
                .environment(\.toggleAmounts, toggleAmounts)
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
        .onAppear { if showsSettings { openSettings() } }
        // Locks again when the Mac sleeps or its screen locks, so it is never left open on a Mac someone else wakes.
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in lockAgain() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)) { _ in lockAgain() }
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.screenIsLocked"))) { _ in lockAgain() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            day = today()
        }
    }

    private var pane: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(modal)
            if let problem { Text(problem).font(Living.caption).opacity(0.5).padding(.bottom, 10) }
        }
        .overlay(alignment: .bottom) {
            if undoShown && !modal {
                UndoPill(undo: undo).padding(.bottom, Kit.Space.edge).transition(.opacity)
            }
        }
        .overlay { drawers }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .today: TodayView(store: store, today: day, now: today, onPayday: open, onSetOwed: { show(.balance(.card)) })
        case .pots: PotsView(store: store, today: day, onPayday: open, onSetBalance: { show(.balance($0)) })
        case .month: MonthView(store: store, today: day)
        case .entries: EntriesPane(store: store, today: day)
        case .plan: PlanPane(store: store, month: YearMonth(day, calendar: store.ledger().calendar))
        }
    }

    /// ⌘N logs a spend, ⌘1 to ⌘5 go to a section, ⇧⌘H hides amounts; hidden buttons, as the window has no menu of its own.
    @ViewBuilder private var shortcuts: some View {
        if store.isSetUp {
            Group {
                Button("Log a Spend") { show(.log) }.keyboardShortcut("n")
                ForEach(Screen.allCases, id: \.self) { screen in
                    Button(screen.title) { if !modal { go(screen) } }.keyboardShortcut(KeyEquivalent(screen.key))
                }
                Button("Hide Amounts") { toggleAmounts() }.keyboardShortcut("h", modifiers: [.command, .shift])
                // Not while a drawer is open: there ⌘Z belongs to the text being typed.
                Button("Undo") { if !modal { undo() } }.keyboardShortcut("z")
            }
            .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
    }

    /// The pane dimmed behind a drawer, which rises from its bottom; dimmed, it takes no clicks.
    @ViewBuilder private var drawers: some View {
        if modal {
            UnevenRoundedRectangle(bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(.black.opacity(0.6))
                .ignoresSafeArea()
                // Clicking the dimmed space round a drawer closes it.
                .onTapGesture { close() }
                .accessibilityHidden(true)
                .transition(.opacity)
            Group {
                if let payday {
                    PaydaySheet(income: payday, split: store.ledger().split(of: payday),
                                add: { record(payday, amount: $0, split: $1) }, cancel: close)
                        .id(payday.id)
                } else if let sheet {
                    drawer(sheet).id(sheet)
                }
            }
            // As wide as a phone, not the pane: its rows stay close to their amounts.
            .frame(maxWidth: 440)
            .padding(.top, 44)
            .padding(.bottom, 12)
            // The drawer and everything in it move as one piece, so nothing inside arrives before it.
            .geometryGroup()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private func drawer(_ sheet: Sheet) -> some View {
        switch sheet {
        case .log:
            QuickLogSheet(last: lastCategory, log: log, cancel: close)
        case .balance(let pot):
            SetBalanceSheet(pot: pot, balance: store.ledger().balance(pot),
                            set: { store.setBalance(pot, to: $0, at: today()); close() }, cancel: close)
        }
    }

    private func lockAgain() {
        guard canLock, lockOn else { return }
        payday = nil
        sheet = nil
        locked = true
    }

    private func toggleAmounts() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { amountsHidden.toggle() }
    }

    private func go(_ target: Screen) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change) { section = target }
    }

    private func open(_ income: Due) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { payday = income }
    }

    /// Only one drawer at a time, and none before the first run is done.
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

    private func log(_ amount: Cents, _ category: Category, _ note: String?, _ onCard: Bool) {
        store.logSpend(amount, category: category, note: note, onCard: onCard, at: today())
        lastCategory = category
        close()
    }

    /// Records it, then shows Pots under the leaving drawer, so the money is seen pouring into the tubes.
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
