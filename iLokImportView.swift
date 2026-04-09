//
//  iLokImportView.swift
//  Plugin Reporter
//
//  UI for importing licenses from iLok License Manager CSV export
//

import SwiftUI

struct iLokImportView: View {
    @State private var isImporting = false
    @State private var importResult: iLokImportResult?
    @State private var errorMessage: String?

    let plugins: [ScannerPluginItem]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.title)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Import from iLok")
                        .font(.headline)
                    Text("Import license data from iLok License Manager")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    #if os(macOS)
                    NSApplication.shared.keyWindow?.close()
                    #endif
                }
            }
            .padding()

            Divider()

            if let result = importResult {
                // Show import results
                importResultsView(result: result)
            } else {
                // Show instructions and import button
                instructionsView
            }
        }
        .frame(width: 600)
        .frame(minHeight: 600, maxHeight: .infinity)
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Step-by-step instructions
                InstructionStep(
                    number: 1, title: "Open iLok License Manager", description: "Launch the iLok License Manager application"
                )

                InstructionStep(
                    number: 2, title: "View Your Licenses", description: "Make sure you're viewing your licenses in the main window"
                )

                InstructionStep(
                    number: 3, title: "Export to CSV", description: "Click the \"Export CSV\" button (usually in the toolbar or File menu)"
                )

                InstructionStep(
                    number: 4, title: "Save the CSV File", description: "Save the exported CSV file to a location you can remember"
                )

                InstructionStep(
                    number: 5, title: "Import Below", description: "Click the \"Select CSV File\" button below to import your licenses"
                )

                Divider()
                    .padding(.vertical)

                // Import button
                VStack(spacing: 12) {
                    Button(action: {
                        openFilePicker()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Select CSV File")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if isImporting {
                        ProgressView("Importing licenses...")
                            .padding()
                    }

                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Import Results View

    private func importResultsView(result: iLokImportResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            Text("Import Complete!")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Successfully imported iLok license data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Statistics
                    HStack(spacing: 40) {
                        StatBox(
                            value: "\(result.totalLicenses)", label: "Total Licenses", icon: "doc.text"
                        )

                        StatBox(
                            value: "\(result.matchedPlugins)", label: "Matched Plugins", icon: "checkmark.circle"
                        )

                        StatBox(
                            value: "\(result.unmatchedLicenses.count)", label: "Unmatched", icon: "questionmark.circle"
                        )
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Imported licenses list
                if !result.importedLicenses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Imported Licenses", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)

                        ForEach(result.importedLicenses.indices, id: \.self) { index in
                            let license = result.importedLicenses[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(license.productName)
                                        .font(.subheadline)
                                    Text(license.publisher)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }

                // Unmatched licenses
                if !result.unmatchedLicenses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Unmatched Licenses", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundColor(.orange)

                        Text("These licenses couldn't be matched to plugins in your library:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(result.unmatchedLicenses.indices, id: \.self) { index in
                            let license = result.unmatchedLicenses[index]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(license.productName)
                                        .font(.subheadline)
                                    Text(license.publisher)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.orange)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }

                // Errors
                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Errors", systemImage: "xmark.circle")
                            .font(.headline)
                            .foregroundColor(.red)

                        ForEach(result.errors, id: \.self) { error in
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }

                // Import another button
                Button(action: {
                    importResult = nil
                    errorMessage = nil
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Import Another File")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    // MARK: - Helper Functions

    private func openFilePicker() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Select iLok CSV File"
        panel.message = "Choose the CSV file exported from iLok License Manager"
        panel.allowedContentTypes = [.commaSeparatedText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Present panel in front of the iLok import window
        if let window = NSApplication.shared.keyWindow {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }

                self.isImporting = true
                self.errorMessage = nil

                Task {
                    do {
                        let result = try await iLokImporter.importFromCSV(
                            url: url, plugins: self.plugins, autoMatch: true
                        )

                        await MainActor.run {
                            self.importResult = result
                            self.isImporting = false
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.isImporting = false
                        }
                    }
                }
            }
        } else {
            // Fallback if no key window
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }

                self.isImporting = true
                self.errorMessage = nil

                Task {
                    do {
                        let result = try await iLokImporter.importFromCSV(
                            url: url, plugins: self.plugins, autoMatch: true
                        )

                        await MainActor.run {
                            self.importResult = result
                            self.isImporting = false
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.isImporting = false
                        }
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - Supporting Views

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}