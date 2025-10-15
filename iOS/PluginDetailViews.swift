//
//  PluginDetailViews.swift
//  PluginReporter (iOS)
//

import SwiftUI

// MARK: - Consolidated Plugin Detail View

struct ConsolidatedPluginDetailView: View {
    let consolidated: PluginListView.ConsolidatedPlugin
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(consolidated.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("by \(consolidated.publisher)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // AI Suggestions Button - Top Center
                HStack {
                    Spacer()
                    AISuggestionsButton(
                        plugin: consolidated.originalPlugins.first ?? PluginItem(
                            name: consolidated.name,
                            publisher: consolidated.publisher,
                            version: "",
                            type: consolidated.types.first ?? "",
                            style: consolidated.style,
                            architectures: "",
                            date: nil,
                            sizeBytes: 0,
                            path: "",
                            runtimeRequirement: "",
                            obsolete: false
                        ),
                        ownedPlugins: consolidated.originalPlugins
                    )
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // Available formats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Formats")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(consolidated.types, id: \.self) { type in
                                Text(type)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(ColorUtilities.colorForFormat(type).opacity(0.2))
                                    .foregroundColor(ColorUtilities.colorForFormat(type))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    if !consolidated.style.isEmpty {
                        DetailInfoRow(label: "Style", value: consolidated.style)
                    }

                    // Show details for each format
                    ForEach(consolidated.originalPlugins) { plugin in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(plugin.type) Details")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ColorUtilities.colorForFormat(plugin.type))

                            DetailInfoRow(label: "Version", value: plugin.version.isEmpty ? "Unknown" : plugin.version)
                            DetailInfoRow(label: "Architecture", value: plugin.architectures.isEmpty ? "Unknown" : plugin.architectures)
                            DetailInfoRow(label: "Size", value: plugin.displaySize)

                            if !plugin.path.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Path")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        Text(plugin.path)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(10)
                                            .background(Color(.systemGray6).opacity(0.5))
                                            .cornerRadius(8)
                                    }
                                }
                            }

                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    var shareText: String {
        var text = "\(consolidated.name)\n"
        text += "Publisher: \(consolidated.publisher)\n"
        text += "Formats: \(consolidated.types.joined(separator: ", "))\n"
        if !consolidated.style.isEmpty {
            text += "Style: \(consolidated.style)\n"
        }
        return text
    }
}

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    let plugin: PluginItem
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plugin.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("by \(plugin.publisher)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // AI Suggestions Button - Top Center
                HStack {
                    Spacer()
                    AISuggestionsButton(
                        plugin: plugin,
                        ownedPlugins: [plugin]
                    )
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                VStack(spacing: 12) {
                    DetailInfoRow(label: "Type", value: plugin.type, color: ColorUtilities.colorForFormat(plugin.type))
                    DetailInfoRow(label: "Style", value: plugin.style)
                    DetailInfoRow(label: "Version", value: plugin.version.isEmpty ? "Unknown" : plugin.version)
                    DetailInfoRow(label: "Architecture", value: plugin.architectures.isEmpty ? "Unknown" : plugin.architectures)
                    DetailInfoRow(label: "Date", value: plugin.displayDate)
                    DetailInfoRow(label: "Size", value: plugin.displaySize)

                    if !plugin.path.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Path")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(plugin.path)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(10)
                                    .background(Color(.systemGray6).opacity(0.5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    var shareText: String {
        var text = "\(plugin.name)\n"
        text += "Publisher: \(plugin.publisher)\n"
        text += "Type: \(plugin.type)\n"
        if !plugin.style.isEmpty {
            text += "Style: \(plugin.style)\n"
        }
        if !plugin.version.isEmpty {
            text += "Version: \(plugin.version)\n"
        }
        return text
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            if let color = color {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .cornerRadius(6)
            } else {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}
