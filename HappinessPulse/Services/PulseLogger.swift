import Foundation

final class PulseLogger {
    static let shared = PulseLogger()

    private let fileManager = FileManager.default
    private let isoFormatter = ISO8601DateFormatter()
    private let logURL: URL

    private init() {
        let home = fileManager.homeDirectoryForCurrentUser
        let baseDir = home.appendingPathComponent("homey-pulse", isDirectory: true)
        logURL = baseDir.appendingPathComponent("pulse.log")
        try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: baseDir.path)
    }

    func info(_ message: String) {
        write(level: "INFO", message: message)
    }

    func error(_ message: String) {
        write(level: "ERROR", message: message)
    }

    private func write(level: String, message: String) {
        let line = "[\(isoFormatter.string(from: Date()))] [\(level)] \(message)\n"
        let data = Data(line.utf8)

        do {
            if !fileManager.fileExists(atPath: logURL.path) {
                fileManager.createFile(atPath: logURL.path, contents: Data())
                try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logURL.path)
            }

            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            rotateIfNeeded()
        } catch {
            // Intentionally swallow to keep app fail-safe and silent.
        }
    }

    private func rotateIfNeeded() {
        guard let data = try? Data(contentsOf: logURL),
              let content = String(data: data, encoding: .utf8)
        else { return }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count > 500 else { return }

        let kept = lines.suffix(500).joined(separator: "\n")
        try? kept.data(using: .utf8)?.write(to: logURL, options: .atomic)
    }
}
