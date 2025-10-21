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
    @AppStorage("appearance") private var appearance: String = "space"
    @State private var showFilePicker = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showBugReport = false
    @State private var showFeatureRequest = false

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
                    Picker("Appearance", selection: $appearance.animation(nil)) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("Space").tag("space")
                    }
                    .pickerStyle(.segmented)
                    .animation(nil, value: appearance)
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

                Section {
                    AISettingsView()
                } header: {
                    Text("AI Suggestions")
                }

                Section {
                    Button(action: {
                        showBugReport = true
                    }) {
                        HStack {
                            Image(systemName: "ant.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Report a Bug")
                                    .foregroundColor(.primary)
                                Text("Send crash reports and bug details")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showFeatureRequest = true
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Request a Feature")
                                    .foregroundColor(.primary)
                                Text("Suggest new features or improvements")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Your device information will be automatically included to help us assist you better.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Support")
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
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
            .scrollContentBackground(.hidden)
            .background(customBackgroundColor)
            .scrollDismissesKeyboard(.never) // Never dismiss keyboard on scroll
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .transaction { transaction in
                transaction.animation = nil // Disable all Form animations
            }
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
            .sheet(isPresented: $showBugReport) {
                NavigationStack {
                    BugReportView()
                        .navigationTitle("Report a Bug")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(Color(red: 24/255, green: 24/255, blue: 26/255), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showFeatureRequest) {
                NavigationStack {
                    FeatureRequestView()
                        .navigationTitle("Request a Feature")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(Color(red: 24/255, green: 24/255, blue: 26/255), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                }
                .presentationDetents([.large])
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
