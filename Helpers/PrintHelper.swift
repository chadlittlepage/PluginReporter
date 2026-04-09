//
//  PrintHelper.swift
//  Plugin Reporter
//
//  Print-related helper functions for creating printable plugin views
//  Extracted from PluginReporterApp.swift
//

import SwiftUI
#if os(macOS)
import AppKit

// MARK: - Print Helper

/// Create a printable NSView with the plugin table
@MainActor
func createPrintablePluginView(plugins: [PluginItem], preferences: Preferences) -> NSView {
    // NSPrintInfo should already be configured by the caller
    let printInfo = NSPrintInfo.shared

    let pageWidth = printInfo.paperSize.width
    let pageHeight = printInfo.paperSize.height

    // Use margins from NSPrintInfo (which were set from preferences)
    let leftMargin = printInfo.leftMargin
    let rightMargin = printInfo.rightMargin
    let topMargin = printInfo.topMargin
    let bottomMargin = printInfo.bottomMargin

    // Calculate content area
    let contentWidth = pageWidth - leftMargin - rightMargin

    // Create text container
    let fontSize = preferences.pdfFontSize
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

    // Build text content with header
    let reportTitle = "Plugin Report - \(plugins.count) plugins"
    let separator = String(repeating: "=", count: min(80, Int(contentWidth / (fontSize * 0.6))))

    let header = """
    \(reportTitle)
    \(separator)

    """

    let tableText = buildPrintTableText(plugins: plugins, width: contentWidth, fontSize: fontSize, preferences: preferences)
    let fullText = header + tableText

    // Create attributed string
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.alignment = .left

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraphStyle
    ]

    let attributedString = NSAttributedString(string: fullText, attributes: attributes)

    // Create text storage and layout manager
    let textStorage = NSTextStorage(attributedString: attributedString)
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)

    // Create text container
    let containerSize = CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
    let textContainer = NSTextContainer(size: containerSize)
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)

    // Force layout
    layoutManager.glyphRange(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)

    // Create custom view
    let view = PrintablePluginTextView(frame: NSRect(origin: .zero, size: CGSize(width: pageWidth, height: max(pageHeight, usedRect.height + topMargin + bottomMargin))))
    view.textStorage = textStorage
    view.layoutManager = layoutManager
    view.leftMargin = leftMargin
    view.topMargin = topMargin
    view.rightMargin = rightMargin
    view.bottomMargin = bottomMargin

    return view
}

