import Foundation

final class SubmissionService {
    private struct HappinessPayload: Codable {
        let type: String
        let score: Int
        let feedback: String
        let timestamp: String
        let version: String
        let os_version: String
        let source: String
        let secret: String?
    }

    private let webhookURL = URL(string: "https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec")
    private let logger = PulseLogger.shared
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let nowProvider: () -> Date
    private let injectedNetworkPost: ((URL, Data, @escaping (Result<Void, Error>) -> Void) -> Void)?
    private let webhookSecret: String?
    private lazy var pendingDirectory: URL = {
        baseDirectory.appendingPathComponent("pending", isDirectory: true)
    }()
    private let baseDirectory: URL

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 2
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    init(
        baseDirectory: URL? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        networkPost: ((URL, Data, @escaping (Result<Void, Error>) -> Void) -> Void)? = nil,
        webhookSecret: String? = ProcessInfo.processInfo.environment["HOMEY_PULSE_WEBHOOK_SECRET"]
    ) {
        self.baseDirectory = baseDirectory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("homey-pulse", isDirectory: true)
        self.nowProvider = nowProvider
        self.injectedNetworkPost = networkPost
        self.webhookSecret = webhookSecret
    }

    func submitPulse(score: Int, feedback: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let webhookURL else {
            completion(.failure(NSError(domain: "SubmissionService", code: -1)))
            return
        }

        let payload = HappinessPayload(
            type: "happiness",
            score: score,
            feedback: feedback,
            timestamp: ISO8601DateFormatter().string(from: nowProvider()),
            version: "2.0.0",
            os_version: ProcessInfo.processInfo.shortOSVersion,
            source: "macos-native-v2",
            secret: webhookSecret
        )

        do {
            let body = try encoder.encode(payload)
            executePost(webhookURL: webhookURL, body: body) { [weak self] result in
                if case .failure = result {
                    self?.queuePendingSubmission(body)
                }
                completion(result)
            }
        } catch {
            queuePendingSubmission(Data())
            completion(.failure(error))
        }
    }

    func retryPendingSubmissions(completion: @escaping () -> Void) {
        cleanupStalePendingSubmissions()

        let pendingFiles: [URL]
        do {
            try ensurePendingDirectory()
            pendingFiles = try fileManager.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
        } catch {
            completion()
            return
        }

        guard !pendingFiles.isEmpty, let webhookURL else {
            completion()
            return
        }

        processPendingFilesSequentially(pendingFiles, webhookURL: webhookURL, index: 0, completion: completion)
    }

    private func processPendingFilesSequentially(_ files: [URL], webhookURL: URL, index: Int, completion: @escaping () -> Void) {
        guard index < files.count else {
            completion()
            return
        }

        let fileURL = files[index]
        guard let body = try? Data(contentsOf: fileURL) else {
            processPendingFilesSequentially(files, webhookURL: webhookURL, index: index + 1, completion: completion)
            return
        }

        executePost(webhookURL: webhookURL, body: body) { [weak self] result in
            switch result {
            case .success:
                try? self?.fileManager.removeItem(at: fileURL)
            case let .failure(error):
                self?.logger.error("Pending submission retry failed: \(error.localizedDescription)")
            }

            self?.processPendingFilesSequentially(files, webhookURL: webhookURL, index: index + 1, completion: completion)
        }
    }

    private func postJSON(webhookURL: URL, body: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "SubmissionService", code: -2)))
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "SubmissionService", code: httpResponse.statusCode)))
                return
            }
            completion(.success(()))
        }.resume()
    }

    private func executePost(webhookURL: URL, body: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        if let injectedNetworkPost {
            injectedNetworkPost(webhookURL, body, completion)
        } else {
            postJSON(webhookURL: webhookURL, body: body, completion: completion)
        }
    }

    private func queuePendingSubmission(_ body: Data) {
        guard !body.isEmpty else { return }
        do {
            try ensurePendingDirectory()
            let filename = "pending-\(UUID().uuidString).json"
            let target = pendingDirectory.appendingPathComponent(filename)
            try body.write(to: target, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            logger.error("Submission queued for retry")
        } catch {
            logger.error("Failed to queue pending submission")
        }
    }

    private func cleanupStalePendingSubmissions() {
        do {
            try ensurePendingDirectory()
            let files = try fileManager.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
            let cutoff = nowProvider().addingTimeInterval(-7 * 24 * 60 * 60)
            for file in files where file.pathExtension == "json" {
                let values = try? file.resourceValues(forKeys: [.creationDateKey])
                if let created = values?.creationDate, created < cutoff {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            // Keep silent for resilience.
        }
    }

    private func ensurePendingDirectory() throws {
        if !fileManager.fileExists(atPath: pendingDirectory.path) {
            try fileManager.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: pendingDirectory.path)
        }
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        if #available(macOS 11.0, *) {
            #if arch(arm64)
            return "arm64"
            #else
            return "x86_64"
            #endif
        } else {
            return "x86_64"
        }
    }

    var shortOSVersion: String {
        let version = operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
    }
}
