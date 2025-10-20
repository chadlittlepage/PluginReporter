//
//  PrintHelper.swift
//  PluginReporter
//
//  Helpers for printing plugin tables with vector text rendering
//

#if os(macOS)
import AppKit
import SwiftUI

class PrintHelper {
    /// Create a printable NSView with the plugin table
    static func createPrintableView(plugins: [PluginItem], preferences: Preferences) -> NSView {
        let printInfo = NSPrintInfo.shared
        let pageWidth = printInfo.paperSize.width
        let pageHeight = printInfo.paperSize.height
        let margin = preferences.pdfMargin

        // Calculate content area
        let contentWidth = pageWidth - (margin * 2)
        let contentHeight = pageHeight - (margin * 2)

        // Create text container
        let fontSize = preferences.pdfFontSize
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Build text content
        let header = "Plugin Report - \(plugins.count) plugins\n\n"
        let tableText = buildTableText(plugins: plugins, width: contentWidth, fontSize: fontSize)
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
        let view = PrintableTextView(frame: NSRect(origin: .zero, size: CGSize(width: pageWidth, height: max(pageHeight, usedRect.height + margin * 2))))
        view.textStorage = textStorage
        view.layoutManager = layoutManager
        view.margin = margin

        return view
    }

    /// Build formatted table text
    private static func buildTableText(plugins: [PluginItem], width: CGFloat, fontSize: CGFloat) -> String {
        // Calculate character capacity
        let charWidth = fontSize * 0.6
        let capacity = Int(width / charWidth)

        // Column headers
        let headers = ["Name", "Publisher", "Type", "Style", "Version", "Arch"]

        // Calculate column widths
        var widths = [30, 20, 6, 15, 10, 12]  // Base widths
        let totalBase = widths.reduce(0, +) + (headers.count - 1) * 2  // Include separators

        // Adjust if needed
        if totalBase > capacity {
            let scale = Double(capacity) / Double(totalBase)
            widths = widths.map { max(4, Int(Double($0) * scale)) }
        }

        // Build header line
        var result = ""
        result += pad(headers[0], widths[0]) + "  "
        result += pad(headers[1], widths[1]) + "  "
        result += pad(headers[2], widths[2]) + "  "
        result += pad(headers[3], widths[3]) + "  "
        result += pad(headers[4], widths[4]) + "  "
        result += pad(headers[5], widths[5]) + "\n"

        // Separator line
        result += String(repeating: "─", count: min(capacity, result.count)) + "\n"

        // Data rows
        for plugin in plugins {
            result += pad(plugin.name, widths[0]) + "  "
            result += pad(plugin.publisher, widths[1]) + "  "
            result += pad(plugin.type, widths[2]) + "  "
            result += pad(plugin.style, widths[3]) + "  "
            result += pad(plugin.version, widths[4]) + "  "
            result += pad(plugin.architectures, widths[5]) + "\n"
        }

        return result
    }

    /// Pad or truncate string to width
    private static func pad(_ text: String, _ width: Int) -> String {
        if text.count == width { return text }
        if text.count > width {
            return String(text.prefix(max(0, width - 1))) + "…"
        }
        return text + String(repeating: " ", count: width - text.count)
    }
}

/// Custom NSView for printing with proper text rendering
class PrintableTextView: NSView {
    var textStorage: NSTextStorage?
    var layoutManager: NSLayoutManager?
    var margin: CGFloat = 40

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw white background
        NSColor.white.setFill()
        dirtyRect.fill()

        // Draw text
        guard let layoutManager = layoutManager,
              let textContainer = layoutManager.textContainers.first else { return }

        let origin = CGPoint(x: margin, y: margin)
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        guard let layoutManager = layoutManager,
              let textContainer = layoutManager.textContainers.first else { return false }

        let usedRect = layoutManager.usedRect(for: textContainer)
        let printInfo = NSPrintInfo.shared
        let pageHeight = printInfo.paperSize.height

        let totalHeight = usedRect.height + margin * 2
        let pageCount = Int(ceil(totalHeight / pageHeight))

        range.pointee = NSRange(location: 1, length: pageCount)
        return true
    }

    override func rect(forPage page: Int) -> NSRect {
        let printInfo = NSPrintInfo.shared
        let pageHeight = printInfo.paperSize.height
        let pageWidth = printInfo.paperSize.width

        let yOffset = CGFloat(page - 1) * pageHeight
        return NSRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight)
    }
}
#endif