/// Get license type for a plugin
@MainActor
func getLicenseType(for plugin: PluginItem) -> String {
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

/// Build formatted table text for printing (matches ExportManager implementation)
@MainActor
func buildPrintTableText(plugins: [PluginItem], width: CGFloat, fontSize: CGFloat, preferences: Preferences) -> String {
    // Calculate character capacity using ACTUAL font metrics (same as PageSetupView)
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    let charWidth = font.maximumAdvancement.width
    let capacity = Int(width / charWidth)

    // Get managers for rating, notes, and metadata
    let ratingsManager = RatingsManager.shared
    let notesManager = NotesManager.shared
    let metadataManager = MetadataManager.shared

    // Define column information structure
    struct ColumnInfo {
        let header: String
        let maxDesired: Int
        let minimum: Int
        let extractor: (PluginItem, RatingsManager, NotesManager) -> String
    }

    // Build columns array based on preferences
    var columns: [ColumnInfo] = []

    if preferences.pdfShowRating {
        columns.append(ColumnInfo(header: "Rating", maxDesired: 6, minimum: 4) { item, ratings, _ in
            let rating = ratings.getRating(for: item.path)
            return rating > 0 ? String(repeating: "★", count: rating) : ""
        })
    }
    if preferences.pdfShowName {
        columns.append(ColumnInfo(header: "Name", maxDesired: 35, minimum: 8) { item, _, _ in item.name })
    }
    if preferences.pdfShowPublisher {
        columns.append(ColumnInfo(header: "Publisher", maxDesired: 20, minimum: 6) { item, _, _ in metadataManager.getDisplayPublisher(for: item) })
    }
    if preferences.pdfShowType {
        columns.append(ColumnInfo(header: "Type", maxDesired: 5, minimum: 3) { item, _, _ in item.type })
    }
    if preferences.pdfShowStyle {
        columns.append(ColumnInfo(header: "Style", maxDesired: 15, minimum: 6) { item, _, _ in metadataManager.getDisplayStyle(for: item) })
    }
    if preferences.pdfShowVersion {
        columns.append(ColumnInfo(header: "Version", maxDesired: 12, minimum: 5) { item, _, _ in metadataManager.getDisplayVersion(for: item) })
    }
    if preferences.pdfShowLicense {
        columns.append(ColumnInfo(header: "License", maxDesired: 8, minimum: 5) { item, _, _ in getLicenseType(for: item) })
    }
    if preferences.pdfShowArch {
        columns.append(ColumnInfo(header: "Preset", maxDesired: 16, minimum: 8) { item, _, _ in item.preset })
    }
    if preferences.pdfShowDate {
        columns.append(ColumnInfo(header: "Date", maxDesired: 12, minimum: 8) { item, _, _ in item.dateString })
    }
    if preferences.pdfShowSize {
        columns.append(ColumnInfo(header: "Size", maxDesired: 10, minimum: 4) { item, _, _ in item.sizeString })
    }
    if preferences.pdfShowRequirement {
        columns.append(ColumnInfo(header: "Requirement", maxDesired: 16, minimum: 8) { item, _, _ in item.runtimeRequirement })
    }
    if preferences.pdfShowObsolete {
        columns.append(ColumnInfo(header: "Obsolete", maxDesired: 3, minimum: 1) { item, _, _ in item.obsolete ? "Y" : "N" })
    }
    if preferences.pdfShowMissing {
        columns.append(ColumnInfo(header: "Missing", maxDesired: 3, minimum: 1) { item, _, _ in item.missing ? "Y" : "N" })
    }
    if preferences.pdfShowTrack {
        columns.append(ColumnInfo(header: "Track", maxDesired: 18, minimum: 5) { item, _, _ in item.trackName ?? "" })
    }
    if preferences.pdfShowNotes {
        columns.append(ColumnInfo(header: "Notes", maxDesired: 20, minimum: 5) { item, _, notes in notes.getNote(for: item.path) })
    }
    if preferences.pdfShowPath {
        columns.append(ColumnInfo(header: "Path", maxDesired: 60, minimum: 10) { item, _, _ in item.path })
    }

    let columnCount = columns.count
    guard columnCount > 0 else {
        return "No columns selected for export"
    }

    let sep = "  " // two spaces between columns
    let sepWidth = (columnCount - 1) * sep.count

    // Extract headers and configuration
    let headers = columns.map { $0.header }
    let maxDesired = columns.map { $0.maxDesired }
    let minimums = columns.map { $0.minimum }

    // Gather content strings per column
    func cols(for item: PluginItem) -> [String] {
        return columns.map { $0.extractor(item, ratingsManager, notesManager) }
    }

    // First, measure actual content
    var maxLens = Array(repeating: 0, count: columnCount)
    for r in plugins.prefix(1000) { // sample up to 1000 rows for performance
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
            // Shrink all columns proportionally from largest to smallest
            var guardCount = 10_000
            while totalWidth(widths) > capacity && guardCount > 0 {
                var didReduce = false
                // Find the column with most room to shrink
                for idx in 0..<columnCount {
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

        // Then, expand to use available space
        // Phase 1: Expand columns up to their maxDesired width
        var guardCount = 10_000
        while totalWidth(widths) < capacity && guardCount > 0 {
            var didExpand = false
            for idx in 0..<columnCount {
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

        // Phase 2: If there's still space, expand columns beyond maxDesired (prioritize wider columns)
        guardCount = 10_000
        while totalWidth(widths) < capacity && guardCount > 0 {
            var didExpand = false
            for idx in 0..<columnCount {
                // Allow expansion beyond maxDesired if content needs it
                if widths[idx] < maxLens[idx] {
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

        // Phase 3: Distribute remaining space to columns, with reasonable limits
        // Cap Name column at 30 chars to prevent excessive expansion in wide layouts
        let reasonableLimits = maxLens.enumerated().map { idx, maxLen in
            if headers[idx] == "Name" {
                return min(maxLen, 30)
            }
            return maxLen
        }

        var guardCount3 = 10_000
        while totalWidth(widths) < capacity && guardCount3 > 0 {
            var didExpand = false

            // Find columns that still have content to show (using reasonable limits)
            var needyColumns: [(index: Int, need: Int)] = []
            for idx in 0..<columnCount {
                let need = reasonableLimits[idx] - widths[idx]
                if need > 0 {
                    needyColumns.append((idx, need))
                }
            }

            // If no columns need more space, we're done
            if needyColumns.isEmpty {
                break
            }

            // Distribute remaining space among needy columns
            let remainingSpace = capacity - totalWidth(widths)
            if remainingSpace <= 0 {
                break
            }

            // Give each needy column 1 character worth of space in rotation
            for (idx, _) in needyColumns {
                if totalWidth(widths) >= capacity { break }
                widths[idx] += 1
                didExpand = true
            }

            if !didExpand { break }
            guardCount3 -= 1
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
    for r in plugins {
        let c = cols(for: r)
        let line = zip(c, widths).map { pad($0, $1) }.joined(separator: sep)
        body += line + "\n"
    }
    return "\(headerLine)\n\(rule)\n\(body)"
}

/// Show custom Page Setup dialog with live preview
func showCustomPageSetup(preferences: Preferences, plugins: [PluginItem]) {
    let pageSetupView = PageSetupView(preferences: preferences, plugins: plugins)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Page Setup"
    window.contentView = NSHostingView(rootView: pageSetupView)
    window.minSize = NSSize(width: 880, height: 640)
    window.maxSize = NSSize(width: 2000, height: 1400)
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.isReleasedWhenClosed = false
}

/// Quick export to PDF using current Page Setup settings
func quickExportPDF(plugins: [PluginItem], preferences: Preferences) {
    // Configure printInfo from preferences
    let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo

    var pageSize = preferences.pdfPage.sizePoints
    if preferences.pdfLandscape {
        pageSize = CGSize(width: pageSize.height, height: pageSize.width)
    }
    printInfo.paperSize = pageSize
    printInfo.orientation = preferences.pdfLandscape ? .landscape : .portrait
    printInfo.leftMargin = preferences.pdfLeftMargin
    printInfo.rightMargin = preferences.pdfRightMargin
    printInfo.topMargin = preferences.pdfTopMargin
    printInfo.bottomMargin = preferences.pdfBottomMargin

    // CRITICAL: Also update the shared instance so createPrintablePluginView uses correct settings
    NSPrintInfo.shared.paperSize = pageSize
    NSPrintInfo.shared.orientation = preferences.pdfLandscape ? .landscape : .portrait
    NSPrintInfo.shared.leftMargin = preferences.pdfLeftMargin
    NSPrintInfo.shared.rightMargin = preferences.pdfRightMargin
    NSPrintInfo.shared.topMargin = preferences.pdfTopMargin
    NSPrintInfo.shared.bottomMargin = preferences.pdfBottomMargin

    // Generate filename with timestamp
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())
    let defaultName = "Plugins_\(timestamp).pdf"

    // Show save panel
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = defaultName
    savePanel.allowedContentTypes = [.pdf]
    savePanel.canCreateDirectories = true

    savePanel.begin { response in
        guard response == .OK, let url = savePanel.url else { return }

        Task { @MainActor in
            // Create printable view (uses NSPrintInfo.shared)
            let printView = createPrintablePluginView(plugins: plugins, preferences: preferences)

            // Configure print info for PDF output
            printInfo.jobDisposition = .save
            printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

            // Create print operation for PDF export
            let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false

            // Run the print operation to generate PDF
            printOperation.run()

            dashboardTrackExport()
        }
    }
}
#endif
