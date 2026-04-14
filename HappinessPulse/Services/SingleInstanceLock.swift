import Foundation
import Darwin

final class SingleInstanceLock {
    private let lockFileURL: URL
    private let fileManager = FileManager.default
    private(set) var lockAcquired = false
    private let staleAfterSeconds: TimeInterval

    init(baseDirectory: URL? = nil, staleAfterSeconds: TimeInterval = 600) {
        let base = baseDirectory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("homey-pulse", isDirectory: true)
        lockFileURL = base.appendingPathComponent(".pulse.lock")
        self.staleAfterSeconds = staleAfterSeconds
    }

    func acquire() -> Bool {
        do {
            try fileManager.createDirectory(
                at: lockFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: lockFileURL.deletingLastPathComponent().path)
        } catch {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier

        do {
            if fileManager.fileExists(atPath: lockFileURL.path) {
                if isStaleLock() {
                    try? fileManager.removeItem(at: lockFileURL)
                } else {
                let raw = try String(contentsOf: lockFileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                if let existingPID = Int32(raw), existingPID > 0, isProcessAlive(existingPID) {
                    return false
                }
                }
            }
        } catch {
            // Treat unreadable lock as stale and continue overwrite.
        }

        do {
            try "\(currentPID)\n".write(to: lockFileURL, atomically: true, encoding: .utf8)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: lockFileURL.path)
            lockAcquired = true
            return true
        } catch {
            return false
        }
    }

    func release() {
        guard lockAcquired else { return }

        do {
            if fileManager.fileExists(atPath: lockFileURL.path) {
                try fileManager.removeItem(at: lockFileURL)
            }
        } catch {
            // Intentionally swallow for safe teardown.
        }
        lockAcquired = false
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        if pid <= 0 { return false }
        return kill(pid, 0) == 0
    }

    private func isStaleLock() -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: lockFileURL.path),
              let modified = attributes[.modificationDate] as? Date
        else {
            return false
        }
        return Date().timeIntervalSince(modified) > staleAfterSeconds
    }
}
