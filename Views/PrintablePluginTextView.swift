//
//  PrintablePluginTextView.swift
//  Plugin Reporter
//
//  Custom NSView for printing with proper text rendering
//  Extracted from PluginReporterApp.swift
//

import SwiftUI
#if os(macOS)
import AppKit

/// Custom NSView for printing with proper text rendering
class PrintablePluginTextView: NSView {
    var textStorage: NSTextStorage?
    var layoutManager: NSLayoutManager?
    var leftMargin: CGFloat = 18
    var rightMargin: CGFloat = 18
    var topMargin: CGFloat = 18
    var bottomMargin: CGFloat = 18

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw white background
        NSColor.white.setFill()
        dirtyRect.fill()

        // Draw text
        guard let layoutManager = layoutManager,
              let textContainer = layoutManager.textContainers.first else { return }

        let origin = CGPoint(x: leftMargin, y: topMargin)
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

        let totalHeight = usedRect.height + topMargin + bottomMargin
        let pageCount = Int(ceil(totalHeight / pageHeight))

        range.pointee = NSRange(location: 1, length: pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        let printInfo = NSPrintInfo.shared
        let pageHeight = printInfo.paperSize.height
        let pageWidth = printInfo.paperSize.width

        // Account for bottom margin by reducing the effective page height
        // This ensures content doesn't draw into the bottom margin area
        let effectivePageHeight = pageHeight - bottomMargin

        let yOffset = CGFloat(page - 1) * pageHeight
        return NSRect(x: 0, y: yOffset, width: pageWidth, height: effectivePageHeight)
    }
}
#endif
