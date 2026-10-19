# Own categories, a partner, and Insights

Agreed on 19 October 2026. Four steps, in this order, each merged and installed before the next.

## 1. Categories of your own

- A category has a name and the pot a spend in it comes out of (Main, Clothes or the Emergency fund; the card is
  chosen per spend). They can be added, renamed, moved to another pot and retired (hidden from Quick log; entries keep it).
- The five that exist keep their keys (`food`, `goingOut`, `clothes`, `fragrance`, `other`), so every entry saved
  before still points at its category. A new one's key is a fresh UUID.
- Changing a category's pot changes future spends only: a saved spend keeps the pot it came out of.
- Managed in Settings → Categories.

## 2. A partner

- Settings → Partner: their name. With no name, nothing of this shows.
- On a spend (Quick log and the entry editor): **Just Me** (default), **With Ana** (company only; all of it was
  yours), **Half Ana's**, **For Ana** (all theirs). With Half or For: **Ana Pays Me Back**, which adds their part to
  what Ana owes.
- **Paid Back** records money from Ana into Main and takes it off what Ana owes.
- What Ana owes = their parts marked to be paid back − what Ana paid back.

## One change to what is saved

Both steps are one schema change, `SchemaV2`, with a lightweight migration from `SchemaV1` (today's records):
a new `CategoryRecord`, and two optional fields on `EntryRecord` (`partner`, `owed`). A repayment is a new entry
kind, `repayment`. Before the first build with V2 opens the real data, `Budget.store`, `-wal` and `-shm` are copied
to a dated backup folder next to them.

## 3. Insights (code; every rule tested)

All exact, from the ledger; nothing guessed.

- **Running short:** where Main's line first goes below 0 before the next income ("Main runs out on the 27th"),
  and the amount a day that would reach the income instead. Also when spending of the last 7 days runs faster
  than the allowance.
- **Habits that add up:** spends repeated often (same category and note, at least 4 times in 30 days), what they
  cost a month and what that is a year.
- **This month and last:** each category's spend by today's day of the month against the same days last month;
  the ones that moved most, in plain words.
- **Plan check:** a spend that came every month for 3 months but isn't in the plan (suggest adding it); a plan item
  dismissed or left unpaid 2 months running; the card owing more at the end of each of the last 3 months.
- **Partner:** how much went to Ana this month, how often you were out together, what Ana owes and since when.
- Each insight: a kind, how much it matters (warning, notice, good news), a title, one line, and the numbers.

## 4. The Insights section

- A section in the sidebar under Month (⌘4): the insights, the most pressing first, with the count of warnings.
- Over them, "In short": one line made by code from the insights (what needs a look, or that all is on track).
- The on-device model was tried for that line and dropped (19 October): given "Sam owes you 29,10 €" it wrote
  "You owe Sam 29,10 €", every number right and the meaning backwards. If it comes back, it is as "Ask Tally",
  where the model only phrases answers that code looks up (tool calls), never a summary of its own.
