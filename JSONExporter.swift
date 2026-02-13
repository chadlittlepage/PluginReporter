// JSONExporter.swift — SINGLE SOURCE OF TRUTH
import Foundation

public enum JSONExporter {

    /// Primary API used by ContentView
    @MainActor
    public static func export(rows: [PluginItem], to url: URL) {
        // Use MetadataManager for edited metadata values
        let metadataManager = MetadataManager.shared

        let payload: [[String: Any]] = rows.map { i in
            let dateKey: Double = i.date?.timeIntervalSince1970 ?? 0

            // Get license type (macOS only, LicenseManager not available on iOS)
            #if os(macOS)
            let licenseType = LicenseTypeHelper.getCachedLicenseType(for: i)
            #else
            let licenseType = ""
            #endif

            return [
                "Name": i.name,
                "Publisher": metadataManager.getDisplayPublisher(for: i),
                "Version": metadataManager.getDisplayVersion(for: i),
                "License": licenseType,
                "Type": i.type,
                "Style": metadataManager.getDisplayStyle(for: i),
                "Architectures": i.architectures,
                "Date": dateKey,                 // Double (seconds since 1970)
                "SizeBytes": i.sizeBytes,
                "Path": i.path,
                "Requirement": i.runtimeRequirement,
                "Obsolete": i.obsolete
            ]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: url, options: [.atomic])
        } catch {
            AppLogger.error("JSON export failed: \(error.localizedDescription)")
        }
    }
}
