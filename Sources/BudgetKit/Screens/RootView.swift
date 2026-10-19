import Combine
import SwiftUI

/// `--screen payday|log|plan|entries`: the sheet a demo opens on.
public enum OpenSheet: String, Sendable { case payday, log, plan, entries }

/// The sheets that rise over the screens, apart from the payday one (which needs an income).
enum Sheet: Hashable { case log, plan, balance(Pot), entries(YearMonth) }

/// The window's content: the three screens side by side, one swipe or arrow key apart,
/// with dots under them saying where you are. Before the first run, the first run instead.
public struct RootView: View {
    let store: Store
    let today: () -> Date
    let first: Screen
    @State private var scroll = ScrollPosition(idType: Screen.self)
    @State private var position: PagerPosition
    /// The one day every screen reads; it changes when the calendar day does, never on a timer.
    @State private var day: Date
    /// The income whose payday sheet is open, over every screen.
    @State private var payday: Due?
    /// The quick log, plan, set-balance or entries sheet, when one is open.
    @State private var sheet: Sheet?
    /// The category Return logs under in the quick log: the one used last.
    @State private var lastCategory = Category.food
    /// "Undo" is on offer for a few seconds after something is recorded.
    @State private var undoShown = false
    @State private var undoHide: Task<Void, Never>?
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `sheet` opens that sheet at once (the payday one for the first income that is due, if one is).
    public init(store: Store, today: @escaping () -> Date, screen: Screen = .today, sheet: OpenSheet? = nil) {
        self.store = store
        self.today = today
        first = screen
        _position = State(initialValue: PagerPosition(Double(screen.rawValue)))
        _day = State(initialValue: today())
        _payday = State(initialValue: sheet == .payday ? store.ledger().stillToPay(today: today()).first(where: \.isIncome) : nil)
        let opened: Sheet? = switch sheet {
        case .log: .log
        case .plan: .plan
        case .entries: .entries(YearMonth(today(), calendar: store.ledger().calendar))
        case .payday, nil: nil
        }
        _sheet = State(initialValue: opened)
    }

    /// A sheet is open: the screens behind it take no keys and no clicks.
    private var modal: Bool { payday != nil || sheet != nil }

