//
//  PDFExporter.swift — FULL REPLACEMENT
//  Renders a simple monospaced table and writes it directly to a PDF file.
//
import Foundation
import AppKit

/// Writes the current plugin list to a PDF file.
enum PDFExporter {

    /// Export rows to a PDF.
    /// - Parameters:
    ///   - rows: Plugins to export.
    ///   - url: Destination URL (e.g. chosen from NSSavePanel).
    ///   - landscape: When true, rotates the page to landscape for wider tables.
    static func write(rows: [PluginItem], to url: URL, landscape: Bool = true) {
        // 1) Build the monospaced text table
        let text = buildTableText(from: rows)

        // 2) Lay text into an NSTextView so we can capture a PDF of its contents
        let pageWidth: CGFloat  = landscape ? 842 : 595   // A4: 595x842 pt
        let pageHeight: CGFloat = landscape ? 595 : 842
        let pageInset = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        let textContainerSize = NSSize(width: pageWidth - pageInset.left - pageInset.right,
                                       height: .greatestFiniteMagnitude)

        let storage = NSTextStorage(string: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: textContainerSize)
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let textViewFrame = NSRect(x: 0, y: 0, width: textContainerSize.width, height: 10_000)
        let textView = NSTextView(frame: textViewFrame, textContainer: container)
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.isEditable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textColor = .black

        let mono = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.font = mono

        // Size the view vertically to fit all content
        textView.sizeToFit()
        let fittedHeight = layout.usedRect(for: container).height
        let totalHeight = max(fittedHeight, pageHeight - pageInset.top - pageInset.bottom)

        // Wrap in a container view that represents a single PDF page (white background)
        let pageBounds = NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let hosting = NSView(frame: pageBounds)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.white.cgColor

        // Position the textView inside page insets (top-left origin is bottom-left, so flip)
        let textFrame = NSRect(x: pageInset.left,
                               y: pageHeight - pageInset.top - totalHeight,
                               width: textContainerSize.width,
                               height: totalHeight)
        textView.frame = textFrame
        hosting.addSubview(textView)

        // 3) Capture PDF and write
        let pdfData = hosting.dataWithPDF(inside: hosting.bounds)
        do {
            try pdfData.write(to: url, options: .atomic)
        } catch {
            AppLogger.export.error("PDF export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Table builder

    /// Produces a simple monospaced table string (header + rows).
    private static func buildTableText(from rows: [PluginItem]) -> String {
        // Column titles (no Path column)
        let header = [
            "Name", "Publisher", "Version", "Type", "Style",
            "Architectures", "Date", "Size",
            "Requirement", "Obsolete"
        ]

        // NOTE: These widths are tuned for A4 landscape with 11pt mono & 24pt margins.
        // Adjust if your table gets too tight.
        var widths = [
            32, // Name
            18, // Publisher
            10, // Version
            8,  // Type
            12, // Style
            20, // Architectures
            12, // Date
            10, // Size
            14, // Requirement
            8   // Obsolete
        ]

        // Helper to pad/clip a string to a fixed width
        func pad(_ s: String, _ n: Int) -> String {
            if s.count == n { return s }
            if s.count < n { return s + String(repeating: " ", count: n - s.count) }
            // clip with ellipsis
            return String(s.prefix(max(0, n - 1))) + "…"
        }

        // Convert one row to column strings (using convenience columns on PluginItem)
        // Note: Path column removed per user request
        func columns(for i: PluginItem) -> [String] {
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
                i.obsolete ? "Yes" : "No"
            ]
        }

        // Optionally let content stretch some columns: compute max width we actually need,
        // then clamp to our configured width to avoid overflowing the page.
        for row in rows {
            let cols = columns(for: row)
            for (idx, str) in cols.enumerated() {
                widths[idx] = min(max(widths[idx], str.count), widths[idx])
            }
        }

        // Build lines
        let sep = "  " // two spaces between columns
        let title = "Plugin Reporter"
        let headerLine = zip(header, widths).map { pad($0, $1) }.joined(separator: sep)
        let rule = String(repeating: "—", count: headerLine.count)

        var body = ""
        for row in rows {
            let cols = columns(for: row)
            let line = zip(cols, widths).map { pad($0, $1) }.joined(separator: sep)
            body += line + "\n"
        }

        return """
        \(title)
        \(headerLine)
        \(rule)
        \(body)
        """
    }
}
