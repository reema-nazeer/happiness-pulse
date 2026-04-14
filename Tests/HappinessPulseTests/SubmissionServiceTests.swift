import XCTest
@testable import HappinessPulse

final class SubmissionServiceTests: XCTestCase {
    func testFailureQueuesPendingAndRetryRemoves() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        var shouldFail = true
        let service = SubmissionService(
            baseDirectory: dir,
            networkPost: { _, _, completion in
                if shouldFail {
                    completion(.failure(NSError(domain: "test", code: -1)))
                } else {
                    completion(.success(()))
                }
            }
        )

        let failureExp = DispatchSemaphore(value: 0)
        service.submitPulse(score: 8, feedback: "offline") { result in
            if case .failure = result { failureExp.signal() }
        }
        wait(for: [failureExp], timeout: 1)

        let pendingDir = dir.appendingPathComponent("pending")
        let pendingFiles = try FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)
        #expect(pendingFiles.filter { $0.pathExtension == "json" }.count == 1)

        shouldFail = false
        let retryExp = DispatchSemaphore(value: 0)
        service.retryPendingSubmissions { retryExp.signal() }
        wait(for: [retryExp], timeout: 1)

        let remaining = try FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)
        #expect(remaining.filter { $0.pathExtension == "json" }.count == 0)
    }

    func testSuccessDoesNotQueuePending() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = SubmissionService(
            baseDirectory: dir,
            networkPost: { _, _, completion in completion(.success(())) }
        )

        let exp = DispatchSemaphore(value: 0)
        service.submitPulse(score: 7, feedback: "") { result in
            if case .success = result { exp.signal() }
        }
        wait(for: [exp], timeout: 1)

        let pendingDir = dir.appendingPathComponent("pending")
        let files = (try? FileManager.default.contentsOfDirectory(at: pendingDir, includingPropertiesForKeys: nil)) ?? []
        #expect(files.filter { $0.pathExtension == "json" }.isEmpty)
    }

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func wait(for semaphores: [DispatchSemaphore], timeout: TimeInterval) {
        let deadline = DispatchTime.now() + timeout
        for semaphore in semaphores {
            let result = semaphore.wait(timeout: deadline)
            XCTAssertEqual(result, .success)
        }
    }
}
