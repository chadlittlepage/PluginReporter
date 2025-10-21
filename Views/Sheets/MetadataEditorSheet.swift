//
//  MetadataEditorSheet.swift
//  PluginReporter
//
//  Extracted from MacPluginTable.swift
//  Sheet for editing plugin metadata (publisher, version, style)
//

import SwiftUI

#if os(macOS)

// MARK: - Metadata Editor Sheet

struct MetadataEditorSheet: View {
    let plugin: PluginItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var metadataManager = MetadataManager.shared

    @State private var publisher: String = ""
    @State private var version: String = ""
    @State private var style: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Metadata")
                .font(.title)
                .fontWeight(.bold)

            Text(plugin.name)
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Override metadata for this plugin. Leave fields empty to use original values.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Publisher")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.publisher)", text: $publisher)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.version)", text: $version)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.style)", text: $style)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            HStack {
                Button("Reset to Original") {
                    metadataManager.removeOverride(for: plugin.path)
                    publisher = ""
                    version = ""
                    style = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveMetadata()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onAppear {
            if let override = metadataManager.getOverride(for: plugin.path) {
                publisher = override.publisher ?? ""
                version = override.version ?? ""
                style = override.style ?? ""
            }
        }
    }

    private func saveMetadata() {
        let override = PluginMetadataOverride(
            publisher: publisher.isEmpty ? nil : publisher,
            version: version.isEmpty ? nil : version,
            style: style.isEmpty ? nil : style
        )

        if override.hasAnyOverride {
            metadataManager.setOverride(for: plugin.path, override: override)
        } else {
            metadataManager.removeOverride(for: plugin.path)
        }
    }
}

#endif
