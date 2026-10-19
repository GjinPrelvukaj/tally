import Foundation

/// A calendar month. Plain numbers, so it compares, sorts and saves without time zones getting in the way.
public struct YearMonth: Hashable, Comparable, Codable, Sendable {
    public var year: Int
    public var month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(_ year: Int, _ month: Int) { self.init(year: year, month: month) }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year!, month: parts.month!)
    }

    public static func < (a: YearMonth, b: YearMonth) -> Bool {
        (a.year, a.month) < (b.year, b.month)
    }

    public var next: YearMonth { month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1) }
    public var previous: YearMonth { month == 1 ? YearMonth(year - 1, 12) : YearMonth(year, month - 1) }

    public func days(calendar: Calendar) -> Int {
        calendar.range(of: .day, in: .month, for: firstDay(calendar: calendar))!.count
    }

    /// The given day of this month; a 31st in a short month lands on its last day.
    public func date(day: Int, calendar: Calendar) -> Date {
        let clamped = min(max(day, 1), days(calendar: calendar))
        return calendar.date(from: DateComponents(year: year, month: month, day: clamped))!
    }

    /// "October", in English whatever the Mac's language, as the rest of the app is.
    public var name: String { Self.english.standaloneMonthSymbols[month - 1] }

    /// "Mar 2027".
    public var shortName: String { "\(Self.english.shortStandaloneMonthSymbols[month - 1]) \(year)" }

    fileprivate static let english: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en")
        return calendar
    }()

    private func firstDay(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }
}

/// "Monday 19 October", in English whatever the Mac's language.
public func dayTitle(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.weekday, .day, .month], from: date)
    let english = YearMonth.english
    return "\(english.weekdaySymbols[parts.weekday! - 1]) \(parts.day!) \(english.standaloneMonthSymbols[parts.month! - 1])"
}
