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

    init(flagManager: FlagChecking = FlagManager(), calendar: Calendar = .current) {
        self.flagManager = flagManager
        self.calendar = calendar
    }

    func isWeekday(date: Date = Date()) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    func isWithinWorkingHours(date: Date = Date()) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let currentMinutes = hour * 60 + minute
        return currentMinutes >= (9 * 60) && currentMinutes < (17 * 60)
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
