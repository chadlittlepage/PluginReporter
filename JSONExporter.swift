// JSONExporter.swift — SINGLE SOURCE OF TRUTH
import Foundation

public enum JSONExporter {

    /// Primary API used by ContentView
    public static func export(rows: [PluginItem], to url: URL) {
        let payload: [[String: Any]] = rows.map { i in
            let dateKey: Double = i.date?.timeIntervalSince1970 ?? 0
            return [
                "Name": i.name,
                "Publisher": i.publisher,
                "Version": i.version,
                "Type": i.type,
                "Style": i.style,
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
            AppLogger.export.error("JSON export failed: \(error.localizedDescription)")
        }
    }
}
