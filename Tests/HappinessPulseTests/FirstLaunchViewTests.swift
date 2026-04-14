import XCTest
@testable import HappinessPulse

final class FirstLaunchViewTests: XCTestCase {
    func testRegistrationWritesRegisteredFileAndSignalsTransition() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = FirstLaunchRegistrationService()
        let registeredFile = dir.appendingPathComponent(".registered")
        try service.completeRegistration(name: "John Smith", registeredFileURL: registeredFile)

        let saved = try String(contentsOf: registeredFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(saved, "John Smith")
    }

    func testRegistrationRejectsShortNames() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = FirstLaunchRegistrationService()
        let registeredFile = dir.appendingPathComponent(".registered")
        XCTAssertThrowsError(try service.completeRegistration(name: "A", registeredFileURL: registeredFile))
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
