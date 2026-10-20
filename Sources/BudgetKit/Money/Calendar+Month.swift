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

    /// How many months after `earlier` this is (negative when before it).
    public func monthsSince(_ earlier: YearMonth) -> Int { (year - earlier.year) * 12 + month - earlier.month }

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

/// A time of day, "18:13": read and written by hand, so it never follows the system locale (24 hours, as the money's commas).
public struct TimeOfDay: Hashable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// When a date happened, in the calendar's time zone.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// "18:13", "9:05" or "9.05"; nil for anything else, so a typo never moves an entry.
    public init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
            .flatMap { $0.split(separator: ".", omittingEmptySubsequences: false) }
        guard parts.count == 2, (1...2).contains(parts[0].count), parts[1].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let hour = Int(parts[0]), let minute = Int(parts[1]), hour < 24, minute < 60 else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// "09:05".
    public var formatted: String {
        (hour < 10 ? "0" : "") + "\(hour):" + (minute < 10 ? "0" : "") + "\(minute)"
    }

    /// The same day as `date`, at this time.
    public func on(_ date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
