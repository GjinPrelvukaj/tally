import Foundation

/// One thing worth knowing about the money, worked out exactly from the ledger: what kind, how much it matters,
/// a title and one line. The words carry their own numbers, so nothing has to be worked out again to say them.
public struct Insight: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case runningShort, onTrack, pace, habit, month, unplanned, skipped, card, partner }

    /// Warnings first, then news, then good news.
    public enum Level: Int, Comparable, Sendable {
        case warning, notice, good
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    /// Stable across redraws: the kind and what it is about ("habit-cigarettes").
    public var id: String
    public var kind: Kind
    public var level: Level
    public var title: String
    public var detail: String
}

extension Insight {
    /// One line over the insights (given warnings first): what needs a look, or that all is on track, and how many
    /// more there are. Made from their own titles, so it never says anything they don't.
    public static func headline(_ insights: [Insight]) -> String? {
        guard !insights.isEmpty else { return nil }
        let warnings = insights.filter { $0.level == .warning }
        let onTrack = insights.first { $0.kind == .onTrack }
        let lead: Insight?
        let opening: String
        if let first = warnings.first {
            lead = first
            opening = warnings.count == 1 ? "One thing needs a look: \(first.title)." : "\(warnings.count) things need a look, first: \(first.title)."
        } else if let onTrack {
            lead = onTrack
            opening = "On track: \(onTrack.title)."
        } else {
            lead = nil
            opening = "Nothing pressing."
        }
        let rest = insights.count - (lead == nil ? 0 : 1)
        return rest == 0 ? opening : "\(opening) \(rest) \(lead == nil ? "" : "more ")below."
    }
}

extension Ledger {
    /// Everything worth knowing today, warnings first. `partnerName` empty leaves the partner out.
    public func insights(today: Date, partnerName: String) -> [Insight] {
        let all = shortfall(today: today) + pace(today: today) + habits(today: today) + monthAgainstLast(today: today)
            + unplanned(today: today) + skipped(today: today) + cardTrend(today: today)
            + partner(today: today, name: partnerName)
        // A stable sort: within a level, the order above.
        return all.enumerated().sorted { ($0.element.level, $0.offset) < ($1.element.level, $1.offset) }.map(\.element)
    }

    /// Spends that took money: what a habit, a category or a pace is made of.
    func spends(from start: Date, through end: Date) -> [Entry] {
        entries.filter { $0.kind == .spend && $0.movesMoney && $0.date >= start && $0.date < end }
    }

    /// The day after `date`, at midnight: the end of a range that includes `date`.
    func dayAfter(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }

    /// The first day anything was written down: nothing is judged from before it.
    var firstDay: Date {
        calendar.startOfDay(for: entries.map(\.date).min() ?? startMonth.date(day: 1, calendar: calendar))
    }
}

/// "cigarettes" → "Cigarettes".
func capitalised(_ words: String) -> String {
    words.prefix(1).uppercased() + words.dropFirst()
}
