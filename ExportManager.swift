// ExportManager.swift — macOS-only helpers for exporting PluginItem rows
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
import CoreGraphics
import SwiftUI

extension ExportManager {
    struct PDFOptionsContainer: View {
        @State private var options: PDFExportOptions
        let rows: [PluginItem]
        let onClose: () -> Void
        
        init(options: PDFExportOptions, rows: [PluginItem], onClose: @escaping () -> Void) {
            self._options = State(initialValue: options)
            self.rows = rows
            self.onClose = onClose
        }
        
        var body: some View {
            PDFExportOptionsSheet(options: $options) { opts in
                // Close the options sheet first to avoid nested sheets
                onClose()
                // Defer presenting NSSavePanel until after the sheet is dismissed
                DispatchQueue.main.async {
                    ExportManager.exportPDF(rows: rows, options: opts)
                }
            } onCancel: {
                onClose()
            }
        }
    }

    static func presentPDFOptionsAndExport(rows: [PluginItem], initial: PDFExportOptions) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "PDF Export Options"
        panel.isReleasedWhenClosed = true

        let host = NSHostingController(rootView: PDFOptionsContainer(options: initial, rows: rows) {
            // Close the panel immediately
            panel.orderOut(nil)
            panel.close()
            panel.contentViewController = nil
        })
        panel.contentViewController = host

        // Present as a standalone window (not a sheet) to avoid any sheet conflicts
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}

