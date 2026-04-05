import Foundation

/// Returns the number of days remaining until a target date (from today).
/// Returns 0 if the date is in the past.
public func daysRemaining(until date: Date) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: Date())
    let end = cal.startOfDay(for: date)
    let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
    return max(days, 0)
}

/// Returns the number of days in the current month.
public func daysInMonth(for date: Date = Date()) -> Int {
    let cal = Calendar.current
    return cal.range(of: .day, in: .month, for: date)?.count ?? 30
}

/// Formats a date as an abbreviated string (e.g., "Mar 24, 2026").
public func dateStringAbbreviated(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
}

/// Formats a date as a relative string (e.g., "2 days ago", "in 3 hours").
public func dateStringRelative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}
