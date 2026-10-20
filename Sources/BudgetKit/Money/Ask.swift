import Foundation

/// A question about the money, in a fixed shape: what about, over which period, and maybe a category (by name) or
/// a word to look for. Ask Tally's on-device model only fills this in; the answer is `Ledger.answer`.
public struct Question: Equatable, Sendable {
    public enum Topic: String, CaseIterable, Sendable { case spending, search, balances, allowance, partner, insights }
    public enum Period: String, CaseIterable, Sendable { case today, thisWeek, lastWeek, thisMonth, lastMonth }

    public var topic: Topic
    public var period: Period
    public var category: String?
    public var search: String?
    /// Only spends with the partner.
    public var withPartner: Bool

    public init(topic: Topic, period: Period = .thisMonth, category: String? = nil, search: String? = nil, withPartner: Bool = false) {
        self.topic = topic
        self.period = period
        self.category = category
        self.search = search
        self.withPartner = withPartner
    }

    /// The model's reading, checked against the question's own words: a category or a word is kept only if the
    /// question says it, plain cues decide the topic ("owe" and the partner's name, "enough until payday", "card"),
    /// the partner's name in a spending question keeps to spends with them, and time words said win.
    public func checked(against text: String, categories: [Category], partnerName: String) -> Question {
        let lower = text.lowercased()
        func says(_ words: String) -> Bool {
            !words.isEmpty && lower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: words.lowercased()))\\b", options: .regularExpression) != nil
        }
        func saysAny(_ cues: [String]) -> Bool { cues.contains { lower.contains($0) } }
        var read = self

        let said = categories.filter { !$0.retired && says($0.name) }
        read.category = (said.first { $0.name.caseInsensitiveCompare(category ?? "") == .orderedSame } ?? said.first)?.name
        read.search = search.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .flatMap { says($0) && $0 != read.category?.lowercased() ? $0 : nil }

        if says("today") { read.period = .today }
        else if lower.contains("this week") { read.period = .thisWeek }
        else if lower.contains("last week") { read.period = .lastWeek }
        else if lower.contains("this month") { read.period = .thisMonth }
        else if lower.contains("last month") { read.period = .lastMonth }

        let partner = says(partnerName) || says("partner")
        let spent = saysAny(["spen", "bought", "buy", "paid for"])
        if lower.contains("card") && (lower.contains("owe") || !spent) { read.topic = .balances }
        else if lower.contains("owe") || (partner && !spent) { read.topic = .partner }
        else if saysAny(["enough", "a day", "per day", "daily", "payday", "can i spend", "left to spend", "still to pay"]) { read.topic = .allowance }
        else if saysAny(["balance", "account", "pots", "how much do i have"]) { read.topic = .balances }

        if read.topic == .spending, read.search != nil, read.category == nil { read.topic = .search }
        if read.topic == .search, read.search == nil { read.topic = .spending }
        read.withPartner = partner && (read.topic == .spending || read.topic == .search)
        if read.topic != .spending { read.category = nil }
        if read.topic != .search { read.search = nil }
        return read
    }
}

/// What Ask Tally says: a title, a few lines, and how the question was understood. All written by code.
public struct Answer: Equatable, Sendable {
    public var title: String
    public var lines: [String]
    public var understood: String
}

extension Ledger {
    public func answer(_ question: Question, today: Date, partnerName: String) -> Answer {
        // A category the model named is used only if it is one of yours.
        let category = question.category.flatMap { name in
            categories.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
        }
        let search = question.search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let range = range(question.period, today: today)
        let when = phrase(question.period, today: today)
        let (title, lines): (String, [String]) = switch question.topic {
        case .spending: spending(in: range, when: when, category: category, with: question.withPartner ? partnerName : "")
        case .search: searching(search ?? "", in: range, when: when, partner: partnerName, onlyWith: question.withPartner)
        case .balances: balances()
        case .allowance: dailyAmount(today: today)
        case .partner: together(in: range, when: when, partner: partnerName)
        case .insights: (Insight.headline(insights(today: today, partnerName: partnerName)) ?? "Nothing to point out",
                         insights(today: today, partnerName: partnerName).prefix(5).map(\.title))
        }
        var understood = [question.topic.title]
        if [.spending, .search, .partner].contains(question.topic) { understood.append(question.period.title) }
        if question.topic == .spending, let category { understood.append(category.name) }
        if question.topic == .search, let search { understood.append("“\(search)”") }
        if question.withPartner, !partnerName.isEmpty { understood.append("with \(partnerName)") }
        return Answer(title: title, lines: lines, understood: understood.joined(separator: " · "))
    }

    // MARK: Topics

