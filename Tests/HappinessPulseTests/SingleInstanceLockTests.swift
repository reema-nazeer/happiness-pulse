import XCTest
@testable import HappinessPulse

final class SingleInstanceLockTests: XCTestCase {
    /// Acquire-then-release is a no-op cycle; the lock file is gone afterwards.
    func testAcquireAndRelease() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lock = SingleInstanceLock(baseDirectory: dir)
        XCTAssertTrue(lock.acquire())
        lock.release()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".pulse.lock").path))
    }

    /// Two SingleInstanceLock instances pointed at the same directory are
    /// mutually exclusive — the second cannot acquire while the first holds
    /// the flock. Once the first releases, the second can.
    func testSecondAcquireFailsWhileFirstHeld() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = SingleInstanceLock(baseDirectory: dir)
        let second = SingleInstanceLock(baseDirectory: dir)

        XCTAssertTrue(first.acquire())
        XCTAssertFalse(second.acquire(), "Second instance must not be able to acquire while first holds the lock")
        XCTAssertFalse(second.lockAcquired)

        first.release()

        XCTAssertTrue(second.acquire(), "After first releases, second instance can acquire")
        second.release()
    }

    /// A leftover lock file from a previous process that has since exited
    /// should not block a fresh acquire — flock auto-releases when the
    /// holding process dies, so the file alone is no obstacle.
    func testFreshAcquireAfterPriorLeftoverFile() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Simulate a leftover file from a previous run (no live process holds flock).
        let lockFile = dir.appendingPathComponent(".pulse.lock")
        try "999999\n".write(to: lockFile, atomically: true, encoding: .utf8)

        let lock = SingleInstanceLock(baseDirectory: dir)
        XCTAssertTrue(lock.acquire())
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
