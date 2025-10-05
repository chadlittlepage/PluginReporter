//
//  SettingsView.swift
//  PluginReporter (iOS)
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings View

struct SettingsView: View {
    let onImport: () -> Void
    @AppStorage("appearance") private var appearance: String = "dark"
    @State private var showFilePicker = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("Space").tag("space")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Display")
                }

                Section {
                    Button(action: { showFilePicker = true }) {
                        Label("Import JSON File", systemImage: "square.and.arrow.down")
                    }

                    Text("Browse and select a plugins.json file to import.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button(action: onImport) {
                        Label("Reload from Documents", systemImage: "arrow.clockwise")
                    }

                    Text("Reload plugins from the app's Documents folder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Data Sync")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Simulator Setup")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("The Mac app saves to:\n~/Library/Application Support/PluginReporter/plugins.json\n\nCopy this file to the simulator's Documents folder to view in iOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Instructions")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleFileImport(url: url)
                    }
                case .failure(let error):
                    AppLogger.error("File picker error: \(error.localizedDescription)")
                    errorMessage = String(format: NSLocalizedString("Could not open file: %@", comment: "File picker error"), error.localizedDescription)
                    showErrorAlert = true
                }
            }
            .alert(NSLocalizedString("Import Error", comment: "Error alert title"), isPresented: $showErrorAlert) {
                Button(NSLocalizedString("OK", comment: "Dismiss button"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    func handleFileImport(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            AppLogger.error("Failed to access file")
            errorMessage = NSLocalizedString("Unable to access the selected file. Please try again.", comment: "File access error")
            showErrorAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Copy to Documents folder
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                AppLogger.error("Failed to access document directory")
                errorMessage = NSLocalizedString("Unable to access app documents folder.", comment: "Documents folder error")
                showErrorAlert = true
                return
            }
            let destinationURL = documentsURL.appendingPathComponent("plugins.json")

            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy new file
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Trigger reload
            onImport()
        } catch {
            AppLogger.error("Import error: \(error.localizedDescription)")
            errorMessage = String(format: NSLocalizedString("Failed to import file: %@", comment: "Import failure error"), error.localizedDescription)
            showErrorAlert = true
        }
    }
}
