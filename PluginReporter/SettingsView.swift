//
//  SettingsView.swift
//  PluginReporter (iOS)
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    let onImport: () -> Void
    @AppStorage("appearance") private var appearance: String = "dark"

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
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("Local JSON Import")
                    }
                    .font(.subheadline)

                    Text("Import plugins from a JSON file exported from the Mac app. Place 'plugins.json' in the app's Documents folder.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: onImport) {
                        Label("Reload Plugins", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Data Sync")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Sync")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("1. On Mac: Open Plugin Reporter and click 'Export JSON'\n2. Save to: ~/Library/Developer/CoreSimulator/Devices/[DEVICE-ID]/data/Containers/Data/Application/[APP-ID]/Documents/plugins.json\n3. On iOS: Tap 'Reload Plugins' above")
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
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
