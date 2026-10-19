import Foundation

// Insights about the plan and what is owed: a spend that comes every month but isn't planned, a plan item skipped
// two months running, a card owing more every month, and the partner.

extension Ledger {
    /// A spend with the same note in each of the last 3 months, at much the same amount (the dearest at most a
    /// quarter over the cheapest), that no plan item is named for.
    func unplanned(today: Date) -> [Insight] {
        let month = YearMonth(today, calendar: calendar)
        let months = [month.previous.previous, month.previous, month]
        guard months[0] >= startMonth else { return [] }
        let planned = plan.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let start = months[0].date(day: 1, calendar: calendar)
        let noted = spends(from: start, through: dayAfter(today)).compactMap { entry -> (String, Entry)? in
            guard let note = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !note.isEmpty else { return nil }
            return (note, entry)
        }
        return Dictionary(grouping: noted, by: \.0).compactMap { note, pairs -> Insight? in
            let spends = pairs.map(\.1)
            let seen = Set(spends.map { YearMonth($0.date, calendar: calendar) })
            guard months.allSatisfy(seen.contains), !planned.contains(where: { $0 == note || $0.contains(note) || note.contains($0) }) else { return nil }
            let amounts = spends.map(\.amount.value)
            let low = amounts.min()!, high = amounts.max()!
            guard high * 4 <= low * 5 else { return nil }
            let each = low == high ? Cents(low).formatted : "\(Cents(low).formatted) to \(Cents(high).formatted)"
            return Insight(id: "unplanned-\(note)", kind: .unplanned, level: .notice,
                           title: "\(capitalised(note)) comes every month",
                           detail: "\(each) in each of the last 3 months, but it isn't in your plan. Add it, so the daily amount counts it.")
        }
        .sorted { $0.id < $1.id }
    }

    /// A plan item that went out of Main (or into a pot) and was neither paid in either of the last two months:
    /// dismissed, or left. It may be worth pausing or taking out.
    func skipped(today: Date) -> [Insight] {
        let month = YearMonth(today, calendar: calendar)
        let months = [month.previous.previous, month.previous]
        guard months[0] >= startMonth else { return [] }
        return plan.filter { item in
            item.kind != .income && item.kind != .daily && months.allSatisfy { m in
                item.applies(in: m) && !entries.contains { $0.planItem == item.id && $0.forMonth == m && $0.kind != .dismissed }
            }
        }
        .map { item in
            Insight(id: "skipped-\(item.id)", kind: .skipped, level: .notice,
                    title: "\(item.name) was skipped in \(months[0].name) and \(months[1].name)",
                    detail: "Pause it, or take it out of the plan if it is gone, so the daily amount stops holding it back.")
        }
    }

    /// The card owing more at the end of each of the last two months, and more again now.
    func cardTrend(today: Date) -> [Insight] {
        let month = YearMonth(today, calendar: calendar)
        let months = [month.previous.previous, month.previous]
        guard months[0] >= startMonth else { return [] }
        let owed = months.map { Pot.card.figure(for: balance(.card, endOf: $0.date(day: $0.days(calendar: calendar), calendar: calendar))) }
        let now = Pot.card.figure(for: balance(.card))
        guard owed[0] > .zero, owed[0] < owed[1], owed[1] < now else { return [] }
        return [Insight(id: "card", kind: .card, level: .warning, title: "The card owes more every month",
                        detail: "\(owed[0].formatted) at the end of \(months[0].name), \(owed[1].formatted) at the end of \(months[1].name), \(now.formatted) now.")]
    }

    /// What the partner owes, and how often you were together this month with what of it was theirs.
    func partner(today: Date, name: String) -> [Insight] {
        guard !name.isEmpty else { return [] }
        var found: [Insight] = []
        if partnerOwes > .zero {
            let marked = entries.filter { $0.owed != nil }.count
            found.append(Insight(id: "partner-owes", kind: .partner, level: .notice, title: "\(name) owes you \(partnerOwes.formatted)",
                                 detail: "From \(marked) spend\(marked == 1 ? "" : "s") marked to be paid back, less what \(name) paid back."))
        }
        let month = YearMonth(today, calendar: calendar)
        let together = spends(from: month.date(day: 1, calendar: calendar), through: dayAfter(today)).filter { $0.partner != nil }
        if !together.isEmpty {
            let theirs = together.reduce(Cents.zero) { $0 + ($1.partner?.theirs(of: $1.amount) ?? .zero) }
            found.append(Insight(id: "partner-month", kind: .partner, level: .notice,
                                 title: "With \(name) \(together.count) time\(together.count == 1 ? "" : "s") this month",
                                 detail: theirs > .zero ? "\(theirs.formatted) of it was \(name)'s." : "All of it was yours."))
        }
        return found
    }
}
