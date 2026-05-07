import Foundation

/// Optional install-time configuration loaded from `~/homey-pulse/config.json`.
///
/// New (v3) installs are department-specific: the per-department install
/// scripts write a tiny config file baking in (a) the department this
/// machine belongs to and (b) the webhook URL pointing at the v3 Google
/// Sheet.  The app reads the file on startup; if it's present, the popup
/// skips the department-picker step and shows the department name as a
/// read-only header.
///
/// Older v2.1.0 installs that don't have a config.json continue to work as
/// before — we fall back to the in-app department picker and the original
/// hardcoded webhook URL, so existing laptops never break when they
/// auto-update to a v3 build.
struct PulseConfig: Decodable {
    let webhook_url: String?
    let department: String?

    /// Validated department: must be one of the known whitelist, otherwise
    /// nil so the app falls back to the picker.
    var validatedDepartment: String? {
        guard let raw = department?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let allowed = ["Operations", "Revenue", "Service", "Technology"]
        for name in allowed where name.lowercased() == raw.lowercased() {
            return name
        }
        return nil
    }

    /// Validated webhook URL: must be a non-empty https URL, otherwise nil.
    var validatedWebhookURL: URL? {
        guard let raw = webhook_url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }
}

// MARK: - Sub-department loader

enum SubDepartmentLoader {
    private struct Response: Decodable {
        let status: String
        let sub_departments: [String]?
    }

    /// Fetches the sub-department list for `department` from the webhook.
    /// Always calls back on the main queue. Returns an empty array on any
    /// error or timeout (the card still works — it just hides the picker).
    static func fetch(
        from webhookURL: URL,
        department: String,
        completion: @escaping ([String]) -> Void
    ) {
        var comps = URLComponents(url: webhookURL, resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "action",     value: "subdepts"),
            URLQueryItem(name: "department", value: department)
        ]
        guard let url = comps?.url else {
            PulseLogger.shared.error("SubDepartmentLoader: could not build URL from \(webhookURL)")
            DispatchQueue.main.async { completion([]) }
            return
        }

        PulseLogger.shared.info("SubDepartmentLoader: fetching \(url.absoluteString)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 15
        let session = URLSession(configuration: config)

        session.dataTask(with: url) { data, response, error in
            if let error {
                PulseLogger.shared.error("SubDepartmentLoader: network error — \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            guard let data else {
                PulseLogger.shared.error("SubDepartmentLoader: no data received")
                DispatchQueue.main.async { completion([]) }
                return
            }
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            PulseLogger.shared.info("SubDepartmentLoader: response — \(raw.prefix(300))")
            do {
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                let subdepts = decoded.sub_departments ?? []
                PulseLogger.shared.info("SubDepartmentLoader: got \(subdepts.count) sub-departments")
                DispatchQueue.main.async { completion(subdepts) }
            } catch {
                PulseLogger.shared.error("SubDepartmentLoader: decode error — \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}

// MARK: - Config loader

enum PulseConfigLoader {
    /// Default config path. Per-dept install scripts write here.
    static var defaultURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("homey-pulse", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    /// Load the config from disk, returning nil if absent or unparseable.
    /// Never throws — a missing or malformed config simply means "fall
    /// back to v2.1.0 behaviour".
    static func load(from url: URL = defaultURL) -> PulseConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PulseConfig.self, from: data)
        } catch {
            PulseLogger.shared.error("Failed to parse config.json — falling back to picker UI: \(error.localizedDescription)")
            return nil
        }
    }
}
