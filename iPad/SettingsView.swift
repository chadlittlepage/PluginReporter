//
//  SettingsView.swift
//  PluginReporter (iPad)
//
//  iPad settings view
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let onImport: () -> Void
    @AppStorage("appearance") private var appearance: String = "dark"
    @State private var showFilePicker = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("System").tag("system")
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

                        Text("The Mac app saves to:\\n~/Library/Application Support/PluginReporter/plugins.json\\n\\nCopy this file to the simulator's Documents folder to view in iOS.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Instructions")
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iPad")
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
                    print("File picker error: \(error.localizedDescription)")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    func handleFileImport(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access file")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Copy to Documents folder
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
            print("Import error: \(error.localizedDescription)")
        }
    }
}
