// HTMLExporter.swift
import Foundation
enum HTMLExporter {
    static func write(rows: [PluginItem], to url: URL) {
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
        "<tr><th>Name</th><th>Publisher</th><th>Version</th><th>Type</th><th>Style</th><th>Architectures</th><th>Date</th><th>Size</th><th>Path</th><th>Requirement</th><th>Obsolete</th></tr>"
        let rowsHTML = rows.map { r in
            "<tr>" + [
                r.name, r.publisher, r.version, r.type, r.style, r.architectures,
                r.dateString, r.sizeString, r.path, r.runtimeRequirement, r.obsoleteString
            ].map { "<td>\($0)</td>" }.joined() + "</tr>"
        }.joined()
        let html = "<!doctype html><html><head>\(head)</head><body><table>\(header)\(rowsHTML)</table></body></html>"
        try? html.data(using: .utf8)?.write(to: url, options: .atomic)
    }
}
