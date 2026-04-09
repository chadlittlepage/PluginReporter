// PluginDetailView.swift - iOS Plugin Detail Screen
// Add this file to iOS target ONLY
import SwiftUI

struct PluginDetailView: View {
    let plugin: PluginItem
    let allPlugins: [PluginItem]

    @State private var showAISuggestions = false
    @State private var showModeChoice = false
    @State private var showHeritageOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
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

                Divider()

                // Info Cards
                VStack(spacing: 12) {
                    InfoRow(label: "Type", value: plugin.type, color: typeColor(plugin.type))
                    InfoRow(label: "Style", value: plugin.style)
                    InfoRow(label: "Version", value: plugin.version)
                    InfoRow(label: "Architecture", value: plugin.architectures)
                    InfoRow(label: "Date", value: plugin.dateString)
                    InfoRow(label: "Size", value: plugin.sizeString)
                    if !plugin.runtimeRequirement.isEmpty {
                        InfoRow(label: "Runtime", value: plugin.runtimeRequirement)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Path Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Path")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(plugin.path)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        showModeChoice = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AI Suggestions")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button {
                        checkForUpdate()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check for Update")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    ShareLink(item: formatPluginText()) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("What would you like to see?", isPresented: $showModeChoice) {
            if PluginHeritageDatabase.getHeritage(for: plugin.name) != nil {
                Button("View Hit Songs Using This Plugin") {
                    print("👤 [User Choice] Selected: View Hit Songs (Heritage exists)")
                    showHeritageOnly = true
                }
                Button("Discover Similar Plugins to Buy") {
                    print("👤 [User Choice] Selected: Discover Similar Plugins (Don't Own)")
                    showAISuggestions = true
                }
                Button("Find Similar Plugins I Already Own") {
                    print("👤 [User Choice] Selected: Find Owned Alternatives")
                    showAISuggestions = true
                }
            } else {
                Button("Discover Similar Plugins to Buy") {
                    print("👤 [User Choice] Selected: Discover Similar Plugins (No heritage)")
                    showAISuggestions = true
                }
                Button("Find Similar Plugins I Already Own") {
                    print("👤 [User Choice] Selected: Find Owned Alternatives (No heritage)")
                    showAISuggestions = true
                }
            }
            Button("Cancel", role: .cancel) {
                print("👤 [User Choice] Cancelled")
            }
        } message: {
            if PluginHeritageDatabase.getHeritage(for: plugin.name) != nil {
                Text("Explore '\(plugin.name)' - you own this plugin")
            } else {
                Text("Find plugins similar to '\(plugin.name)'")
            }
        }
        .sheet(isPresented: $showAISuggestions) {
            AISuggestionsView(initialPlugin: plugin, ownedPlugins: allPlugins)
        }
        .sheet(isPresented: $showHeritageOnly) {
            if let heritage = PluginHeritageDatabase.getHeritage(for: plugin.name) {
                NavigationStack {
                    HeritageDetailView(heritage: heritage, pluginName: plugin.name)
                }
            } else {
                NavigationStack {
                    VStack(spacing: 20) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Heritage Data")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("'\(plugin.name)' doesn't have heritage information yet.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Heritage data includes famous recordings, hit songs, and the engineers who used this plugin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .navigationTitle("Heritage")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showHeritageOnly = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func typeColor(_ type: String) -> Color {
        switch type.uppercased() {
        case "AU": return .blue
        case "VST": return .green
        case "VST3": return .teal
        case "AAX": return .purple
        case "CLAP": return .orange
        case "LV2": return .gray
        default: return .gray
        }
    }

    private func checkForUpdate() {
        let searchQuery = "\(plugin.publisher) \(plugin.name) plugin download"
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") else {
            return
        }
        UIApplication.shared.open(searchURL)
    }

    private func formatPluginText() -> String {
        """
        \(plugin.name)
        Publisher: \(plugin.publisher)
        Type: \(plugin.type)
        Style: \(plugin.style)
        Version: \(plugin.version)
        Architecture: \(plugin.architectures)
        Size: \(plugin.sizeString)
        """
    }
}

// MARK: - Info Row

struct InfoRow: View {
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

#Preview {
    NavigationStack {
        PluginDetailView(
            plugin: PluginItem(
                name: "2016 Stereo Room",
                publisher: "Eventide",
                version: "3.7.10",
                type: "AAX",
                style: "Reverb",
                architectures: "Universal",
                date: Date(),
                sizeBytes: 45_000_000,
                path: "/Library/Application Support/Avid/Audio/Plug-Ins/2016 Stereo Room.aaxplugin",
                runtimeRequirement: "macOS 10.15+",
                obsolete: false
            ),
            allPlugins: []
        )
    }
}
