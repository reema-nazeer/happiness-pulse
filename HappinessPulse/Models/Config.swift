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