struct ExportManager {
    // MARK: Public API
    static func exportCSV(rows: [PluginItem]) {
        let defaultName = defaultFileName(prefix: "Plugins", ext: "csv")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["csv"]) else { return }
        let csv = makeCSV(rows: rows)
        do {
            try csv.data(using: .utf8)?.write(to: url)
            dashboardTrackExport()
        } catch {
            NSAlert(error: error).runModal()
            dashboardLogError(message: "CSV export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    static func exportJSON(rows: [PluginItem]) {
        let defaultName = defaultFileName(prefix: "Plugins", ext: "json")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["json"]) else { return }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(rows.map(JSONRow.init))
            try data.write(to: url)
            dashboardTrackExport()
        } catch {
            NSAlert(error: error).runModal()
            dashboardLogError(message: "JSON export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    static func exportHTML(rows: [PluginItem]) {
        let defaultName = defaultFileName(prefix: "Plugins", ext: "html")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["html", "htm"]) else { return }
        let html = makeHTML(rows: rows)
        do {
            try html.data(using: .utf8)?.write(to: url)
            dashboardTrackExport()
        } catch {
            NSAlert(error: error).runModal()
            dashboardLogError(message: "HTML export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    static func exportPDF(rows: [PluginItem], options: PDFExportOptions) {
        let defaultName = defaultFileName(prefix: "Plugins", ext: "pdf")
        runSavePanelAsync(suggestedName: defaultName, allowedFileTypes: ["pdf"]) { url in
            guard let url else { return }
            do {
                var size = options.page.sizePoints
                if options.landscape { size = CGSize(width: size.height, height: size.width) }
                var mediaBox = CGRect(origin: .zero, size: size)
                guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"]) }
                
                let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsctx

                let contentRect = mediaBox.insetBy(dx: options.margin, dy: options.margin)

                let header = "Plugin Report (\(rows.count) items)\n\n"
                let charWidth = max(options.fontSize * 0.6, 1)
                let capacity = Int((contentRect.width / charWidth).rounded(.down))
                let body = makeTabularText(rows: rows, capacity: capacity)
                let full = header + body

                // Build attributed text
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = .left
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraph
                ]
                let storage = NSTextStorage(string: full, attributes: attrs)
                let layout = NSLayoutManager()
                storage.addLayoutManager(layout)

                // First pass: build containers and collect glyph ranges per page
                var ranges: [NSRange] = []
                var consumed = 0
                while consumed < layout.numberOfGlyphs || layout.numberOfGlyphs == 0 {
                    let container = NSTextContainer(size: contentRect.size)
                    container.lineFragmentPadding = 0
                    layout.addTextContainer(container)
                    let glyphRange = layout.glyphRange(for: container)
                    if glyphRange.length == 0 { break }
                    ranges.append(glyphRange)
                    consumed = glyphRange.upperBound
                    if consumed >= layout.numberOfGlyphs { break }
                }

                // Second pass: draw each page and add page numbers
                let totalPages = max(ranges.count, 1)
                for (pageIndex, glyphRange) in ranges.enumerated() {
                    ctx.beginPDFPage(nil)
                    let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = nsctx

                    // Draw text
                    let origin = CGPoint(x: contentRect.origin.x, y: contentRect.origin.y)
                    layout.drawBackground(forGlyphRange: glyphRange, at: origin)
                    layout.drawGlyphs(forGlyphRange: glyphRange, at: origin)

                    // Footer: centered page number (e.g., "Page 1 of 5")
                    let footer = "Page \(pageIndex + 1) of \(totalPages)"
                    let footerAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: max(options.fontSize - 2, 6)),
                        .foregroundColor: NSColor.gray
                    ]
                    let footerStr = NSAttributedString(string: footer, attributes: footerAttrs)
                    let footerSize = footerStr.size()
                    let footerPoint = CGPoint(
                        x: contentRect.midX - footerSize.width / 2,
                        y: options.margin / 2 - footerSize.height / 2
                    )
                    footerStr.draw(at: footerPoint)

                    NSGraphicsContext.restoreGraphicsState()
                    ctx.endPDFPage()
                }

                ctx.closePDF()
                dashboardTrackExport()
            } catch {
                NSAlert(error: error).runModal()
                dashboardLogError(message: "PDF export failed: \(error.localizedDescription)", severity: "error")
            }
        }
    }
    
    // Overloads to accept ScannerPluginItem arrays
    static func exportCSV(rows: [ScannerPluginItem]) { exportCSV(rows: rows.map { PluginItem(
        id: $0.id,
        name: $0.name,
        publisher: $0.publisher,
        version: $0.version,
        type: $0.type,
        style: $0.style,
        architectures: $0.architectures,
        date: $0.date,
        sizeBytes: Int64($0.sizeBytes),
        path: $0.path,
        runtimeRequirement: $0.runtimeRequirement,
        obsolete: $0.obsolete
    ) }) }

    static func exportJSON(rows: [ScannerPluginItem]) { exportJSON(rows: rows.map { PluginItem(
        id: $0.id,
        name: $0.name,
        publisher: $0.publisher,
        version: $0.version,
        type: $0.type,
        style: $0.style,
        architectures: $0.architectures,
        date: $0.date,
        sizeBytes: Int64($0.sizeBytes),
        path: $0.path,
        runtimeRequirement: $0.runtimeRequirement,
        obsolete: $0.obsolete
    ) }) }

    static func exportHTML(rows: [ScannerPluginItem]) { exportHTML(rows: rows.map { PluginItem(
        id: $0.id,
        name: $0.name,
        publisher: $0.publisher,
        version: $0.version,
        type: $0.type,
        style: $0.style,
        architectures: $0.architectures,
        date: $0.date,
        sizeBytes: Int64($0.sizeBytes),
        path: $0.path,
        runtimeRequirement: $0.runtimeRequirement,
        obsolete: $0.obsolete
    ) }) }

    static func exportPDF(rows: [ScannerPluginItem], options: PDFExportOptions) { exportPDF(rows: rows.map { PluginItem(
        id: $0.id,
        name: $0.name,
        publisher: $0.publisher,
        version: $0.version,
        type: $0.type,
        style: $0.style,
        architectures: $0.architectures,
        date: $0.date,
        sizeBytes: Int64($0.sizeBytes),
        path: $0.path,
        runtimeRequirement: $0.runtimeRequirement,
        obsolete: $0.obsolete
    ) }, options: options) }

    // MARK: Save Panel
    private static func runSavePanel(suggestedName: String, allowedFileTypes: [String]) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
        } else {
            panel.allowedFileTypes = allowedFileTypes
        }
        panel.isExtensionHidden = false
        let resp = panel.runModal()
        return resp == .OK ? panel.url : nil
    }

    private static func runSavePanelAsync(suggestedName: String, allowedFileTypes: [String], completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = allowedFileTypes.compactMap { UTType(filenameExtension: $0) }
        } else {
            panel.allowedFileTypes = allowedFileTypes
        }
        panel.isExtensionHidden = false
        // Present as app-modal (not attached as a sheet) to avoid nested sheet conflicts
        panel.begin { resp in
            completion(resp == .OK ? panel.url : nil)
        }
    }

    private static func defaultFileName(prefix: String, ext: String) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "\(prefix)_\(fmt.string(from: Date())).\(ext)"
    }

    // MARK: CSV
    private static func makeCSV(rows: [PluginItem]) -> String {
        let headers = [
            "Name","Publisher","Version","Type","Style","Arch","Date","Size","Path","Requirement","Obsolete"
        ]
        let lines: [String] = [csvLine(headers)] + rows.map { r in
            csvLine([
                r.name,
                r.publisher,
                r.version,
                r.type,
                r.style,
                r.architectures,
                r.dateString,
                r.sizeString,
                r.path,
                r.runtimeRequirement,
                r.obsolete ? "Yes" : "No"
            ])
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvLine(_ fields: [String]) -> String {
        fields.map { f in
            var s = f
            s = s.replacingOccurrences(of: "\"", with: "\"\"")
            if s.contains(where: { ",\n\"".contains($0) }) {
                return "\"\(s)\""
            } else {
                return s
            }
        }.joined(separator: ",")
    }

    // MARK: JSON encoding row
    private struct JSONRow: Codable {
        let id: UUID
        let name: String
        let publisher: String
        let version: String
        let type: String
        let style: String
        let architectures: String
        let date: String
        let size: String
        let path: String
        let requirement: String
        let obsolete: Bool
        init(_ r: PluginItem) {
            id = r.id
            name = r.name
            publisher = r.publisher
            version = r.version
            type = r.type
            style = r.style
            architectures = r.architectures
            date = r.dateString
            size = r.sizeString
            path = r.path
            requirement = r.runtimeRequirement
            obsolete = r.obsolete
        }
    }

    // MARK: HTML
    private static func makeHTML(rows: [PluginItem]) -> String {
        let head = """
        <!doctype html>
        <html>
        <head>
          <meta charset=\"utf-8\">
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
          <title>Plugin Report</title>
          <style>
            body { font: 13px -apple-system, system-ui, Helvetica, Arial; color: #eee; background: #111; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border-bottom: 1px solid #333; text-align: left; padding: 6px 8px; }
            th { position: sticky; top: 0; background: #1b1b1b; }
            tr:nth-child(even) { background: #151515; }
            .obsolete { color: #ff6b6b; font-weight: 600; }
            .path { color: #9aa0a6; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
          </style>
        </head>
        <body>
        <h2>Plugin Report</h2>
        <table>
          <thead>
            <tr>
              <th>Name</th><th>Publisher</th><th>Version</th><th>Type</th><th>Style</th><th>Arch</th><th>Date</th><th>Size</th><th>Path</th><th>Requirement</th><th>Obsolete</th>
            </tr>
          </thead>
          <tbody>
        """
        let rowsHTML = rows.map { r in
            """
            <tr>
              <td>\(escapeHTML(r.name))</td>
              <td>\(escapeHTML(r.publisher))</td>
              <td>\(escapeHTML(r.version))</td>
              <td>\(escapeHTML(r.type))</td>
              <td>\(escapeHTML(r.style))</td>
              <td>\(escapeHTML(r.architectures))</td>
              <td>\(escapeHTML(r.dateString))</td>
              <td>\(escapeHTML(r.sizeString))</td>
              <td class=\"path\">\(escapeHTML(r.path))</td>
              <td>\(escapeHTML(r.runtimeRequirement))</td>
              <td class=\"\(r.obsolete ? "obsolete" : "")\">\(r.obsolete ? "Yes" : "No")</td>
            </tr>
            """
        }.joined(separator: "\n")
        let tail = """
          </tbody>
        </table>
        </body>
        </html>
        """
        return head + rowsHTML + tail
    }

    private static func escapeHTML(_ s: String) -> String {
        var out = s
        let map: [(String, String)] = [
            ("&", "&amp;"), ("\"", "&quot;"), ("'", "&#39;"), ("<", "&lt;"), (">", "&gt;")
        ]
        for (a,b) in map { out = out.replacingOccurrences(of: a, with: b) }
        return out
    }

    // MARK: PDF (simple text rendering)
    private static func makeTabularText(rows: [PluginItem], capacity: Int) -> String {
        // Columns (Path omitted to save width)
        let headers = ["Name", "Publisher", "Version", "Type", "Style", "Arch", "Date", "Size", "Requirement", "Obs"]
        let columnCount = headers.count
        let sep = "  " // two spaces between columns
        let sepWidth = (columnCount - 1) * sep.count

        // Gather content strings per column
        func cols(for i: PluginItem) -> [String] {
            [
                i.name,
                i.publisher,
                i.version,
                i.type,
                i.style,
                i.architectures,
                i.dateString,
                i.sizeString,
                i.runtimeRequirement,
                i.obsolete ? "Y" : "N"
            ]
        }

        // Desired/base widths and minimums per column (in characters)
        var widths: [Int] = [32, 20, 12, 6, 12, 14, 12, 10, 14, 3]
        let minimums: [Int] = [10, 8, 7, 3, 8, 6, 8, 5, 8, 1]

        // Clamp desired widths to actual content maxima
        var maxLens = Array(repeating: 0, count: columnCount)
        for r in rows.prefix(1000) { // sample up to 1000 rows for performance
            let c = cols(for: r)
            for i in 0..<columnCount { maxLens[i] = max(maxLens[i], c[i].count) }
        }
        for i in 0..<columnCount { widths[i] = min(widths[i], maxLens[i]) }

        // Ensure we have at least the header width
        for i in 0..<columnCount { widths[i] = max(widths[i], headers[i].count, minimums[i]) }

        // Reduce widths until total fits into capacity
        func totalWidth(_ w: [Int]) -> Int { w.reduce(0, +) + sepWidth }
        if capacity > 0 {
            let order = [0, 1, 8, 4, 5, 6, 2, 7] // columns to shrink first (Name, Publisher, Requirement, Style, Arch, Date, Version, Size)
            var guardCount = 10_000
            while totalWidth(widths) > capacity && guardCount > 0 {
                var didReduce = false
                for idx in order {
                    if widths[idx] > minimums[idx] {
                        widths[idx] -= 1
                        didReduce = true
                        if totalWidth(widths) <= capacity { break }
                    }
                }
                if !didReduce { break }
                guardCount -= 1
            }
        }

        // Padding/clip helper
        func pad(_ s: String, _ n: Int) -> String {
            if s.count == n { return s }
            if s.count < n { return s + String(repeating: " ", count: n - s.count) }
            return String(s.prefix(max(0, n - 1))) + "…"
        }

        // Build lines
        let headerLine = zip(headers, widths).map { pad($0, $1) }.joined(separator: sep)
        let rule = String(repeating: "—", count: min(headerLine.count, max(capacity, headerLine.count)))
        var body = ""
        for r in rows {
            let c = cols(for: r)
            let line = zip(c, widths).map { pad($0, $1) }.joined(separator: sep)
            body += line + "\n"
        }
        return "\(headerLine)\n\(rule)\n\(body)"
    }
}
#endif

