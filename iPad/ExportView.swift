//
//  ExportView.swift
//  PluginReporter (iPad)
//
//  iPad-optimized export view
//

import SwiftUI

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
        NavigationView {
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
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
