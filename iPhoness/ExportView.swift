//
//  ExportView.swift
//  PluginReporter (iOS)
//
//  Export view for CSV and PDF generation
//

import SwiftUI
import UIKit
import Combine

struct ExportView: View {
    let plugins: [PluginItem]
    @StateObject private var viewModel = ExportViewModel()
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
                        viewModel.updatePlugins(plugins)
                        viewModel.exportCSV()
                    }) {
                        Label("Export as CSV", systemImage: "doc.text")
                    }
                    .accessibilityHint("Export plugin list as CSV file")

                    Text("Export plugin list as comma-separated values file.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button(action: {
                        viewModel.updatePlugins(plugins)
                        viewModel.exportPDF()
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
            .transaction { transaction in
                transaction.animation = nil // Disable all Form animations
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
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

    private func generatePDF() -> URL? {
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

                // Truncate long text to prevent overflow
                let name = String(plugin.name.prefix(30))
                let publisher = String(plugin.publisher.prefix(20))
                let type = String(plugin.type.prefix(10))
                let style = String(plugin.style.prefix(15))

                // Draw with bounds checking
                let nameRect = CGRect(x: Constants.PDF.pageMargin, y: yPosition, width: 180, height: 20)
                let pubRect = CGRect(x: Constants.PDF.pageMargin + 200, y: yPosition, width: 140, height: 20)
                let typeRect = CGRect(x: Constants.PDF.pageMargin + 350, y: yPosition, width: 40, height: 20)
                let styleRect = CGRect(x: Constants.PDF.pageMargin + 400, y: yPosition, width: 150, height: 20)

                name.draw(in: nameRect, withAttributes: bodyAttributes)
                publisher.draw(in: pubRect, withAttributes: bodyAttributes)
                type.draw(in: typeRect, withAttributes: bodyAttributes)
                style.draw(in: styleRect, withAttributes: bodyAttributes)

                yPosition += Constants.PDF.lineSpacing
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.FilePaths.pdfExportFileName)

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            AppLogger.error("Failed to write PDF: \(error.localizedDescription)")
            lastError = error
            return nil
        }
    }
}
