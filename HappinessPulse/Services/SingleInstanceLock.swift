import Foundation
import Darwin

/// Atomic single-instance enforcement using `flock(2)`. The previous
/// implementation used a PID file with a mod-time-based "stale after 600s"
/// fallback — which had a race window where two processes started inside
/// the same poll interval could both pass the lock check before either one
/// wrote its PID. That caused the duplicate-popup reports.
///
/// `flock(LOCK_EX | LOCK_NB)` is kernel-enforced and atomic: the second
/// caller's flock() returns EWOULDBLOCK immediately. When the holding
/// process exits (cleanly or via crash), the kernel releases the advisory
/// lock automatically, so we never need a stale-detection heuristic.
final class SingleInstanceLock {
    private let lockFileURL: URL
    private let fileManager = FileManager.default
    private(set) var lockAcquired = false
    private var fileDescriptor: Int32 = -1

    init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("homey-pulse", isDirectory: true)
        lockFileURL = base.appendingPathComponent(".pulse.lock")
    }

    func acquire() -> Bool {
        do {
            try fileManager.createDirectory(
                at: lockFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: lockFileURL.deletingLastPathComponent().path
            )
        } catch {
            return false
        }

        let path = lockFileURL.path
        // O_CREAT|O_RDWR — create if missing, open for writing.
        let fd = open(path, O_RDWR | O_CREAT, 0o600)
        guard fd >= 0 else { return false }

        // LOCK_NB → don't block; return immediately if another process holds the lock.
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            // Another instance has the lock. Don't pretend we have it.
            close(fd)
            return false
        }

        fileDescriptor = fd
        lockAcquired = true

        // Write our PID inside the locked file for diagnostic purposes only —
        // the lock itself is held by flock, not by reading this PID.
        let pidString = "\(ProcessInfo.processInfo.processIdentifier)\n"
        if let data = pidString.data(using: .utf8) {
            ftruncate(fd, 0)
            data.withUnsafeBytes { _ = write(fd, $0.baseAddress, data.count) }
        }

        return true
    }

    func release() {
        guard lockAcquired else { return }
        if fileDescriptor >= 0 {
            // Releasing the fd implicitly releases the flock on macOS.
            flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
            fileDescriptor = -1
        }
        // Best-effort cleanup of the on-disk file. If another instance picks
        // up the lock between our LOCK_UN and unlink, that's fine — they
        // hold the kernel lock regardless of whether the file exists.
        try? fileManager.removeItem(at: lockFileURL)
        lockAcquired = false
    }
}
