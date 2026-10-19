# Ask Tally

Agreed on 19 October 2026. A question box at the top of Insights: "Where did my money go this week?",
"How much did I spend on coffee this month?", "What does Sam owe me?".

## Who does what

- **Apple's on-device model only reads the question.** It turns it into a `Question` (guided generation into a
  fixed shape): a topic, a period, and maybe a category or a word to look for. It is `SystemLanguageModel.default`,
  on this Mac; never the Private Cloud Compute model.
- **Code writes the answer.** `Ledger.answer(_:today:partnerName:)` in `Money/` turns a `Question` into a title and a
  few lines, from the ledger, exactly. The model writes no sentence about the money, so it can't get a number or who
  owes whom wrong (it did both ways round in a trial summary: "You owe Sam" for "Sam owes you").
- Under the answer, how the question was understood ("Spending · this week · Food"), so a misreading shows.
- A category the model names must be one of yours (matched by name, case aside), or it is dropped.
- On a Mac without Apple Intelligence the box doesn't show.

## A Question

- Topic: **spending** (in a period, maybe in one category), **search** (spends whose note or category says a word,
  in a period), **balances** (the pots now), **allowance** (what can be spent a day, until when, and what is still to
  pay), **partner** (what they owe; together in a period), **insights** (what needs a look).
- Period: today, this week (Monday to today), last week (Monday to Sunday), this month, last month.

## Answers (examples)

- Spending, this week: "312,40 € in 14 spends" · "Food 180,00 € · Going out 52,40 € · …" · "Most on the 17th: 61,20 €".
- Search "coffee", this month: "6 spends, 30,60 €" · "Last on the 17th: 5,10 €" · "4 of them with Sam".
- Balances: each pot, the card as what it owes, the total.
- Allowance: "46,53 € a day until the 2 000 on the 1st (13 days)" · what is still to pay.
- Partner: "Sam owes you 29,10 €" · "With Sam 3 times this month; 29,10 € of it was Sam's".
- Insights: the "In short" line and the titles.
