# Tally — context

Read this first, then [AGENTS.md](AGENTS.md) for how to work here.

## What it is

A small native macOS app for one person's monthly money: a monthly plan, what actually happened, and a daily
allowance, in one glass window with three screens (Today, Pots, Month). Swift 6, SwiftUI, SwiftData, macOS 26 or
later, no network, no third-party packages. Its look (black glass, colour as light from the bottom edge, springs,
nothing moves unless something happens) comes from the author's app Brimlight.

**Names.** The app is **Tally**. Inside it is still **Budget**: the Swift package and targets (`Budget`,
`BudgetKit`), the bundle id `app.gjin.budget` and the data file `~/Library/Application Support/Budget/Budget.store`.
Keep the data path: renaming it would make the app open empty on a Mac that already has data.

## What exists

Everything below is built: the money logic (balances, "still to pay" with carry-over, next income, the daily
allowance, the emergency fund's goal month, the month line), the SwiftData store, a starter plan for the first run,
the three screens, and the drawers: Quick log, the Plan with its item editor, a payday, Set Balance, the first run,
a month's entries with their editor.
Undo takes back the last recorded action. A style kit (`Design/Kit.swift`) holds every size, button and switch.

**Not done yet:** typing a negative balance (an overdrawn account, a card in credit); remembering Quick log's last category across launches; categories and pots of
your own (they are fixed: Main, Clothes, Emergency fund, Card).

**Not checked by hand yet** (keys and clicks don't reach a demo started from a script): swiping the pager, clicking
rows, the payday pour, ⌘N / ⌘, / ⌘Z, right-click Set Balance, the plan editor, the entry editor, dragging a drawer down, month paging.

## Where things live

```
Sources/Budget/BudgetApp.swift        the @main App: one window (`Window`, hidden title bar, 380 × 560; closing it quits), opens `Store()` or the demo, `--screen` (`payday`, `log`, `plan`, `entries`: Today with that sheet open; `firstrun`: a demo not yet set up)
Sources/BudgetKit/Money/Cents.swift   money in whole cents: formatting (`formatted`, `wholeEuros` "2 000", `editable` "2 450,17" for a field), parsing, floor division
Sources/BudgetKit/Money/Calendar+Month.swift  YearMonth: a month as two numbers (next, previous, days, clamped date, `name` "October", `shortName` "Mar 2027")
Sources/BudgetKit/Money/Model.swift   Pot, Category, Schedule, PlanItem, Entry (plain values, no logic beyond `applies(in:)`)
Sources/BudgetKit/Money/Ledger.swift  Ledger: start balances + plan + entries; `balance(_:)`, `balance(_:endOf:)`, `total` (every pot, the card's debt taken off), `entries(in:)` (a month's money-moving entries, newest first)
Sources/BudgetKit/Money/Ledger+Due.swift  `Due`, `isDone`, `stillToPay(today:)`: done / still to pay, with unpaid items carried over; `split(of:)`: an income's undone items; `upcomingIncomes(today:)`: this month's incomes not yet due
Sources/BudgetKit/Money/Ledger+Forecast.swift  `nextIncome`, `allowance`, `goalMonth`, `paydays`: what can be spent a day, when the emergency fund is full, which days are paydays
Sources/BudgetKit/Money/Ledger+MonthLine.swift  `monthLine`: Main at the end of each day from the first-run day, past from entries, the rest projected from the plan
Sources/BudgetKit/Money/Ledger+MonthNumbers.swift  for Month: the line's `lowest` point, `saved(in:)`, `linePaydays` (arrived and expected incomes on the line), `ordinal` ("19th")
Sources/BudgetKit/Money/PlanGroup.swift  the plan's four headings (Comes in / Goes to savings / Goes out / Every day) and `PlanItem.group`; paying off the card counts as going out
Sources/BudgetKit/Money/Tubes.swift   the sums behind Pots' tubes: `held` (the card as what's owed), the shared `scale` (largest held amount or goal), `level`
Sources/BudgetKit/Money/Payday.swift  `Payday.leftInMain`: the income less everything paid out of it
Sources/BudgetKit/Store/Records.swift  SwiftData records (plan item, entry, settings) with their conversion to and from the plain values
Sources/BudgetKit/Store/Store.swift   `Store`: opens the database, `ledger()` snapshot, `revision`, and every action the screens call
Sources/BudgetKit/Store/Seed.swift    `Seed.plan`: the starter plan the first run seeds (fixed ids in `Seed.ID`), `Seed.goals`
Sources/BudgetKit/Store/Demo.swift    `Store.demo(afterPayday:paydayDue:setUp:calendar:)`: a made-up 19 October on the starter plan, in memory; `paydayDue` / `afterPayday` move to 1 November with the salary due / added
Sources/BudgetKit/Design/Kit.swift     the app's own sizes, one spacing scale (Kit.Space), buttons (.primary/.secondary/.quiet), chips, glass switch, eyebrow/group labels
Sources/BudgetKit/Screens/SheetCard.swift  sheet glass (sheetCard), GlassField, AmountField (label + field + €), SheetFooter (Cancel + action)
Sources/BudgetKit/Screens/Drawer.swift     every sheet is a drawer (.drawer(close:)): flush with the bottom edge, a handle, dragged down (>90 pt or a flick) or a click on the dim above closes it; Plan's item editor stacks on Plan, which sinks back (0.94, darker)
Scripts/make-icon.swift / make-icon.sh  draw the app icon (ring of days on black glass) into Resources/AppIcon.icns, which is committed
Sources/BudgetKit/Design/Living.swift  copied from Brimlight: Living, Motion, EdgeLight, GlowMeter, DayLine, LiquidDayLine, DotRing, PillButtonStyle, HoverLift, RollingDigits
Sources/BudgetKit/Design/Spring.swift  copied from Brimlight: the damped spring
Sources/BudgetKit/Screens/Screen.swift  `Screen` (today, pots, month), titles, each screen's edge-light colours, each pot's colour (`Pot.light`, and the two named colours `Color.arrived` green / `Color.ahead` cyan)
Sources/BudgetKit/Screens/Glass.swift  the black glass behind the window: corners 22, hairline, the edge light crossfading with the pager
Sources/BudgetKit/Screens/RootView.swift  the pager (paging ScrollView, arrow keys, page dots), the quiet error line, the "Plan" and "+" buttons beside the dots (⌘, and ⌘N too); `FirstRunView` before set-up.
                                      The scroll position lives in `PagerPosition`, read only by the light and the dots, so scrolling never redraws
                                      the screens; the screens read one `day`, refreshed on `NSCalendarDayChanged` (no timer)
Sources/BudgetKit/Screens/TodayView.swift  Today: the ring with "YOU CAN SPEND", the amount a day ("a day until the 2 000", "2 000 is late", red below 0)
Sources/BudgetKit/Screens/TodayRing.swift  the month's days as dots: gone lit, paydays larger (green once come, cyan ahead), today white and largest
Sources/BudgetKit/Screens/StillToPayList.swift  "Still to pay": click = paid at the planned amount, ⌥-click or Edit = change it first (above 0),
                                      right-click = Not This Month; "2 000 arrived?" opens the payday sheet; incomes not due yet are listed dimmed at the end ("650 · from the 15th") and open it too; carried-over rows say "· from October"
Sources/BudgetKit/Screens/PotsView.swift  Pots: "OCTOBER", the total, a tube per pot on one shared scale (the largest goal or amount), the balance above
                                      each, the card as what's owed ("Paid off" at 0), the goal month under Emergency; "2 000 arrived?" while an income is due
Sources/BudgetKit/Screens/PotTube.swift  one tube: glass, a fill of light with a glowing surface, the goal line; a new level pours on `Motion.fill`
                                      (under Reduce Motion it cross-fades in place)
Sources/BudgetKit/Screens/PaydayDraft.swift  the payday sheet's typed amounts; `canAdd` (income above 0, every split amount money)
Sources/BudgetKit/Screens/UndoPill.swift  the "Undo" pill RootView shows after each recording action
Sources/BudgetKit/Screens/UnreadableView.swift  "Couldn't read your data", in place of a screen when `Store.loadError` is set
Sources/BudgetKit/Screens/PaydaySheet.swift  the payday sheet (`PaydayDraft` holds the typed amounts): the income, its split, "Left in Main", Add to Main / Cancel.
                                      RootView shows it over the dimmed screens; Add to Main records it and shows Pots under the leaving sheet, so the pour is seen
Sources/BudgetKit/Screens/MonthView.swift  Month: "MAIN ACCOUNT", "‹ October 2026 ›", one page per month from the start month to this one
                                      (a vertical paging ScrollView, oldest at the top: scrolling up goes back; ⌘← / ⌘→ while Month shows);
                                      each page the lowest point ("lowest point · the 19th" / "today"), the line, and left at end of month,
                                      saved ("Saved this month" on the current month, "Saved" on past ones), and on the current month only the emergency fund's goal month; last, "Entries" with their count opens that month's list
Sources/BudgetKit/Screens/MonthLine.swift  the line in a `Canvas`: the month's days as faint dots along zero, solid and lit where it happened,
                                      dashed where projected, paydays as labelled dots, today the brightest, the lowest point ringed; hover reads a day out
Sources/BudgetKit/Screens/SheetCard.swift  the glass card every sheet sits on (`sheetCard`) and `GlassField`, the capsule text field (red while invalid)
Sources/BudgetKit/Screens/QuickLogSheet.swift  Quick log: amount, "Paid with" Bank Card / Credit Card (`PaidWith`), note, then five category chips
                                      (`CategoryChips`; a tap logs and closes, so everything else comes above them); Return logs under the category used last
Sources/BudgetKit/Screens/EntriesSheet.swift  a month's entries (the "Entries" row on Month), newest first; a row opens `EntryEditor`, stacked like Plan's
Sources/BudgetKit/Screens/EntryEditor.swift  one entry: a spend's amount, how it was paid, note and category; a payment's or income's amount; Delete
                                      (a paid plan item is due again); a balance set by hand can only be deleted. `EntryDraft.swift` holds its typed values
Sources/BudgetKit/Screens/PlanSheet.swift  the plan under "Comes in / Goes to savings / Goes out / Every day" (`PlanGroup`); a row opens `PlanItemEditor`
                                      (`PlanItemDraft` holds the typed values); Delete keeps the item's past payments
Sources/BudgetKit/Screens/PlanItemEditor.swift  the editor for one plan item (opened from the Plan); `PlanItemDraft.swift` holds its typed values
Sources/BudgetKit/Screens/SetBalanceSheet.swift  right-click a tube on Pots, "Set Balance…": the card asks what is owed; the difference is an adjustment
Sources/BudgetKit/Screens/FirstRunView.swift  one question per pot ("What's in Main right now?", the card "How much do you owe on the card?"), then this month's
                                      items to tick as already paid (nothing pre-ticked)
Sources/BudgetKit/Screens/OpenErrorView.swift  "Budget couldn't open your data", the file's path and Quit, when `Store()` throws
Tests/BudgetKitTests/                 swift-testing suites; `Example.swift` is the example month most tests are built on (two incomes, savings, a one-off card payment, part paid by the 19th) and `setUpExample`
```

Layout: `Money/` (value types and all money logic), `Store/` (SwiftData, the only place that
persists; the file is `~/Library/Application Support/Budget/Budget.store`), `Design/` (copies from Brimlight's own `Sources/`, marked "Budget:" where changed), `Screens/` (all drawing of screens).

## How the money works

- **Money is whole cents (`Int`), never `Double`.** Shown as `2 450,17 €`: groups of three split by
  U+00A0, comma decimals, U+00A0 then `€`; negative as `−45,00 €` (U+2212). Formatting is by hand, not
  `NumberFormatter`, so it never follows the system locale.
- `Cents.parse` takes `12,5`, `12.50`, ` 12 `, `2 400` and refuses letters, empty text and more than two
  decimals (a typo must never be saved as 0).
- `Cents.dividedFloor(by:)` rounds down (also for negatives), so the daily allowance is never more than the
  money allows. The caller makes sure the days are above 0.
- Pot balance = starting balance + entries in − entries out, counting only entries that move money (`Ledger.balance`).
- A plan item is **done** for a month when any entry points to it for that month, whatever the amount
  (`dismissed` counts). `Ledger.stillToPay(today:)` lists every undone item from the start month through
  this month, oldest month first, incomes first within a month, then plan order; unpaid items carry over
  to the next month. An income shows once its day (or the start of its window) has come; before that `Ledger.upcomingIncomes(today:)` lists it (shown dimmed, "650 · from the 15th", and it opens the same payday sheet, so an early income can be recorded). `Due.heldBack`
  marks what takes money out of Main and is ready to go: an item planned "with" an income waits only while that income applies this month and has not arrived; with the income paused, limited to another month or gone it is held back at once.
- **Next income** (`Ledger.nextIncome`): the earliest undone income of this month (`.day(d)` is d, a window is
  its last day). If that day has passed it is `late` and counted as today; with none left, next month's first.
- **Daily allowance** (`Ledger.allowance`) = (Main − every held-back due paid from Main, carried-over months
  included) divided down (floor) over `max(1, days from today to the income)`. It can be negative and is never hidden.
- **Goal month** (`Ledger.goalMonth`): balance plus this month's undone planned transfers into the pot; if that
  reaches the goal it is this month, else each later month's planned transfers are added, up to 120 months, else nil.
- **Month line** (`Ledger.monthLine`): it starts on the first-run day (the earliest entry's day, or the start month's 1st
  with no entries), so it never makes up a balance from before the first run; months before the start month are empty. Past months come from entries, today's month is entries up to yesterday,
  today's real balance, then a projection (every held-back due the allowance counts out of Main, on its day if it is dated and still ahead this month, else on the first projected day, the
  daily-life amount out every day, an undone income in on its day or on the first projected day if it is late,
  with its undone split out of Main). Later months are empty. See "How the numbers work" in the design.
- **Month's numbers:** the lowest point is the line's lowest balance, on the first day it is reached; "Saved this month" is the
  transfers that moved money into Clothes or the Emergency fund, dated in that month (corrections don't count); the line's paydays are
  the incomes that arrived into Main that month, and in this month the undone ones on the day the line expects them.

## How it is saved

- `Store` is the only thing the screens talk to: they read `ledger()` (a plain snapshot, cached until the next action)
  and call actions. Every action saves and bumps `revision`; a failed save sets `saveError` (cleared by the next good save).
  A failed read sets `loadError`: `ledger()` is then empty and not cached, actions that need the plan refuse to write,
  and opening the file throws, so a store that cannot be read never looks like a fresh one.
- `markPaid`, `dismiss` and `payday` do nothing when the item is already done for that month (or the ledger can't be read),
  so a double-click never records twice.
- Deleting an income, or changing its kind away from income, turns the items planned "with" it into "any day" (`Store.delete` / `save`), so nothing waits for an income that is gone; the editor says how many first. The card is typed as what you owes and kept as a debt (`Pot.figure(for:)` / `balance(fromFigure:)`).
- **Entries are added; only the last action can be undone**, and any entry can be changed or deleted from the month's list
  (`Store.update`, `Store.deleteEntry`; a deleted one also clears Undo when it was part of the last action). `Store.undo()` deletes the entries the last recording action wrote (by id, one level; `undoable`, `canUndo`; `recordings` goes up with each action so the screen can offer it). RootView shows an "Undo" pill for 6 s after each action (one delayed hide, nothing runs while idle) and ⌘Z does the same. `setBalance` writes the difference as an `adjustment`; `dismiss` writes a
  `dismissed` entry that moves no money; deleting a plan item leaves its entries, so balances never change.
- `setUp` (first run) takes the typed balances plus `paid`, the plan items already paid this month: they are
  recorded as done without moving money. Emergency goal from `Seed.goals` (6 000,00 for the starter plan). It does nothing a second time.
- A spend comes out of its category's pot, or the card when `onCard` (the debt grows).
- `payday` records the income to its pot and one entry per chosen split item, all for the income's month; a split item
  already done that month (paid early or dismissed) is left out, and so is one typed as 0 (it stays due). A 0 is never recorded as a payment, spend or income (`Cents.parsePositive`; use "Not This Month" for nothing).
- The container is kept in `Store.container` and opened with `cloudKitDatabase: .none`, so nothing can sync.
- Before any model change add a `VersionedSchema` and back up `Budget.store`, `-wal` and `-shm`.
- `Store(inMemory: true)` is for tests and the demo; the app opens `Store()` (throws if the file cannot be opened). If it
  throws, the window shows `OpenErrorView` and nothing else: it never falls back to a fresh or in-memory store.
  `saveError` shows as one quiet line at the bottom of the window; while the ledger can't be read, Today, Pots and Month show "Couldn't read your data" (`UnreadableView`) instead of zero figures, and the quiet line says so too.

## Rules

- Nothing moves unless something happens: no timers or animations while idle, idle CPU about 0%.
  Springs only; honour Reduce Motion and Reduce Transparency.
- Plain words in the UI; sentence case for descriptions, Title Case for buttons and titles.
- Every spend keeps its exact time, amount and category; nothing is deleted when months roll over.
- Data stays on the Mac, in the app's Application Support folder.
- Code that reads easily: one job per file and type, short files (split a view past ~200 lines), plain names,
  money logic only in `Money/`, persistence only in `Store/`, drawing only in `Screens/` and `Design/`.
