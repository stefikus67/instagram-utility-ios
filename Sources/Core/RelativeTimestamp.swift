import Foundation

public enum RelativeTimestamp {
    /// Today → "09:07", the previous six days → "Tue", older or future → "28.9.26".
    public static func string(for date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return format(date, "HH:mm", calendar, locale) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? Int.max
        if (1...6).contains(days) { return format(date, "EEE", calendar, locale) }
        return format(date, "d.M.yy", calendar, locale)
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar, _ locale: Locale) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = locale
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
