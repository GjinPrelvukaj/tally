# Tally — context

Read this first, then [AGENTS.md](AGENTS.md) for how to work here.

## What it is

A small native macOS app for one person's monthly money: a monthly plan, what actually happened, and a daily
allowance, in one glass window: a sidebar of seven sections (Today, Pots, Month, Insights, Entries, Plan, People) and Settings, and the chosen one beside it. Swift 6, SwiftUI, SwiftData, macOS 26 or
later, no network, no third-party packages. Its look (black glass, colour as light from the bottom edge, springs,
nothing moves unless something happens) comes from the author's app Brimlight.

**Names.** The app is **Tally**. Inside it is still **Budget**: the Swift package and targets (`Budget`,
`BudgetKit`), the bundle id `app.gjin.budget` and the data file `~/Library/Application Support/Budget/Budget.store`.
Keep the data path: renaming it would make the app open empty on a Mac that already has data.

## What exists

Everything below is built: the money logic (balances, "still to pay" with carry-over, next income, the daily
allowance, each savings pot's goal month, the month line), the SwiftData store, a first run that builds the person's own plan,
the sidebar and its seven sections and Settings, People (money lent, borrowed or owed from before), Insights (exact, tested rules) with Ask Tally, the Plan's and the entries' editors in a panel on the right, and the cards in the
middle: Quick log, a payday, Set Balance, Paid Back; the first run. See `docs/mac-layout.md` for the layout as agreed.
Undo takes back the last recorded action. A style kit (`Design/Kit.swift`) holds every size, button and switch.
Privacy: every amount can be hidden at once, and Tally can lock behind Touch ID (Settings, ⌘,).

**Not done yet:** nothing on the list. Pots are the person's own: Main and the card always, savings pots added, named, given a goal
and retired in Settings → Pots (data from before has Clothes and the Emergency fund).

**Not checked by hand yet** (keys and clicks don't reach a demo started from a script): clicking the sidebar,
rows, the payday pour, ⌘N / ⌘1–⌘7 / ⌘, / ⌘Z / ⇧⌘H, right-click Set Balance, recording money with someone, the plan and entry editors (their pop-ups), typing a question into Ask Tally, pulling a card down,
month paging, resizing the window and it keeping its size, clicking a big number or the eye to hide amounts, the Touch ID lock
(the demo never locks) and turning it on in Settings, two-finger swipes closing a card (down) or an editor panel (right),
clicking into a hidden amount field to show it, opening the menu bar panel and logging from it, typing into the first run by keyboard (it was stepped through by Accessibility).

## Where things live

```
Sources/Budget/BudgetApp.swift        the @main App: one window (`Window`, hidden title bar, resizable from `WindowSize.minimum` 880 × 560, opens at `WindowSize.standard` 940 × 620 and keeps the size it is left at; closing it quits), opens `Store()` or the demo, `--screen` (`today|pots|month|insights|entries|plan|people|settings`: that section; `payday`, `log`: Today with that card open; `firstrun`: a demo not yet set up)
Sources/BudgetKit/Money/Cents.swift   money in whole cents: formatting (`formatted`, `wholeEuros` "2 000", `editable` "2 450,17" for a field), parsing, floor division
Sources/BudgetKit/Money/Calendar+Month.swift  YearMonth: a month as two numbers (next, previous, days, clamped date, `name` "October", `shortName` "Mar 2027", `monthsSince`)
Sources/BudgetKit/Money/Model.swift   `Pot` (its id alone, as entries, the plan and balances keep it: `.main`, `.card`, and the savings pots, `.clothes` /
                                      `.emergency` from before), `SavingsPot` (name, colour, retired; `original`, `nextColour`), Schedule, PlanItem, Entry (plain values, no logic beyond `applies(in:)` and `perMonth`); a plan item comes every
                                      `repeatEvery` months (1 every month, 12 every year) from `startsIn` (nil: always), or once (`onlyIn`); a spend names its category by key;
                                      `PaymentMethod` (bank, card, cash: the credit card adds to its debt, the others come out of the category's pot)
Sources/BudgetKit/Money/Category.swift  `Category`: key, name, pot, retired; the five `starters` keep the keys they always had (`food`…)
Sources/BudgetKit/Money/Insight.swift  `Insight` (kind, level: warning / notice / good, title, detail), `Ledger.insights(today:partnerName:)` warnings first,
                                      `Insight.headline` (the "In short" line, made from their titles)
Sources/BudgetKit/Money/Insights+Spending.swift  running short before the next income (or on track), the last 7 days' pace against the allowance,
                                      habits (a note, or a category of your own, 4+ times in 30 days, with a year's cost), each category against
                                      the same days of last month (moved by 10 € and a quarter)
Sources/BudgetKit/Money/Insights+Plan.swift  a noted spend in each of the last 3 months that no plan item is named for, a plan item skipped two
                                      months running, the card owing more at each month's end, the partner (owes, together this month)
Sources/BudgetKit/Money/Ask.swift  `Question` (topic, period, category, search, with the partner), `Question.checked(against:categories:partnerName:)` (a
                                      category or word kept only if said, cues decide the topic, time words win), `Ledger.answer` (an `Answer`: title, lines,
                                      how it was understood), periods: today, this week from Monday, last week, this month, last month
Sources/BudgetKit/Money/Partner.swift  `PartnerShare` (with, half, forThem; `theirs(of:)`, half rounding down); `Ledger.owes(_ person:)` (what they owe you,
                                      negative: you owe them; nil is the partner, whose owed spend parts count), `partnerOwes`, `people` (partner first, then by
                                      name, one person whatever the case), `EntryKind.isWithSomeone` (lent, borrowed, repayment, paidBack)
Sources/BudgetKit/Money/Ledger.swift  Ledger: start balances + plan + entries; `balance(_:)`, `balance(_:endOf:)`, `savings`, `goals`, `pots` (Main, the savings pots not retired, the card), `spendingPots`, `name(_:)`, `colour(_:)`, `potCount` ("four pots"),
                                      `canRetire(_:)` (empty, nothing in the plan), `total` (every pot, the card's debt taken off), `entries(in:)` (a month's money-moving entries and money owed from before, newest first), `categories`, `category(_:)` (by key; an unknown key reads "Other")
Sources/BudgetKit/Money/Ledger+Due.swift  `Due`, `isDone`, `stillToPay(today:)`: done / still to pay, with unpaid items carried over; `split(of:)`: an income's undone items; `upcomingIncomes(today:)`: this month's incomes not yet due; `asked(_:)`: paying off the card asks for what is owed
Sources/BudgetKit/Money/Ledger+Forecast.swift  `nextIncome`, `allowance`, `goalMonth`, `paydays`: what can be spent a day, when the emergency fund is full, which days are paydays
Sources/BudgetKit/Money/Ledger+MonthLine.swift  `monthLine`: Main at the end of each day from the first-run day, past from entries, the rest projected from the plan
Sources/BudgetKit/Money/Ledger+MonthNumbers.swift  for Month: the line's `lowest` point, `saved(in:)`, `linePaydays` (arrived and expected incomes on the line), `ordinal` ("19th")
Sources/BudgetKit/Money/PlanSummary.swift  `Ledger.planSummary(for:)`: what the plan comes to in a month (comes in, to savings, goes out, every day ×
                                      its days, left over), counting only what is due that month
Sources/BudgetKit/Money/PlanGroup.swift  the plan's four headings (Comes in / Goes to savings / Goes out / Every day) and `PlanItem.group`; paying off the card counts as going out
Sources/BudgetKit/Money/Tubes.swift   the sums behind Pots' tubes: `held` (the card as what's owed), the shared `scale` (largest held amount or goal), `level`
Sources/BudgetKit/Money/Payday.swift  `Payday.leftInMain`: the income less everything paid out of it
Sources/BudgetKit/Store/Records.swift  SwiftData records (plan item, entry, settings, category) with their conversion to and from the plain values
Sources/BudgetKit/Store/Schema.swift  `SchemaV1` (frozen copies of the records before versions), `SchemaV2` (+ `CategoryRecord`, `EntryRecord.partner`, `owed`, `method`;
                                      frozen copies), `SchemaV3` (+ `EntryRecord.person`; frozen), `SchemaV4` (+ `PlanItemRecord.repeatEvery`, `startsInYear`,
                                      `startsInMonth`), `SchemaV5` (+ `SettingsRecord.pots`, the savings pots as JSON, nil: Clothes and the Emergency fund),
                                      `TallyMigration` (lightweight V1 → V2 → V3 → V4 → V5); the container opens through it
Sources/BudgetKit/Store/Store.swift   `Store`: opens the database (seeds the five categories into a store without any), `ledger()` snapshot, `revision`, and every action the screens call;
Sources/BudgetKit/Store/Store.swift (people)  `record(_ kind:_:with:pot:before:at:)`: lent / paid back go out of Main, repayment / borrowed come in;
                                      `before` (owed from before Tally) moves no money
Sources/BudgetKit/Store/Store+Pots.swift  `addPot(_:)`, `rename(_:to:)`, `setGoal(_:for:)`, `retire(_:)` (only when `canRetire`; its categories then spend
                                      from Main), `bringBack(_:)`; `setUp(…savings:)` keeps the first run's pots, and a starting category in a pot not chosen spends from Main
Sources/BudgetKit/Store/Store+Categories.swift  `addCategory(_:pot:)`, `update(_ category:)` (name, pot for spends from now on, retired)
Sources/BudgetKit/Store/Preferences.swift  `Preference`: the keys kept in the app's preferences (the lock, how amounts start, whether they were last hidden);
                                      `AmountsOnOpen` (Shown, Hidden, As I Left Them, the default; the old "always hidden" switch reads as Hidden)
Sources/BudgetKit/Store/Seed.swift    `Seed.plan`: the starter plan the demo and tests use (fixed ids in `Seed.ID`), `Seed.goals`; `firstRunItems`, `paidEntries`
Sources/BudgetKit/Store/Demo.swift    `Store.demo(afterPayday:paydayDue:setUp:calendar:)`: a made-up 19 October on the starter plan, in memory; `paydayDue` / `afterPayday` move to 1 November with the salary due / added
Sources/BudgetKit/Design/Kit.swift     the app's own sizes, one spacing scale (Kit.Space), buttons (.primary/.secondary/.quiet), chips, glass switch, `GlassSegments` (a choice of a few as one glass bar; names, or symbols, never cut), `SidePanel`, `.edgeFade()` (a list scrolling under a header fades at both ends), `.pane()` (at most `Kit.readable` 820 wide, centred in a wide window), `.rowPanel()`, eyebrow/group labels; the three input widths (`Kit.field` 170 for
                                      every control in a form, `Kit.rowAmount` 96 for an amount in a list's row, `Kit.largeField` 160 for a card's big amount)
Sources/BudgetKit/Screens/SheetCard.swift  sheet glass (sheetCard), GlassField, AmountField (label + field + €), SheetFooter (Cancel + action)
Sources/BudgetKit/Screens/Modal.swift      Quick log, payday, Set Balance and Paid Back are cards (`.modal(close:)`) in the middle of the window, at most 440 wide, over the
                                      rest of it blurred and dimmed (only dimmed under Reduce Transparency); pulled down (>90 pt or a flick), two fingers down,
                                      Escape or a click round it closes it
Scripts/make-icon.swift / make-icon.sh  draw the app icon (ring of days on black glass) into Resources/AppIcon.icns, which is committed
.github/workflows/tests.yml           on every push to main and pull request: build, test, the app and an unsigned installer (an artifact for 7 days)
.github/workflows/release.yml         a pushed `v*` tag: test, sign and notarize with the repository's secrets (`Scripts/release.sh`), publish Tally.dmg
                                      as that release, the tag's message its notes. `main` is protected: no force pushes or deleting, and Tests must pass
Scripts/make-dmg.sh / dmg-background.swift  the download's installer window, as Brimlight's: black glass, "Tally", the bottom light in the icon's
                                      green and cyan, the app and Applications on a ledge (Finder lays it out; the first run asks to control Finder);
                                      `Scripts/release.sh` uses it
Sources/BudgetKit/Design/Living.swift  copied from Brimlight: Living, Motion, EdgeLight, GlowMeter, DayLine, LiquidDayLine, DotRing, PillButtonStyle, HoverLift, RollingDigits
Sources/BudgetKit/Design/Spring.swift  copied from Brimlight: the damped spring
Sources/BudgetKit/Design/Swipe.swift  `.swipeToClose(.down|.right, pull:ended:)`: two fingers on the trackpad (a local scroll-event monitor; not a mouse wheel,
                                      not momentum) pull a card down or a `SidePanel` right, following them (the panel gives its width back as it goes, so the list widens with the fingers); `SwipeDirection.travel` reads the
                                      fingers' way whatever the scroll setting, and ignores a move mostly the other way
Sources/BudgetKit/Screens/Screen.swift  `Screen` (today, pots, month, insights, entries, plan: the sidebar's sections), titles, symbols, ⌘ keys, each section's edge-light colours and `tint`, the pots' colours (`Pot.palette`, `Ledger.light(_:)`, and the two named colours `Color.arrived` green / `Color.ahead` cyan)
Sources/BudgetKit/Screens/Glass.swift  the black glass behind the window: corners 22, hairline, the edge light crossfading to the chosen section; `lightRoom` (48: how far up the light reaches; the pane, the
                                      Undo pill and the cards keep above it, so nothing touches it); `WindowSize`
Sources/BudgetKit/Screens/RootView.swift  the sidebar and the chosen section's pane, the cards over the blurred window (nothing behind takes clicks while one is open),
                                      the quiet error line, the Undo pill; ⌘N, ⌘1–⌘7, ⌘, (Settings), ⌘Z, ⇧⌘H; `FirstRunView` before set-up; `LockView` in place of everything
                                      while locked (on open when the setting is on, and again when the Mac sleeps or its screen locks; never in the demo);
                                      amounts hidden by `amountsHidden` in the environment over the sidebar and pane (starts as `AmountsOnOpen` says; each toggle in the real app is kept for As I Left Them)
                                      The sections read one `day`, refreshed on `NSCalendarDayChanged` (no timer)
Sources/BudgetKit/Screens/Sidebar.swift  Today (with how many are still to pay), Pots, Month; "Records": Entries (this month's count), Plan;
                                      "You can spend" at the bottom (not while Today shows), and Log a Spend in the section's `tint` (the left of its light, just below it), beside the eye that hides amounts
Sources/BudgetKit/Screens/TodayView.swift  Today: "Monday 19 October", the ring with "YOU CAN SPEND", the amount a day ("a day until the 2 000", "2 000 is late", red below 0);
                                      beside it Still to pay and "Spent today", kept together in the middle of the pane; under them `TodayCards`; `TodayLayout` grows
                                      the ring (240 to 380, its dots and number with it) and the column with the window, a third of the room left above
Sources/BudgetKit/Screens/InsightsView.swift  Insights: Ask Tally (on a Mac with Apple Intelligence), "In short", then each insight as a card with a dot for its level
Sources/BudgetKit/Screens/AskBox.swift  "Ask about your money", three example questions; the answer (written by `Ledger.answer`, live with the data) under how
                                      the question was understood ("Spending · this week · with Sam")
Sources/BudgetKit/Screens/AskReader.swift  the on-device model (`SystemLanguageModel.default`, never the cloud one) reads a question into a `Question` by guided
                                      generation (`@Generable Reading`), then `Question.checked` against the words; it writes no sentence about the money
Sources/BudgetKit/Screens/TodayCards.swift  three cards under Today: Next pay ("the 1st · in 13 days"), Main this month (a small month line, "ends at"), Pots
Sources/BudgetKit/Screens/Privacy.swift  hiding amounts: `toggleAmounts` in the environment, `.bigAmount()` (hidden with the rest, a click hides or shows all);
                                      every other amount is marked `.privateAmount()`: hidden, one glass shape the size of it (a field's fill and hairline, round
                                      ends, corners of 10 when tall); the month line leaves its amounts out while hidden
Sources/BudgetKit/Screens/LockView.swift  "Tally is locked" and Unlock with Touch ID (or the Mac's password), via LocalAuthentication; asks at once
Sources/BudgetKit/Screens/SettingsView.swift  Settings, a section in the sidebar (⌘,): a `GlassSegments` bar of four tabs, each on `SettingsCard`s of `SettingRow`s: Privacy
                                      (Lock with Touch ID, asked first so a lock that can't open is never set; Amounts when Tally opens: Shown / Hidden / As I Left
                                      Them), Pots (`PotSettings`), Categories, Partner (their name; empty, it's off)
Sources/BudgetKit/Screens/PotSettings.swift  Settings → Pots: the savings pots on one card (colour, name saved as typed, goal saved once it reads, a ⋯ menu to
                                      Retire, only when it can be, or Bring Back), a new one on its own card
Sources/BudgetKit/Screens/CategorySettings.swift  Settings → Categories: one card of rows, name (saved as typed), pot (`GlassPicker`), a ⋯ menu to Retire / Bring Back; Add on its own card
Sources/BudgetKit/Screens/PartnerChoice.swift  Just Me / With Ana / Half / For Ana (a `GlassSegments` bar, or chips two by two where narrow), "Ana Pays Me Back";
                                      `partnerName` in the environment (Settings in the real app, "Sam" in the demo)
Sources/BudgetKit/Screens/PeopleView.swift  People: everyone money is open with ("Ben owes you", "You owe Lena", settled below), Record; a row opens
                                      `MoneyWithSheet` for them (`Someone`: new, partner, named)
Sources/BudgetKit/Screens/MoneyWithSheet.swift  amount, who (chips of people), I Lent / Paid Me Back / I Borrowed / I Paid Back, From before Tally, and how it
                                      will stand after ("Then Ben owes you 30,00 €"); the partner's own name means the partner
Sources/BudgetKit/Screens/PaidBackSheet.swift  "Ana paid back": how much (all they owe to start), into Main; Today shows "Ana owes you" with Paid Back
Sources/BudgetKit/Screens/TodayRing.swift  the month's days as dots: gone lit, paydays larger (green once come, cyan ahead), today white and largest
Sources/BudgetKit/Screens/StillToPayList.swift  "Still to pay": click = paid at the planned amount, ⌥-click or Edit = change it first (above 0; on the card's row
                                      "Set Owed" opens Set Balance for the card instead),
                                      right-click = Not This Month; "2 000 arrived?" opens the payday sheet; incomes not due yet are listed dimmed at the end ("650 · from the 15th") and open it too; carried-over rows say "· from October"
Sources/BudgetKit/Screens/PotsView.swift  Pots: "OCTOBER", the total, a tube per pot on one shared scale (the largest goal or amount), the balance above
                                      each (red below 0), the card as what's owed ("Paid off" at 0, "in credit" below), the tubes growing with the window up to 640 × 520, the goal month under
                                      each pot with a goal; "2 000 arrived?" while an income is due
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
                                      saved ("Saved this month" on the current month, "Saved" on past ones), and on the current month only each pot's goal month
Sources/BudgetKit/Screens/MonthLine.swift  the line in a `Canvas`: the month's days as faint dots along zero, solid and lit where it happened,
                                      dashed where projected, paydays as labelled dots, today the brightest, the lowest point ringed; hover reads a day out (none before the line starts; its first point, the day before the first run, reads "Started with")
Sources/BudgetKit/Screens/SheetCard.swift  the glass card every sheet sits on (`sheetCard`) and `GlassField`, the capsule text field (red while invalid);
                                      while amounts are hidden an amount field shows a bar until clicked or typed into (`secret: false` for a name or note)
Sources/BudgetKit/Screens/MenuBar.swift  Tally in the menu bar while it runs (`MenuBarExtra` in BudgetApp): `MenuBarLabel` shows the amount a day beside
                                      the ring's symbol (only the symbol with amounts hidden or the lock on); `MenuBarPanel` is Quick log on the black glass,
                                      and Open Tally (with the lock on, only Open Tally)
Sources/BudgetKit/Screens/QuickLogSheet.swift  Quick log: amount, the category chips (three a row, retired ones left out; a tap only chooses, the newest spend's to begin with: `Ledger.lastSpendCategory`, so it holds across launches), Bank Card /
                                      Credit Card / Cash (`PaymentMethodPicker`), the partner (when named), the note (`NoteField`); Log (or Return) saves
Sources/BudgetKit/Screens/EntriesPane.swift  Entries: a month's entries newest first, "‹ October 2026 ›" back to the first month; a row opens `EntryEditor`
                                      in a `SidePanel` on the right; `Entry.title`, `detail`, `shownAmount` say a row
Sources/BudgetKit/Screens/EntryEditor.swift  one entry: a spend's amount, how it was paid (bank, card or cash), the partner, note and category; a payment's, income's or repayment's amount; Delete
                                      (a paid plan item is due again); a balance set by hand can only be deleted. `EntryDraft.swift` holds its typed values
Sources/BudgetKit/Screens/PlanPane.swift  Plan: Add Item; "In October" (the month's summary, four across or two by two, and Left over); each group on a card
                                      (symbol, total due this month), items by day on two lines (name and amount; when, how often, from where; "≈ 1,25 € a month"
                                      for a rarer one); a row opens `PlanItemEditor` in a `SidePanel`
                                      (`PlanItemDraft` holds the typed values); Delete keeps the item's past payments
Sources/BudgetKit/Screens/PlanItemEditor.swift  the editor for one plan item (opened from the Plan): Repeats (every month, every 2, 3 or 6 months, every
                                      year, once) and Starting / In; `PlanItemDraft.swift` holds its typed values; a new item starts in the month it is added
Sources/BudgetKit/Screens/SetBalanceSheet.swift  right-click a tube on Pots, "Set Balance…": the card asks what is owed; the difference is an adjustment
Sources/BudgetKit/Screens/FirstRunView.swift  the first run, a page a step with the steps on the left (a done one goes back): Welcome, Income (name, amount,
                                      day), Regular Costs, Saving (`FirstRunSavings`: savings pots as chips or of
                                      their own, an emergency fund to begin with, each with what goes in each month and its goal; everything else a day), Your Pots (empty
                                      is 0, the card as owed), Already Paid, Partner (its name kept only in the real app); Start sets up with that plan
Sources/BudgetKit/Screens/FirstRunDraft.swift  what is typed, and the plan it makes (`plan`, nil while anything doesn't read; costs with no day go with the
                                      pay, or any day without one; a yearly one starts in its next month), `goals`, `balances`, `tickWhatHasPassed(today:)`
                                      (a dated item before today, an income that came and what goes with it), `paidAmounts`
Sources/BudgetKit/Screens/FirstRunPage.swift / FirstRunCosts.swift / FirstRunPaid.swift  each page's question and fields; the usual costs as chips with
                                      Add Your Own, each cost's amount, day ("When I'm paid") and Every month / Every year (in a month); this month's ticks
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
  decimals (a typo must never be saved as 0). A balance (Set Balance, the first run's pots) is read by `Cents.parseSigned`, which also takes one leading
  minus (`-45`, or `−45,00` as Tally writes it): an overdrawn account, or the card in credit. Pots shows a pot below 0 in red and
  the card in credit as "4,30 € in credit".
- `Cents.dividedFloor(by:)` rounds down (also for negatives), so the daily allowance is never more than the
  money allows. The caller makes sure the days are above 0.
- Pot balance = starting balance + entries in − entries out, counting only entries that move money (`Ledger.balance`).
- A plan item is **done** for a month when any entry points to it for that month, whatever the amount
  (`dismissed` counts). `Ledger.stillToPay(today:)` lists every undone item from the start month through
  this month, oldest month first, incomes first within a month, then plan order; unpaid items carry over
  to the next month. An income shows once its day (or the start of its window) has come; before that `Ledger.upcomingIncomes(today:)` lists it (shown dimmed, "650 · from the 15th", and it opens the same payday sheet, so an early income can be recorded). `Due.heldBack`
  marks what takes money out of Main and is ready to go: an item planned "with" an income waits only while that income applies this month and has not arrived; with the income paused, limited to another month or gone it is held back at once.
- **Paying off the card** (a plan item moving money to the card) is asked at what is owed now, not its planned amount
  (`Ledger.asked`): in still to pay, an income's split, the allowance and the month line. With nothing owed it is not
  listed, and only its latest month is: what is owed now covers the months before.
- **Next income** (`Ledger.nextIncome`): the earliest undone income of this month (`.day(d)` is d, a window is
  its last day). If that day has passed it is `late` and counted as today; with none left, next month's first.
- **Daily allowance** (`Ledger.allowance`) = (Main − every held-back due paid from Main, carried-over months
  included) divided down (floor) over `max(1, days from today to the income)`. It can be negative and is never hidden.
- **Goal month** (`Ledger.goalMonth`): balance plus this month's undone planned transfers into the pot; if that
  reaches the goal it is this month, else each later month's planned transfers are added, up to 120 months, else nil.
- **Month line** (`Ledger.monthLine`): it starts the day before the first-run day (the earliest entry's day, or the start month's 1st
  with no entries), at the balance typed then (`opening`, not counted as the lowest point), so the first day's spending shows and it never makes up a balance from further back; months before the start month are empty. Past months come from entries, today's month is entries up to yesterday,
  today's real balance, then a projection (every held-back due the allowance counts out of Main, on its day if it is dated and still ahead this month, else on the first projected day, the
  daily-life amount out every day, an undone income in on its day or on the first projected day if it is late,
  with its undone split out of Main). Later months are empty. See "How the numbers work" in the design.
- **Month's numbers:** the lowest point is the line's lowest balance, on the first day it is reached; "Saved this month" is the
  transfers that moved money into a savings pot, dated in that month, those ticked as paid at the first run included (corrections don't count); the line's paydays are
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
  (`Store.update`, `Store.deleteEntry`; a deleted one also clears Undo when it was part of the last action). `Store.undo()` deletes the entries the last recording action wrote (by id, one level; `undoable`, `canUndo`; `recordings` goes up with each action so the screen can offer it). RootView shows an "Undo" pill for 6 s after each action (one delayed hide, nothing runs while idle) and ⌘Z does the same. `setBalance` writes the difference as an `adjustment`, and a balance set that way holds: deleting or changing an entry
  dated before it moves the first adjustment after it in each pot it touches by the same amount (`Ledger.setBalancesHeld`), and the delete
  confirmation says so ("Credit card stays at what you set on the 19th."); `dismiss` writes a
  `dismissed` entry that moves no money; deleting a plan item leaves its entries, so balances never change.
- `setUp` (first run) takes the typed balances, the plan and goals the first run made, plus `paid`, the plan items already paid this
  month: they are recorded as done without moving money (`Seed.plan`, `Seed.goals` and `SavingsPot.original` are its defaults, for the demo and tests). It does nothing a second time.
- A spend comes out of its category's pot (by bank card or cash; it remembers which), or the credit card's debt grows. Its pot is kept on the entry, so moving a
  category to another pot changes later spends only. With the partner, `owed` is their part when they pay it back; money with anyone is
  `lent` / `borrowed` / `repayment` / `paidBack` with `person` (nil: the partner), moving no money when it was owed from before; a `repayment`
  entry brings money into Main and off `partnerOwes`.
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
