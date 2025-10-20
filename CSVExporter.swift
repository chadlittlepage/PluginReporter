// CSVExporter.swift
import Foundation

enum CSVExporter {
    @MainActor
    static func write(rows: [PluginItem], to url: URL) {
        // Formatters (cheap to set up once per export)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let sizeFormatter = ByteCountFormatter()
        sizeFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        sizeFormatter.countStyle = .file

        // Use MetadataManager for edited metadata values
        let metadataManager = MetadataManager.shared

        // CSV header
        let header = "Name,Publisher,Version,Type,Style,Architectures,Date,Size,Path,Requirement,Obsolete\n"

        // Build body rows, escaping quotes and wrapping fields in quotes
        let body = rows.map { r -> String in
            let dateStr = r.date.map { dateFormatter.string(from: $0) } ?? ""
            let sizeStr = sizeFormatter.string(fromByteCount: r.sizeBytes)
            let obsoleteStr = r.obsolete ? "Yes" : "No"

            let fields = [
                r.name,
                metadataManager.getDisplayPublisher(for: r),
                metadataManager.getDisplayVersion(for: r),
                r.type,
                metadataManager.getDisplayStyle(for: r),
                r.architectures,
                dateStr,
                sizeStr,
                r.path,
                r.runtimeRequirement,
                obsoleteStr
            ]

            return fields
                .map { $0.replacingOccurrences(of: "\"", with: "\"\"") } // escape quotes
                .map { "\"\($0)\"" }                                      // wrap in quotes
                .joined(separator: ",")
        }
        .joined(separator: "\n")

        try? (header + body).data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
