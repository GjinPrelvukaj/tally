# Working on Tally

**Read [CONTEXT.md](CONTEXT.md) first**, then this file.

## The loop, for every batch

1. Work on a branch from `main` (`git checkout -b mNN-short-name`). The first one is `m1-first-version`.
2. Read the code a change touches before changing it. Fix root causes in the shared place.
3. **Test first** (swift-testing, `Tests/BudgetKitTests`): watch it fail for the right reason, then make it pass.
   Pure logic gets a test; view-only changes get a picture (below).
4. Run the whole suite and read it: `swift test > /tmp/t.log 2>&1; grep -E "Test run with|✘|error" /tmp/t.log | tail`.
5. **Update the docs in the same commit**: if the change touches anything CONTEXT.md, AGENTS.md or README.md
   states (a type or file name, a command, a rule, a decision), fix that line. Facts only, checked against the code.
6. Commit in plain words about what changed for the person. **No `Co-Authored-By`, no AI mention.**
7. Have the branch reviewed read-only (`git diff main...branch`) and fix what it finds, then merge with
   `git merge --no-ff`.

## Commands

| Task | Command |
|---|---|
| Build | `swift build` |
| Test | `swift test` (filter: `swift test --filter CentsTests`) |
| Run | `swift run Budget` opens your real saved data: **agents never run it**, only `--demo` (below) |
| App bundle (in `build/`) | `Scripts/make-app.sh` (debug), `Scripts/make-app.sh release`; `Scripts/release.sh X.Y.Z` for a signed, notarized DMG |

## Seeing what you changed (demo mode)

`Budget --demo` runs on a made-up 19 October 2026 on the starter plan, in memory (Main 640, Clothes 240, Emergency
2 150, card −45; this month's salary items already paid), today pinned to 19 Oct 2026 12:00; it never opens the file on disk.

- `--screen today|pots|month|entries|plan`: the section it opens on; `--screen payday` is 1 November with the salary due and its
  card open, `--screen log` Today with Quick log open, `--screen firstrun` a demo that
  has not been set up. Other values are ignored.
- `--after-payday`: the salary added on 1 November with its planned split, today pinned there.
- `--hidden`: every amount starts hidden. `--screen settings` opens the Settings window too (a second window: capture it by its
  width, 440). The demo never reads the real app's settings and never locks.
- Keys and clicks are not delivered to a demo started from a shell, so the editors inside a sheet (a plan item, a
  typed amount, the right-click "Set Balance…", ⌘N / ⌘,) are checked by hand in the real app.
- Month in the demo has only October (the demo starts there), so paging back through months, ⌘← / ⌘→ and the hover
  read-out are checked by hand in the real app.

Capture only the demo's own window, by its id:

```bash
Scripts/make-app.sh >/dev/null
build/Tally.app/Contents/MacOS/Tally --demo --screen pots & PID=$!; sleep 3
cat > /tmp/winid.swift <<'EOF'   # prints "<window id> <width> <height>" for each window of a pid
import CoreGraphics; import Foundation
let pid = Int32(CommandLine.arguments[1])!
for w in CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
    where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let b = w[kCGWindowBounds as String] as! [String: Any]; print(w[kCGWindowNumber as String]!, b["Width"]!, b["Height"]!)
}
EOF
ID=$(swift /tmp/winid.swift $PID | head -1 | cut -d' ' -f1)
screencapture -x -o -l $ID /tmp/budget-pots.png; kill $PID
```

Stop only your own demo (`kill $PID`), never `pkill`. A key can be sent to the demo alone with
`CGEvent(keyboardEventSource:virtualKey:keyDown:).postToPid(pid)` (124 is the right arrow); never post events to the
whole session. It only arrives while the demo is the active app, which a demo started from a shell usually isn't. Idle CPU: average `ps -o %cpu= -p $PID` over 15 s with the window untouched; it should be about 0%.

## Rules that are not negotiable

- **Agents always run with `--demo`**, never on real data (`~/Library/Application Support/Budget/Budget.store`).
- **Before any model change** (a field added to or removed from a SwiftData record) add a `VersionedSchema` in `Store/Schema.swift` (freeze the old records as copies, as `SchemaV1` does) with a migration and a test that opens a file saved the old way (`MigrationTests`),
  and back up `Budget.store`, `Budget.store-wal` and `Budget.store-shm` first.

- **Money is `Cents`, never `Double`.** Money logic lives only in `Sources/BudgetKit/Money/`.
- **Privacy:** nothing leaves the Mac. No network, no third-party packages.
- **Pictures:** capture only the app's own window (`screencapture -l <window id>`), never the whole screen.
- **Git:** `github.com/GjinPrelvukaj/tally`, branch `main`.
- **Scope:** the design's non-goals stay out (bank import, iPhone, sync, charts beyond the month line,
  per-category budgets, other currencies) unless asked.
- Ask before downloading anything new; pin versions at least two weeks old.

## Traps already hit

- AppKit takes a bare word on the command line (`pots` in `--screen pots`) for a file to open and then opens no
  window; `BudgetApp` registers `NSTreatUnknownArgumentsAsOpen = NO` so it doesn't.
- With the title bar hidden the content sits under the title bar's height; the glass behind it fills the whole window.
- `.scrollPosition(id:)` alone did not open on the asked page; `ScrollPosition.scrollTo(id:)` in `onAppear` does.
- The window keeps its size under the defaults key `NSWindow Frame budget`, shared by the demo and the real app; a new
  `Window` id opened no window at all, so the id stays `budget`.
- Scroll events and mouse clicks posted to a pid (`postToPid`) don't reach the window, so a swipe or a click on a row
  can't be faked that way; check them by hand.
- A `TextField` given a large font from outside (`.font` after `.background`) is drawn clipped to a small field; set the
  font on the field itself (`GlassField` in `SheetCard.swift`).
- A glow (`.shadow`) reaches past a frame of height 0, so an empty fill still showed a line; hide it with opacity.

## Style

- **Looks live in `Design/Kit.swift`.** Screens use its fonts (`Kit.body`, `Kit.quiet`, `Kit.title`, `Kit.amount`), buttons (`.primary`, `.secondary`, `.quiet`, `.chip`), `.toggleStyle(.glass)`, `.eyebrow()` and `.groupLabel()`. No inline font sizes, fills or stock switches in a screen; change the kit instead. Gaps come from `Kit.Space` (label 6, item 8, group 16, edge 20); fields come in `Kit.field`, `Kit.rowAmount` and `Kit.largeField` widths only. Any amount drawn on screen is `.privacySensitive()` (a big one `.bigAmount()`); a `GlassField` holding a name or note passes `secret: false`. Sheets are `AmountField` + content + `SheetFooter`, wrapped in `.modal(close:)`. A section's content uses `.pane()`; an editor beside a list sits in `SidePanel`; lists of rows use `.rowPanel()`; a choice of a few is a `GlassSegments` bar (or `.chip` buttons where many).
- **No lazy stacks or grids inside a sheet:** their items are made after the sheet starts rising and pop in before it arrives. The sheet container has `.geometryGroup()` so it moves as one piece.
- The icon: edit `Scripts/make-icon.swift`, run `Scripts/make-icon.sh`, commit `Resources/AppIcon.icns`.

- Comments say **why**, short, in plain words. Names say what a thing is (`stillToPay`, `PaydaySheet`).
- User-facing text: plain, short, no jargon.
- Smallest change that fixes the root cause; no abstraction with a single use.
