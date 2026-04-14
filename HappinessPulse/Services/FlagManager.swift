import Foundation

final class FlagManager {
    private let fileManager = FileManager.default
    private let flagsDirectory: URL
    private let dateFormatter: DateFormatter
    private let isoFormatter: ISO8601DateFormatter
    private let nowProvider: () -> Date

    init(
        baseDirectory: URL? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        let homeDirectory = baseDirectory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("homey-pulse", isDirectory: true)
        flagsDirectory = homeDirectory.appendingPathComponent("flags", isDirectory: true)
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_GB_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        isoFormatter = ISO8601DateFormatter()
        self.nowProvider = nowProvider
    }

    func didSubmitPulseToday() -> Bool {
        didSubmit(on: nowProvider())
    }

    func didSubmit(on date: Date) -> Bool {
        do {
            try ensureFlagsDirectory()
            let todayFlag = flagsDirectory.appendingPathComponent(currentDateString(for: date))
            return fileManager.fileExists(atPath: todayFlag.path)
        } catch {
            return false
        }
    }

    func writeTodaySubmittedFlag() throws {
        try writeSubmittedFlag(on: nowProvider())
    }

    func writeSubmittedFlag(on date: Date) throws {
        try ensureFlagsDirectory()
        let todayFlag = flagsDirectory.appendingPathComponent(currentDateString(for: date))
        let payload = "\(isoFormatter.string(from: date))\n"
        try payload.write(to: todayFlag, atomically: true, encoding: .utf8)
    }

    func cleanupOldFlags(daysToKeep: Int = 30) {
        guard daysToKeep > 0 else { return }

        do {
            try ensureFlagsDirectory()
            let cutoff = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: nowProvider()) ?? Date.distantPast
            let fileURLs = try fileManager.contentsOfDirectory(at: flagsDirectory, includingPropertiesForKeys: nil)

            for fileURL in fileURLs {
                let filename = fileURL.lastPathComponent
                guard let date = dateFormatter.date(from: filename) else { continue }
                if date < cutoff {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            // Swallow by design for unattended reliability.
        }
    }

    func flagsDirectoryPath() -> URL {
        flagsDirectory
    }

    private func currentDateString(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func ensureFlagsDirectory() throws {
        if !fileManager.fileExists(atPath: flagsDirectory.path) {
            try fileManager.createDirectory(at: flagsDirectory, withIntermediateDirectories: true)
        }
    }
}
