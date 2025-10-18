//
//  ExportView.swift
//  PluginReporter (iOS)
//
//  Export view for CSV and PDF generation
//

import SwiftUI
import Combine

struct ExportView: View {
    let plugins: [PluginItem]
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @AppStorage("appearance") private var appearance: String = "space"

    // Pre-computed colors
    private let spaceBackground = Color.black
    private let darkBackground = Color(red: 28/255, green: 28/255, blue: 30/255)
    private let lightBackground = Color(red: 242/255, green: 242/255, blue: 247/255)

    var customBackgroundColor: Color {
        appearance == "space" ? spaceBackground : appearance == "dark" ? darkBackground : appearance == "light" ? lightBackground : Color(UIColor.systemBackground)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Plugins to Export")
                        Spacer()
                        Text("\(plugins.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Export Summary")
                }

                Section {
                    Button(action: {
                        if let url = generateCSV() {
                            exportURL = url
                            showShareSheet = true
                        }
                    }) {
                        Label("Export as CSV", systemImage: "doc.text")
                    }
                    .accessibilityHint("Export plugin list as CSV file")

                    Text("Export plugin list as comma-separated values file.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button(action: {
                        if let url = generatePDF() {
                            exportURL = url
                            showShareSheet = true
                        }
                    }) {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    .accessibilityHint("Export plugin list as PDF file")

                    Text("Export plugin list as formatted PDF document.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Export Options")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Information")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("The export will include only the plugins currently visible on the Plugins tab. Use search and filters to customize what gets exported.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About Export")
                }
            }
            .scrollContentBackground(.hidden)
            .background(customBackgroundColor)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }

    func generateCSV() -> URL? {
        // Optimize string building for large datasets
        var lines = [String]()
        lines.reserveCapacity(plugins.count + 1)

        // Header
        lines.append("Name,Publisher,Type,Style,Version,Architecture,Size,Obsolete")

        // Data rows
        for plugin in plugins {
            let name = escapeCSV(plugin.name)
            let publisher = escapeCSV(plugin.publisher)
            let type = plugin.type
            let style = escapeCSV(plugin.style)
            let version = escapeCSV(plugin.version)
            let arch = escapeCSV(plugin.architectures)
            let size = plugin.displaySize
            let obsolete = plugin.obsolete ? "Yes" : "No"

            lines.append("\(name),\(publisher),\(type),\(style),\(version),\(arch),\(size),\(obsolete)")
        }

        let csv = lines.joined(separator: "\n")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.FilePaths.csvExportFileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            AppLogger.error("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    func generatePDF() -> URL? {
        let pdfMetaData = [
            kCGPDFContextTitle: "Plugin List",
            kCGPDFContextAuthor: "Plugin Reporter"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: Constants.PDF.pageWidth, height: Constants.PDF.pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { (context) in
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

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.FilePaths.pdfExportFileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            AppLogger.error("Failed to write PDF: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Embedded ExportViewModel (to avoid path issues)

@MainActor
class ExportViewModel: ObservableObject {
    @Published var showShareSheet = false
    @Published var exportURL: URL?
    @Published var isExporting = false
    @Published var lastError: Error?
    
    private(set) var plugins: [PluginItem] = []
    
    func updatePlugins(_ newPlugins: [PluginItem]) {
        self.plugins = newPlugins
    }
    
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
    
    private func generateCSV() -> URL? {
        // Simple CSV generation
        var csv = "Name,Publisher,Format,Path\n"
        for plugin in plugins {
            let name = plugin.name.replacingOccurrences(of: "\"", with: "\"\"")
            let pub = plugin.publisher.replacingOccurrences(of: "\"", with: "\"\"")
            let format = plugin.type.replacingOccurrences(of: "\"", with: "\"\"")
            let path = plugin.path.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(name)\",\"\(pub)\",\"\(format)\",\"\(path)\"\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("plugins_export.csv")
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            lastError = error
            return nil
        }
    }
}
