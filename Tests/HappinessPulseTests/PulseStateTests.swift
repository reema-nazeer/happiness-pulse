import XCTest
@testable import HappinessPulse

final class PulseStateTests: XCTestCase {
    func testShouldShowCombinations() {
        let weekdayMorning = makeDate(year: 2026, month: 4, day: 14, hour: 10, minute: 0)
        let saturday = makeDate(year: 2026, month: 4, day: 18, hour: 10, minute: 0)
        // Working hours are 7am–8pm, so 6:30am is outside.
        let early = makeDate(year: 2026, month: 4, day: 14, hour: 6, minute: 30)
        // 8pm is outside (interval is half-open: < 20:00).
        let late = makeDate(year: 2026, month: 4, day: 14, hour: 20, minute: 30)

        let mock = MockFlagChecker()
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.firstWeekday = 1
        let state = PulseState(flagManager: mock, calendar: gregorian)

        mock.submittedToday = false
        XCTAssertTrue(state.shouldShow(lockIsAvailable: true, date: weekdayMorning))
        XCTAssertFalse(state.shouldShow(lockIsAvailable: false, date: weekdayMorning))
        XCTAssertFalse(state.shouldShow(lockIsAvailable: true, date: saturday))
        XCTAssertFalse(state.shouldShow(lockIsAvailable: true, date: early))
        XCTAssertFalse(state.shouldShow(lockIsAvailable: true, date: late))

        mock.submittedToday = true
        XCTAssertFalse(state.shouldShow(lockIsAvailable: true, date: weekdayMorning))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

private final class MockFlagChecker: FlagChecking {
    var submittedToday = false

    func didSubmitPulseToday() -> Bool { submittedToday }
    func writeTodaySubmittedFlag() throws {}
    func cleanupOldFlags(daysToKeep: Int) {}
}
