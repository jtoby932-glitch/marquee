import Foundation

/// Calendar rules shared by every date calculation: the device timezone
/// (Europe/London by default), weeks starting on Monday, en-GB formats.
enum AppCalendar {
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    enum PartOfDay: Equatable { case morning, afternoon, evening, night }

    static func partOfDay(_ date: Date, calendar: Calendar = calendar()) -> PartOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<23: return .evening
        default: return .night
        }
    }

    /// "Good evening, Toby" — without a name if none is set.
    static func greeting(at date: Date, name: String?, calendar: Calendar = calendar()) -> String {
        let base: String
        switch partOfDay(date, calendar: calendar) {
        case .morning: base = String(localized: "Good morning")
        case .afternoon: base = String(localized: "Good afternoon")
        case .evening: base = String(localized: "Good evening")
        case .night: base = String(localized: "Still up")
        }
        guard let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return base }
        return "\(base), \(name)"
    }

    /// "THURSDAY 12 NOVEMBER" for the Home eyebrow.
    static func eyebrowDate(_ date: Date, calendar: Calendar = calendar()) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date).uppercased()
    }

    /// "12 Nov 2026"
    static func shortDate(_ date: Date, calendar: Calendar = calendar()) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    /// "2 h 46 m", "48 m"
    static func runtime(_ minutes: Int) -> String {
        guard minutes > 0 else { return "" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) m" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) m"
    }
}
