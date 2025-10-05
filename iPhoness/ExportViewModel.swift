//
//  ExportViewModel.swift
//  PluginReporter (iOS)
//
//  ViewModel for export operations - handles CSV and PDF generation
//

import SwiftUI
import Combine

@MainActor
class ExportViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var showShareSheet = false
    @Published var exportURL: URL?
    @Published var isExporting = false
    @Published var lastError: Error?

    // MARK: - Input

    private(set) var plugins: [PluginItem]

    // MARK: - Initialization

    init(plugins: [PluginItem] = []) {
        self.plugins = plugins
    }

    func updatePlugins(_ newPlugins: [PluginItem]) {
        self.plugins = newPlugins
    }

    // MARK: - Export Operations

    func exportCSV() {
        isExporting = true
        lastError = nil

        guard let url = generateCSV() else {
            isExporting = false
            return
        }

        exportURL = url
        showShareSheet = true
        isExporting = false
    }

    func exportPDF() {
        isExporting = true
        lastError = nil

        guard let url = generatePDF() else {
            isExporting = false
            return
        }

        exportURL = url
        showShareSheet = true
        isExporting = false
    }

    // MARK: - CSV Generation

    private func generateCSV() -> URL? {
        // Optimize string building for large datasets
        var lines = [String]()
        lines.reserveCapacity(plugins.count + 1)

        // Header
        lines.append("Name,Publisher,Type,Style,Version,Architecture,Size,Obsolete")

        // Data rows
        for plugin in plugins {
            let name = plugin.name.escapedForCSV()
            let publisher = plugin.publisher.escapedForCSV()
            let type = plugin.type
            let style = plugin.style.escapedForCSV()
            let version = plugin.version.escapedForCSV()
            let arch = plugin.architectures.escapedForCSV()
            let size = plugin.displaySize
            let obsolete = plugin.obsolete ? "Yes" : "No"

            lines.append("\(name),\(publisher),\(type),\(style),\(version),\(arch),\(size),\(obsolete)")
        }

        let csv = lines.joined(separator: "\n")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Constants.FilePaths.csvExportFileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            lastError = error
            AppLogger.error("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - PDF Generation

    private func generatePDF() -> URL? {
        let pdfMetaData = [
            kCGPDFContextTitle: "Plugin List",
            kCGPDFContextAuthor: "Plugin Reporter"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: Constants.PDF.pageWidth,
            height: Constants.PDF.pageHeight
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let titleFont = UIFont.boldSystemFont(ofSize: Constants.PDF.titleFontSize)
            let headerFont = UIFont.boldSystemFont(ofSize: Constants.PDF.headerFontSize)
            let bodyFont = UIFont.systemFont(ofSize: Constants.PDF.bodyFontSize)

            var yPosition: CGFloat = Constants.PDF.pageMargin

            // Title
            let title = "Plugin List (\(plugins.count) plugins)"
            let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
            title.draw(at: CGPoint(x: Constants.PDF.pageMargin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40

            // Headers
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
            "Name".draw(at: CGPoint(x: Constants.PDF.pageMargin, y: yPosition), withAttributes: headerAttributes)
            "Publisher".draw(at: CGPoint(x: Constants.PDF.pageMargin + 200, y: yPosition), withAttributes: headerAttributes)
            "Type".draw(at: CGPoint(x: Constants.PDF.pageMargin + 350, y: yPosition), withAttributes: headerAttributes)
            "Style".draw(at: CGPoint(x: Constants.PDF.pageMargin + 400, y: yPosition), withAttributes: headerAttributes)
            yPosition += 20

            let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]

            for plugin in plugins {
                // Check if we need a new page
                if yPosition > Constants.PDF.pageHeight - Constants.PDF.pageMargin {
                    context.beginPage()
                    yPosition = Constants.PDF.pageMargin
                }

                plugin.name.draw(at: CGPoint(x: Constants.PDF.pageMargin, y: yPosition), withAttributes: bodyAttributes)
                plugin.publisher.draw(at: CGPoint(x: Constants.PDF.pageMargin + 200, y: yPosition), withAttributes: bodyAttributes)
                plugin.type.draw(at: CGPoint(x: Constants.PDF.pageMargin + 350, y: yPosition), withAttributes: bodyAttributes)
                plugin.style.draw(at: CGPoint(x: Constants.PDF.pageMargin + 400, y: yPosition), withAttributes: bodyAttributes)

                yPosition += Constants.PDF.lineSpacing
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Constants.FilePaths.pdfExportFileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            lastError = error
            AppLogger.error("Failed to write PDF: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - String Extension for CSV Escaping

private extension String {
    func escapedForCSV() -> String {
        replacingOccurrences(of: ",", with: ";")
    }
}
