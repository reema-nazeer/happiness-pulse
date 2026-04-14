import Foundation

final class FirstLaunchRegistrationService {
    private let fileManager = FileManager.default

    func completeRegistration(name: String, registeredFileURL: URL) throws {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitized.count >= 2 else {
            throw NSError(domain: "FirstLaunchRegistrationService", code: 1)
        }
        let parent = registeredFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try sanitized.write(to: registeredFileURL, atomically: true, encoding: .utf8)
    }
}
