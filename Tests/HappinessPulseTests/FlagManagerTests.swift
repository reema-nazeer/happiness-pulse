import XCTest
@testable import HappinessPulse

final class FlagManagerTests: XCTestCase {
    func testWriteAndReadTodayFlag() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date(timeIntervalSince1970: 1_712_000_000)
        let manager = FlagManager(baseDirectory: dir, nowProvider: { now })

        XCTAssertFalse(manager.didSubmitPulseToday())
        try manager.writeTodaySubmittedFlag()
        XCTAssertTrue(manager.didSubmitPulseToday())
    }

    func testMidnightEdgeCasesByDate() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = FlagManager(baseDirectory: dir)
        let beforeMidnight = Date(timeIntervalSince1970: 1_712_063_900)
        let afterMidnight = beforeMidnight.addingTimeInterval(200)

        try manager.writeSubmittedFlag(on: beforeMidnight)
        XCTAssertTrue(manager.didSubmit(on: beforeMidnight))
        XCTAssertFalse(manager.didSubmit(on: afterMidnight))
    }

    func testCleanupDeletesOlderThanThirtyDays() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let now = Date(timeIntervalSince1970: 1_712_000_000)
        let manager = FlagManager(baseDirectory: dir, nowProvider: { now })
        let old = now.addingTimeInterval(-35 * 24 * 60 * 60)
        let fresh = now.addingTimeInterval(-5 * 24 * 60 * 60)

        try manager.writeSubmittedFlag(on: old)
        try manager.writeSubmittedFlag(on: fresh)

        manager.cleanupOldFlags(daysToKeep: 30)
        XCTAssertFalse(manager.didSubmit(on: old))
        XCTAssertTrue(manager.didSubmit(on: fresh))
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
