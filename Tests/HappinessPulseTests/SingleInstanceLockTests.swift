import XCTest
@testable import HappinessPulse

final class SingleInstanceLockTests: XCTestCase {
    func testAcquireAndRelease() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lock = SingleInstanceLock(baseDirectory: dir)
        XCTAssertTrue(lock.acquire())
        lock.release()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent(".pulse.lock").path))
    }

    func testStaleLockIsReclaimed() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lockFile = dir.appendingPathComponent(".pulse.lock")
        try "999999\n".write(to: lockFile, atomically: true, encoding: .utf8)
        let oldDate = Date().addingTimeInterval(-700)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: lockFile.path)

        let lock = SingleInstanceLock(baseDirectory: dir, staleAfterSeconds: 600)
        XCTAssertTrue(lock.acquire())
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
