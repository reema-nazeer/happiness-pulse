import Foundation

protocol FlagChecking {
    func didSubmitPulseToday() -> Bool
    func writeTodaySubmittedFlag() throws
    func cleanupOldFlags(daysToKeep: Int)
}

extension FlagManager: FlagChecking {}

final class PulseState {
    private let calendar: Calendar
    private let flagManager: FlagChecking

    init(flagManager: FlagChecking = FlagManager(), calendar: Calendar = PulseState.defaultCalendar()) {
        self.flagManager = flagManager
        self.calendar = calendar
    }

    /// Pinned to Gregorian calendar. Calendar.current can vary by user locale
    /// (Hebrew, Buddhist, etc.) which would change weekday numbering and
    /// historically caused the "popup on Saturday" bug for some users.
    private static func defaultCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday — matches Gregorian convention so weekday 2..6 == Mon..Fri
        return cal
    }

    /// Mon–Fri only. Belt-and-braces with the LaunchAgent's
    /// StartCalendarInterval (which the OS itself enforces).
    func isWeekday(date: Date = Date()) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    /// 7am–8pm. Matches the original v1 contract; the v2 narrowing to 9–5 was
    /// the cause of "some people don't see the popup" reports — anyone on
    /// before 9am or off after 5pm got nothing.
    func isWithinWorkingHours(date: Date = Date()) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let currentMinutes = hour * 60 + minute
        return currentMinutes >= (7 * 60) && currentMinutes < (20 * 60)
    }

    func writeFlag() throws {
        try flagManager.writeTodaySubmittedFlag()
    }

    func hasSubmittedToday() -> Bool {
        flagManager.didSubmitPulseToday()
    }

    func cleanupFlags() {
        flagManager.cleanupOldFlags(daysToKeep: 30)
    }

    func shouldShow(lockIsAvailable: Bool, date: Date = Date()) -> Bool {
        guard lockIsAvailable else { return false }
        guard isWeekday(date: date) else { return false }
        guard isWithinWorkingHours(date: date) else { return false }
        return !hasSubmittedToday()
    }
}