    public var body: some View {
        VStack(spacing: 0) {
            if store.isSetUp { pager } else { FirstRunView(store: store, today: today()) }
            if let problem { Text(problem).font(Living.caption).opacity(0.5).padding(.bottom, 10) }
        }
        .frame(width: Glass.contentSize.width, height: Glass.contentSize.height)
        .overlay { sheets }
        .background { shortcuts }
        .background { PagerGlass(setUp: store.isSetUp, position: position) }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onChange(of: store.recordings) { offerUndo() }
        .onKeyPress(.leftArrow) { go(to: position.screen.previous) }
        .onKeyPress(.rightArrow) { go(to: position.screen.next) }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
            day = today()
        }
    }

    private var pager: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    TodayView(store: store, today: day, now: today, onPayday: open)
                        .containerRelativeFrame(.horizontal).id(Screen.today)
                    PotsView(store: store, today: day, onPayday: open, onSetBalance: { show(.balance($0)) }).containerRelativeFrame(.horizontal).id(Screen.pots)
                    MonthView(store: store, today: day, onEntries: { show(.entries($0)) }).containerRelativeFrame(.horizontal).id(Screen.month)
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.paging)
            .scrollPosition($scroll)
            .scrollDisabled(modal)
            .onAppear { scroll.scrollTo(id: first) }
            .onScrollGeometryChange(for: Double.self) { geometry in
                geometry.contentOffset.x / max(1, geometry.containerSize.width)
            } action: { _, now in position.value = now }
            bottomBar
        }
        .overlay(alignment: .bottom) {
            if undoShown && !modal {
                UndoPill(undo: undo).padding(.bottom, 44).transition(.opacity)
            }
        }
        .accessibilityHidden(modal)
    }

    /// The plan on the left, the dots, and the "+" that logs a spend, on every screen.
    private var bottomBar: some View {
        ZStack {
            PageDots(position: position) { go(to: $0) }
            HStack {
                Button("Plan") { show(.plan) }
                    .buttonStyle(.secondary)
                Spacer()
                Button { show(.log) } label: { Image(systemName: "plus").font(.system(size: 12, weight: .semibold)) }
                    .buttonStyle(.secondary)
                    .accessibilityLabel("Log a spend")
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 10)
    }

    /// ⌘N logs a spend, ⌘, opens the plan; hidden buttons, since the window has no menu of its own for them.
    @ViewBuilder private var shortcuts: some View {
        if store.isSetUp {
            Group {
                Button("Log a Spend") { show(.log) }.keyboardShortcut("n")
                Button("Plan") { show(.plan) }.keyboardShortcut(",")
                // Not while a sheet is open: there ⌘Z belongs to the text being typed.
                Button("Undo") { if !modal { undo() } }.keyboardShortcut("z")
            }
            .frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
        }
    }

    /// The screens dimmed behind a sheet, which rises from the bottom; dimmed, they take no clicks.
    @ViewBuilder private var sheets: some View {
        if modal {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black.opacity(0.6))
                .ignoresSafeArea()
                // Clicking the dimmed space above a drawer closes it.
                .onTapGesture { close() }
                .accessibilityHidden(true)
                .transition(.opacity)
            Group {
                if let payday {
                    PaydaySheet(income: payday, split: store.ledger().split(of: payday),
                                add: { record(payday, amount: $0, split: $1) }, cancel: close)
                        .id(payday.id)
                } else if let sheet {
                    content(of: sheet).id(sheet)
                }
            }
            // Flush with the window's bottom edge, with room above to click away.
            .padding(.top, 44)
            // The sheet and everything in it move as one piece, so nothing inside arrives before the drawer.
            .geometryGroup()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private func content(of sheet: Sheet) -> some View {
        switch sheet {
        case .log:
            QuickLogSheet(last: lastCategory, log: log, cancel: close)
        case .plan:
            PlanSheet(store: store, month: YearMonth(today(), calendar: store.ledger().calendar), close: close)
        case .balance(let pot):
            SetBalanceSheet(pot: pot, balance: store.ledger().balance(pot),
                            set: { store.setBalance(pot, to: $0, at: today()); close() }, cancel: close)
        case .entries(let month):
            EntriesSheet(store: store, month: month, close: close)
        }
    }

    private func open(_ income: Due) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.appear) { payday = income }
    }

    /// Only one sheet at a time, and none before the first run is done.
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
        focused = true
    }

    private func log(_ amount: Cents, _ category: Category, _ note: String?, _ onCard: Bool) {
        store.logSpend(amount, category: category, note: note, onCard: onCard, at: today())
        lastCategory = category
        close()
    }

    /// Records it, then shows Pots under the leaving sheet, so the money is seen pouring into the tubes.
    private func record(_ income: Due, amount: Cents, split: [UUID: Cents]) {
        store.payday(income, amount: amount, split: split, at: today())
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { scroll.scrollTo(id: Screen.pots) }
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

    @discardableResult
    private func go(to target: Screen) -> KeyPress.Result {
        guard store.isSetUp, !modal else { return .ignored }
        withAnimation(reduceMotion ? nil : Motion.appear) { scroll.scrollTo(id: target) }
        return .handled
    }
}

/// Where the pager is, in screens: fractions while it moves, so the edge light follows. An object of its own,
/// read only by the light and the dots, so a scroll frame never draws the screens again.
@MainActor @Observable
final class PagerPosition {
    var value: Double

    init(_ value: Double) { self.value = value }

    /// The page the pager is on, or nearest to while it moves.
    var screen: Screen { Screen(rawValue: Int(value.rounded())) ?? .today }
}

/// The glass behind the window, its light following the pager once there are screens to page.
private struct PagerGlass: View {
    let setUp: Bool
    let position: PagerPosition

    var body: some View {
        Glass(light: setUp ? Screen.allCases.map(\.light) : [Screen.today.light], position: setUp ? position.value : 0)
    }
}

/// Three small dots under the screens; the lit one is where you are. A click goes there.
private struct PageDots: View {
    let position: PagerPosition
    let go: (Screen) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = position.screen
        HStack(spacing: 8) {
            ForEach(Screen.allCases, id: \.self) { screen in
                Button { go(screen) } label: {
                    Circle()
                        .fill(.white.opacity(screen == current ? 0.9 : 0.22))
                        .frame(width: 6, height: 6)
                        .padding(3)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .hoverLift()
                .accessibilityLabel(screen.title)
                .accessibilityAddTraits(screen == current ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Motion.change, value: current)
    }
}
