//
//  ExportView.swift
//  PluginReporter (iPad)
//
//  iPad-optimized export view
//

import SwiftUI
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

                    // PDF export removed - macOS only feature
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
