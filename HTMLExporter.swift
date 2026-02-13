// HTMLExporter.swift
import Foundation
enum HTMLExporter {
    @MainActor
    static func write(rows: [PluginItem], to url: URL) {
        // Use MetadataManager for edited metadata values
        let metadataManager = MetadataManager.shared

        let head =
        """
        <meta charset="utf-8"><style>
        body{font:12px -apple-system,BlinkMacSystemFont,Helvetica,Arial}
        table{border-collapse:collapse;width:100%}
        th,td{border:1px solid #444;padding:4px 6px;text-align:left}
        th{background:#222;color:#ddd}
        tr:nth-child(even){background:#111}
        </style>
        """
        let header =
        "<tr><th>Name</th><th>Publisher</th><th>Version</th><th>License</th><th>Type</th><th>Style</th><th>Architectures</th><th>Date</th><th>Size</th><th>Path</th><th>Requirement</th><th>Obsolete</th></tr>"
        let rowsHTML = rows.map { r in
            // Get license type (macOS only, LicenseManager not available on iOS)
            #if os(macOS)
            let licenseType = LicenseTypeHelper.getCachedLicenseType(for: r)
            #else
            let licenseType = ""
            #endif

            return "<tr>" + [
                r.name,
                metadataManager.getDisplayPublisher(for: r),
                metadataManager.getDisplayVersion(for: r),
                licenseType,
                r.type,
                metadataManager.getDisplayStyle(for: r),
                r.architectures,
                r.dateString, r.sizeString, r.path, r.runtimeRequirement, r.obsoleteString
            ].map { "<td>\($0)</td>" }.joined() + "</tr>"
        }.joined()
        let html = "<!doctype html><html><head>\(head)</head><body><table>\(header)\(rowsHTML)</table></body></html>"
        try? html.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
