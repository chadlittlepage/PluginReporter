// iOS_Preview_Production.swift
// PRODUCTION-READY PREVIEW - Optimized for thousands of entries
// Copy into Xcode Playground to preview

import SwiftUI
import PlaygroundSupport

// MARK: - Main View

struct PluginListScreen: View {
    @State private var searchText = ""
    @State private var isRefreshing = false

    // Simulate 2000+ plugins with realistic data
    let plugins: [(String, String, String, String)] = {
        let names = ["Reverb", "Delay", "Compressor", "EQ", "Limiter", "Saturator", "Chorus", "Phaser", "Flanger", "Distortion"]
        let publishers = ["FabFilter", "Eventide", "Waves", "Universal Audio", "iZotope", "Slate Digital", "Plugin Alliance", "Soundtoys", "Native Instruments", "Arturia"]
        let styles = ["Reverb", "Delay", "Dynamics", "EQ", "Modulation", "Saturation", "Effect"]
        let types = ["AU", "VST", "VST3", "AAX"]

        return (0..<2000).map { i in
            ("\(names[i % names.count]) \(i + 1)",
             publishers[i % publishers.count],
             styles[i % styles.count],
             types[i % types.count])
        }
    }()

    var filteredPlugins: [(String, String, String, String)] {
        if searchText.isEmpty {
            return plugins
        }
        return plugins.filter { plugin in
            plugin.0.localizedCaseInsensitiveContains(searchText) ||
            plugin.1.localizedCaseInsensitiveContains(searchText) ||
            plugin.2.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Card
                statsCard
                    .padding()

                // Plugin List with LazyVStack for performance
                List {
                    ForEach(filteredPlugins.indices, id: \.self) { index in
                        PluginRow(plugin: filteredPlugins[index])
                    }
                }
                .searchable(text: $searchText, prompt: "Search \(plugins.count) plugins...")
                .refreshable {
                    await refresh()
                }
            }
            .navigationTitle("Plugin Reporter")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "gear")
                            .font(.title3)
                    }
                }
            }
        }
        .preferredColorScheme(.dark) // DARK MODE
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Plugin Library")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(plugins.count) Total Plugins")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Synced")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("5m ago")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Format breakdown with bars
            VStack(spacing: 8) {
                let counts = formatCounts
                MiniBarRow(label: "AU", count: counts.au, maxCount: counts.max, color: .blue)
                MiniBarRow(label: "VST", count: counts.vst, maxCount: counts.max, color: .green)
                MiniBarRow(label: "VST3", count: counts.vst3, maxCount: counts.max, color: .cyan)
                MiniBarRow(label: "AAX", count: counts.aax, maxCount: counts.max, color: .purple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }

    private var formatCounts: (au: Int, vst: Int, vst3: Int, aax: Int, max: Int) {
        var au = 0, vst = 0, vst3 = 0, aax = 0
        for plugin in plugins {
            switch plugin.3.uppercased() {
            case "AU": au += 1
            case "VST": vst += 1
            case "VST3": vst3 += 1
            case "AAX": aax += 1
            default: break
            }
        }
        let max = [au, vst, vst3, aax].max() ?? 1
        return (au, vst, vst3, aax, max)
    }

    private func refresh() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        isRefreshing = false
    }
}

// MARK: - Plugin Row

struct PluginRow: View {
    let plugin: (String, String, String, String)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plugin.0)
                .font(.headline)

            HStack(spacing: 8) {
                // Publisher
                Text(plugin.1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                // Style
                Text(plugin.2)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("•")
                    .foregroundColor(.secondary)

                // Type badge
                Text(plugin.3)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor(plugin.3).opacity(0.2))
                    .foregroundColor(typeColor(plugin.3))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private func typeColor(_ type: String) -> Color {
        switch type.uppercased() {
        case "AU": return .blue
        case "VST": return .green
        case "VST3": return .cyan
        case "AAX": return .purple
        default: return .gray
        }
    }
}

// MARK: - Mini Bar Row

struct MiniBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var fraction: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - Show Preview

PlaygroundPage.current.setLiveView(PluginListScreen())