    /// `with`: the partner's name to keep to spends with them; empty for all.
    private func spending(in range: Range<Date>, when: String, category: Category?, with partner: String) -> (String, [String]) {
        let spends = spends(from: range.lowerBound, through: range.upperBound)
            .filter { (category == nil || $0.category == category?.id) && (partner.isEmpty || $0.partner != nil) }
        let on = (category.map { " on \($0.name)" } ?? "") + (partner.isEmpty ? "" : " with \(partner)")
        guard !spends.isEmpty else { return ("Nothing spent\(on) \(when)", []) }
        var lines = ["\(spends.count) spend\(spends.count == 1 ? "" : "s")"]
        if category == nil {
            let byCategory = Dictionary(grouping: spends) { $0.category ?? Category.other.id }.mapValues(total)
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(4)
            lines.append(byCategory.map { "\(self.category($0.key)?.name ?? Category.other.name) \($0.value.formatted)" }.joined(separator: " · "))
        }
        let byDay = Dictionary(grouping: spends) { calendar.component(.day, from: $0.date) }.mapValues(total)
        if byDay.count > 1, let most = byDay.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) {
            lines.append("Most on the \(ordinal(most.key)): \(most.value.formatted)")
        }
        return ("\(total(spends).formatted) spent\(on) \(when)", lines)
    }

    private func searching(_ word: String, in range: Range<Date>, when: String, partner: String, onlyWith: Bool) -> (String, [String]) {
        let found = spends(from: range.lowerBound, through: range.upperBound).filter { entry in
            !word.isEmpty && ((entry.note?.lowercased().contains(word) ?? false)
                || category(entry.category)?.name.lowercased() == word)
                && (!onlyWith || entry.partner != nil)
        }
        guard let last = found.max(by: { $0.date < $1.date }) else { return ("Nothing on “\(word)” \(when)", []) }
        var lines = ["\(found.count) spend\(found.count == 1 ? "" : "s")",
                     "Last on the \(ordinal(calendar.component(.day, from: last.date))): \(last.amount.formatted)"]
        let with = found.filter { $0.partner != nil }.count
        if !partner.isEmpty, with > 0 { lines.append("\(with) of them with \(partner)") }
        return ("\(total(found).formatted) on “\(word)” \(when)", lines)
    }

    private func balances() -> (String, [String]) {
        let lines = pots.map { pot -> String in
            guard pot == .card else { return "\(name(pot)) \(balance(pot).formatted)" }
            let owed = Pot.card.figure(for: balance(.card))
            return owed > .zero ? "\(name(pot)): you owe \(owed.formatted)" : "\(name(pot)): paid off"
        }
        return ("\(total.formatted) across \(potCount)", lines)
    }

    private func dailyAmount(today: Date) -> (String, [String]) {
        guard let allowance = allowance(today: today) else { return ("Add your income in the plan", []) }
        let dues = stillToPay(today: today).filter { !$0.isIncome }.prefix(4)
            .map { "\($0.item.name) \($0.item.amount.formatted)" }
        return ("\(allowance.perDay.formatted) a day until the \(allowance.until.item.amount.wholeEuros)",
                ["\(allowance.days) day\(allowance.days == 1 ? "" : "s"), today included",
                 dues.isEmpty ? "Nothing left to pay" : "Still to pay: " + dues.joined(separator: ", ")])
    }

    private func together(in range: Range<Date>, when: String, partner: String) -> (String, [String]) {
        guard !partner.isEmpty else { return ("No partner set", ["Add their name in Settings."]) }
        let title = partnerOwes > .zero ? "\(partner) owes you \(partnerOwes.formatted)" : "\(partner) owes you nothing"
        let with = spends(from: range.lowerBound, through: range.upperBound).filter { $0.partner != nil }
        guard !with.isEmpty else { return (title, ["Not out with \(partner) \(when)"]) }
        let theirs = with.reduce(Cents.zero) { $0 + ($1.partner?.theirs(of: $1.amount) ?? .zero) }
        return (title, ["With \(partner) \(with.count) time\(with.count == 1 ? "" : "s") \(when); \(theirs.formatted) of it was \(partner)'s"])
    }

    // MARK: Periods

    /// Today; this week from Monday to today; last week Monday to Sunday; this month to today; last month whole.
    func range(_ period: Question.Period, today: Date) -> Range<Date> {
        let day = calendar.startOfDay(for: today)
        let monday = calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: day) + 5) % 7), to: day)!
        let month = YearMonth(today, calendar: calendar)
        return switch period {
        case .today: day..<dayAfter(today)
        case .thisWeek: monday..<dayAfter(today)
        case .lastWeek: calendar.date(byAdding: .day, value: -7, to: monday)!..<monday
        case .thisMonth: month.date(day: 1, calendar: calendar)..<dayAfter(today)
        case .lastMonth: month.previous.date(day: 1, calendar: calendar)..<month.date(day: 1, calendar: calendar)
        }
    }

    private func phrase(_ period: Question.Period, today: Date) -> String {
        switch period {
        case .today: "today"
        case .thisWeek: "this week"
        case .lastWeek: "last week"
        case .thisMonth: "this month"
        case .lastMonth: "in \(YearMonth(today, calendar: calendar).previous.name)"
        }
    }

    private func total(_ entries: [Entry]) -> Cents { entries.reduce(Cents.zero) { $0 + $1.amount } }
}

extension Question.Topic {
    public var title: String {
        switch self {
        case .spending: "Spending"
        case .search: "Search"
        case .balances: "Balances"
        case .allowance: "Daily amount"
        case .partner: "Partner"
        case .insights: "Insights"
        }
    }
}

extension Question.Period {
    public var title: String {
        switch self {
        case .today: "today"
        case .thisWeek: "this week"
        case .lastWeek: "last week"
        case .thisMonth: "this month"
        case .lastMonth: "last month"
        }
    }
}
