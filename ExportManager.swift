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
                Task { @MainActor in
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
    @MainActor
    static func exportCSV(rows: [PluginItem], ratingsManager: RatingsManager? = nil, notesManager: NotesManager? = nil) {
        let ratingsManager = ratingsManager ?? .shared
        let notesManager = notesManager ?? .shared
        let defaultName = defaultFileName(prefix: "Plugins", ext: "csv")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["csv"]) else { return }
        let csv = makeCSV(rows: rows, ratingsManager: ratingsManager, notesManager: notesManager)
        do {
            try csv.data(using: .utf8)?.write(to: url)
            dashboardTrackExport()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = UserFriendlyError.exportMessage(for: error, format: "CSV")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()

            // Log technical details for debugging
            AppLogger.error("CSV export failed: \(UserFriendlyError.technicalDetails(for: error))")
            dashboardLogError(message: "CSV export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    @MainActor
    static func exportJSON(rows: [PluginItem], ratingsManager: RatingsManager? = nil, notesManager: NotesManager? = nil) {
        let ratingsManager = ratingsManager ?? .shared
        let notesManager = notesManager ?? .shared
        let defaultName = defaultFileName(prefix: "Plugins", ext: "json")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["json"]) else { return }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonRows = rows.map { JSONRow($0, ratingsManager: ratingsManager, notesManager: notesManager) }
            let data = try enc.encode(jsonRows)
            try data.write(to: url)
            dashboardTrackExport()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = UserFriendlyError.exportMessage(for: error, format: "JSON")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()

            // Log technical details for debugging
            AppLogger.error("JSON export failed: \(UserFriendlyError.technicalDetails(for: error))")
            dashboardLogError(message: "JSON export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    @MainActor
    static func exportHTML(rows: [PluginItem], ratingsManager: RatingsManager? = nil, notesManager: NotesManager? = nil) {
        let ratingsManager = ratingsManager ?? .shared
        let notesManager = notesManager ?? .shared
        let defaultName = defaultFileName(prefix: "Plugins", ext: "html")
        guard let url = runSavePanel(suggestedName: defaultName, allowedFileTypes: ["html", "htm"]) else { return }
        let html = makeHTML(rows: rows, ratingsManager: ratingsManager, notesManager: notesManager)
        do {
            try html.data(using: .utf8)?.write(to: url)
            dashboardTrackExport()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = UserFriendlyError.exportMessage(for: error, format: "HTML")
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()

            // Log technical details for debugging
            AppLogger.error("HTML export failed: \(UserFriendlyError.technicalDetails(for: error))")
            dashboardLogError(message: "HTML export failed: \(error.localizedDescription)", severity: "error")
        }
    }

    static func exportPDF(rows: [PluginItem], options: PDFExportOptions) {
        let defaultName = defaultFileName(prefix: "Plugins", ext: "pdf")
        runSavePanelAsync(suggestedName: defaultName, allowedFileTypes: ["pdf"]) { url in
            guard let url else { return }
            Task { @MainActor in
                do {
                    var size = options.page.sizePoints
                    if options.landscape { size = CGSize(width: size.height, height: size.width) }
                    var mediaBox = CGRect(origin: .zero, size: size)
                    guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"]) }

                    let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = nsctx

                    // Use individual margins to create content rectangle
                    let contentRect = CGRect(
                        x: mediaBox.origin.x + options.leftMargin,
                        y: mediaBox.origin.y + options.bottomMargin,
                        width: mediaBox.width - (options.leftMargin + options.rightMargin),
                        height: mediaBox.height - (options.topMargin + options.bottomMargin)
                    )

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

                    // Draw text - calculate Y position so text starts at top of content area
                    // In non-flipped coordinates, Y increases upward, so we need to position at the top
                    let glyphRect = layout.usedRect(for: layout.textContainers[pageIndex])
                    let origin = CGPoint(
                        x: contentRect.origin.x,
                        y: contentRect.maxY - glyphRect.height
                    )
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
                        y: options.bottomMargin / 2 - footerSize.height / 2
                    )
                    footerStr.draw(at: footerPoint)

                    NSGraphicsContext.restoreGraphicsState()
                    ctx.endPDFPage()
                }

                    ctx.closePDF()
                    dashboardTrackExport()
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = UserFriendlyError.exportMessage(for: error, format: "PDF")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()

                    // Log technical details for debugging
                    AppLogger.error("PDF export failed: \(UserFriendlyError.technicalDetails(for: error))")
                    dashboardLogError(message: "PDF export failed: \(error.localizedDescription)", severity: "error")
                }
            }
        }
    }
    
    // Overloads to accept ScannerPluginItem arrays
    @MainActor
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

    @MainActor
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

    @MainActor
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
    @MainActor
    private static func makeCSV(rows: [PluginItem], ratingsManager: RatingsManager, notesManager: NotesManager) -> String {
        // Column order matches plugin listing: Rating, Name, Publisher, Type, Style, Version, License, Arch, Date, Size, Requirement, Obsolete, Missing, Track, Notes, Path
        let headers = [
            "Rating","Name","Publisher","Type","Style","Version","License","Arch","Date","Size","Requirement","Obsolete","Missing","Track","Notes","Path"
        ]
        let metadataManager = MetadataManager.shared
        let lines: [String] = [csvLine(headers)] + rows.map { r in
            let rating = ratingsManager.getRating(for: r.path)
            let ratingStr = rating > 0 ? String(repeating: "★", count: rating) : ""
            let note = notesManager.getNote(for: r.path)
            let license = getLicenseType(for: r)

            return csvLine([
                ratingStr,
                r.name,
                metadataManager.getDisplayPublisher(for: r),
                r.type,
                metadataManager.getDisplayStyle(for: r),
                metadataManager.getDisplayVersion(for: r),
                license,
                r.architectures,
                r.dateString,
                r.sizeString,
                r.runtimeRequirement,
                r.obsolete ? "Yes" : "No",
                r.missing ? "Yes" : "No",
                r.trackName ?? "",
                note,
                r.path
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
        // Column order matches plugin listing: Rating, Name, Publisher, Type, Style, Version, License, Arch, Date, Size, Requirement, Obsolete, Missing, Track, Notes, Path
        let rating: Int
        let name: String
        let publisher: String
        let type: String
        let style: String
        let version: String
        let license: String
        let architectures: String
        let date: String
        let size: String
        let requirement: String
        let obsolete: Bool
        let missing: Bool
        let track: String?
        let notes: String
        let path: String

        @MainActor
        init(_ r: PluginItem, ratingsManager: RatingsManager, notesManager: NotesManager) {
            let metadataManager = MetadataManager.shared
            id = r.id
            rating = ratingsManager.getRating(for: r.path)
            name = r.name
            publisher = metadataManager.getDisplayPublisher(for: r)
            type = r.type
            style = metadataManager.getDisplayStyle(for: r)
            version = metadataManager.getDisplayVersion(for: r)
            license = getLicenseType(for: r)
            architectures = r.architectures
            date = r.dateString
            size = r.sizeString
            requirement = r.runtimeRequirement
            obsolete = r.obsolete
            missing = r.missing
            track = r.trackName
            notes = notesManager.getNote(for: r.path)
            path = r.path
        }
    }

    // MARK: HTML
    @MainActor
    private static func makeHTML(rows: [PluginItem], ratingsManager: RatingsManager, notesManager: NotesManager) -> String {
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
            th, td { border-bottom: 1px solid #333; text-align: left; padding: 6px 8px; white-space: nowrap; }
            th { position: sticky; top: 0; background: #1b1b1b; }
            tr:nth-child(even) { background: #151515; }
            .obsolete { color: #ff6b6b; font-weight: 600; }
            .missing { color: #ffa500; font-weight: 600; }
            .path { color: #9aa0a6; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
            .notes { max-width: 300px; white-space: normal; }
            .rating { color: #ffd700; }
          </style>
        </head>
        <body>
        <h2>Plugin Report</h2>
        <table>
          <thead>
            <tr>
              <th>Rating</th><th>Name</th><th>Publisher</th><th>Type</th><th>Style</th><th>Version</th><th>License</th><th>Arch</th><th>Date</th><th>Size</th><th>Requirement</th><th>Obsolete</th><th>Missing</th><th>Track</th><th>Notes</th><th>Path</th>
            </tr>
          </thead>
          <tbody>
        """
        let metadataManager = MetadataManager.shared
        let rowsHTML = rows.map { r in
            let rating = ratingsManager.getRating(for: r.path)
            let ratingStr = rating > 0 ? String(repeating: "★", count: rating) : ""
            let note = notesManager.getNote(for: r.path)
            let license = getLicenseType(for: r)

            return """
            <tr>
              <td class=\"rating\">\(escapeHTML(ratingStr))</td>
              <td>\(escapeHTML(r.name))</td>
              <td>\(escapeHTML(metadataManager.getDisplayPublisher(for: r)))</td>
              <td>\(escapeHTML(r.type))</td>
              <td>\(escapeHTML(metadataManager.getDisplayStyle(for: r)))</td>
              <td>\(escapeHTML(metadataManager.getDisplayVersion(for: r)))</td>
              <td>\(escapeHTML(license))</td>
              <td>\(escapeHTML(r.architectures))</td>
              <td>\(escapeHTML(r.dateString))</td>
              <td>\(escapeHTML(r.sizeString))</td>
              <td>\(escapeHTML(r.runtimeRequirement))</td>
              <td class=\"\(r.obsolete ? "obsolete" : "")\">\(r.obsolete ? "Yes" : "No")</td>
              <td class=\"\(r.missing ? "missing" : "")\">\(r.missing ? "Yes" : "No")</td>
              <td>\(escapeHTML(r.trackName ?? ""))</td>
              <td class=\"notes\">\(escapeHTML(note))</td>
              <td class=\"path\">\(escapeHTML(r.path))</td>
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

    // MARK: License Type Helper
    @MainActor
    private static func getLicenseType(for plugin: PluginItem) -> String {
        let pluginID = "\(plugin.publisher.lowercased())_\(plugin.name.lowercased())"
            .replacingOccurrences(of: " ", with: "_")

        if let license = LicenseManager.shared.getLicense(for: pluginID) {
            // Check if it mentions iLok anywhere (imported from iLok)
            if let notes = license.notes?.lowercased(), notes.contains("ilok") {
                return "iLok"
            }
            if let activationCode = license.activationCode?.lowercased(), activationCode.contains("ilok") {
                return "iLok"
            }
            // Check if it has a serial number or license key
            if license.serialNumber?.isEmpty == false || license.licenseKey?.isEmpty == false {
                return "Serial"
            }
            // If we have a license entry but no specific data, still show something was imported
            if license.notes?.isEmpty == false {
                return "iLok"  // Default to iLok if we have notes but no serial
            }
        }
        return ""
    }

    // MARK: PDF (simple text rendering)
    @MainActor
    private static func makeTabularText(rows: [PluginItem], capacity: Int) -> String {
        // All columns in correct order matching table display
        let headers = ["Rating", "Name", "Publisher", "Type", "Style", "Version", "License", "Arch", "Date", "Size", "Requirement", "Obsolete", "Missing", "Track", "Notes", "Path"]
        let columnCount = headers.count
        let sep = "  " // two spaces between columns
        let sepWidth = (columnCount - 1) * sep.count

        // Get managers for rating and notes
        let ratingsManager = RatingsManager.shared
        let notesManager = NotesManager.shared

        // Gather content strings per column
        let metadataManager = MetadataManager.shared
        func cols(for i: PluginItem) -> [String] {
            let rating = ratingsManager.getRating(for: i.path)
            let ratingStr = rating > 0 ? String(repeating: "★", count: rating) : ""
            let note = notesManager.getNote(for: i.path)
            let license = getLicenseType(for: i)

            return [
                ratingStr,
                i.name,
                metadataManager.getDisplayPublisher(for: i),
                i.type,
                metadataManager.getDisplayStyle(for: i),
                metadataManager.getDisplayVersion(for: i),
                license,
                i.architectures,
                i.dateString,
                i.sizeString,
                i.runtimeRequirement,
                i.obsolete ? "Y" : "N",
                i.missing ? "Y" : "N",
                i.trackName ?? "",
                note,
                i.path
            ]
        }

        // Maximum desired widths (what we'd use if we had infinite space)
        let maxDesired: [Int] = [6, 35, 20, 5, 15, 12, 8, 16, 12, 10, 16, 3, 3, 18, 20, 60]
        let minimums: [Int] = [4, 8, 6, 3, 6, 5, 5, 8, 8, 4, 8, 1, 1, 5, 5, 10]

        // First, measure actual content
        var maxLens = Array(repeating: 0, count: columnCount)
        for r in rows.prefix(1000) { // sample up to 1000 rows for performance
            let c = cols(for: r)
            for i in 0..<columnCount { maxLens[i] = max(maxLens[i], c[i].count) }
        }

        // Start with content-based widths, capped at max desired
        var widths: [Int] = maxLens.enumerated().map { idx, len in
            max(min(len, maxDesired[idx]), headers[idx].count, minimums[idx])
        }

        func totalWidth(_ w: [Int]) -> Int { w.reduce(0, +) + sepWidth }

        if capacity > 0 {
            // First, shrink to fit if needed
            if totalWidth(widths) > capacity {
                // Shrink columns in this priority order (less important first):
                // Notes(13), Track(12), Publisher(2), Name(1), Requirement(9), Style(4), Arch(6), Date(7), Size(8), Path(14)
                let shrinkOrder = [13, 12, 2, 1, 9, 4, 6, 7, 8, 14]
                var guardCount = 10_000
                while totalWidth(widths) > capacity && guardCount > 0 {
                    var didReduce = false
                    for idx in shrinkOrder {
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

            // Then, expand to use available space (prioritize important columns)
            // Expand order: Path(14), Name(1), Publisher(2), Notes(13), Requirement(9), Style(4), Track(12), Arch(6)
            let expandOrder = [14, 1, 2, 13, 9, 4, 12, 6]
            var guardCount = 10_000
            while totalWidth(widths) < capacity && guardCount > 0 {
                var didExpand = false
                for idx in expandOrder {
                    if widths[idx] < maxDesired[idx] && widths[idx] < maxLens[idx] {
                        let available = capacity - totalWidth(widths)
                        if available > 0 {
                            widths[idx] += 1
                            didExpand = true
                            if totalWidth(widths) >= capacity { break }
                        }
                    }
                }
                if !didExpand { break }
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

