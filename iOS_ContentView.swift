// iOS_ContentView.swift - Main iOS app interface
// Add this file to iOS target ONLY
import SwiftUI

struct iOS_ContentView: View {
    @StateObject private var cloudSync = CloudSyncManager()
    @StateObject private var prefs = Preferences()
    @State private var selectedTab = 0
    @State private var showFilters = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Plugin List
            PluginListView(cloudSync: cloudSync, prefs: prefs, showFilters: $showFilters)
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

            // Tab 2: Stats Dashboard
            StatsView(cloudSync: cloudSync)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)
        }
    }
}

// MARK: - Plugin List View

struct PluginListView: View {
    @ObservedObject var cloudSync: CloudSyncManager
    @ObservedObject var prefs: Preferences
    @Binding var showFilters: Bool

    @State private var searchText = ""
    @State private var selectedPlugin: PluginItem?

    var filteredPlugins: [PluginItem] {
        var plugins = cloudSync.plugins

        // Apply search
        if !searchText.isEmpty {
            plugins = plugins.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.publisher.localizedCaseInsensitiveContains(searchText) ||
                plugin.style.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply format filters
        if !prefs.selectedFormats.isEmpty {
            plugins = plugins.filter { plugin in
                guard let format = PluginFormat(rawValue: plugin.type) else { return false }
                return prefs.selectedFormats.contains(format)
            }
        }

        // Apply style filters
        if !prefs.selectedStyles.isEmpty {
            plugins = plugins.filter { prefs.selectedStyles.contains($0.style) }
        }

        // Apply publisher filters
        if !prefs.selectedPublishers.isEmpty {
            plugins = plugins.filter { prefs.selectedPublishers.contains($0.publisher) }
        }

        return plugins
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Card
                statsCard
                    .padding()

                // Plugin List
                List {
                    ForEach(filteredPlugins) { plugin in
                        NavigationLink(destination: PluginDetailView(plugin: plugin, allPlugins: cloudSync.plugins)) {
                            PluginRowView(plugin: plugin)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedPlugin = plugin
                            } label: {
                                Label("AI Suggestions", systemImage: "sparkles")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing) {
                            ShareLink(item: formatPluginText(plugin)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search plugins...")
                .refreshable {
                    await cloudSync.syncFromCloud()
                }
            }
            .navigationTitle("Plugin Reporter")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        iOS_SettingsView(prefs: prefs, cloudSync: cloudSync)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(item: $selectedPlugin) { plugin in
                AISuggestionsView(plugin: plugin, ownedPlugins: cloudSync.plugins)
            }
            .sheet(isPresented: $showFilters) {
                FilterSidebarView(prefs: prefs, allPlugins: cloudSync.plugins)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Plugin Library")
                        .font(.headline)
                    Text("\(cloudSync.plugins.count) Total Plugins")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()

                if cloudSync.isSyncing {
                    ProgressView()
                } else if let syncDate = cloudSync.lastSyncDate {
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                        Text("Synced \(timeAgo(syncDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Mini bar graphs
            MiniBarGraphs(plugins: cloudSync.plugins)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formatPluginText(_ plugin: PluginItem) -> String {
        """
        \(plugin.name)
        Publisher: \(plugin.publisher)
        Type: \(plugin.type)
        Style: \(plugin.style)
        Version: \(plugin.version)
        """
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}

// MARK: - Plugin Row

struct PluginRowView: View {
    let plugin: PluginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plugin.name)
                .font(.headline)

            HStack(spacing: 8) {
                Text(plugin.publisher)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(plugin.style)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(plugin.type)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor(plugin.type).opacity(0.2))
                    .foregroundColor(typeColor(plugin.type))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
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
}

// MARK: - Mini Bar Graphs

struct MiniBarGraphs: View {
    let plugins: [PluginItem]

    private var counts: (au: Int, vst: Int, vst3: Int, aax: Int, clap: Int, lv2: Int) {
        var au = 0, vst = 0, vst3 = 0, aax = 0, clap = 0, lv2 = 0
        for plugin in plugins {
            switch plugin.type.uppercased() {
            case "AU": au += 1
            case "VST": vst += 1
            case "VST3": vst3 += 1
            case "AAX": aax += 1
            case "CLAP": clap += 1
            case "LV2": lv2 += 1
            default: break
            }
        }
        return (au, vst, vst3, aax, clap, lv2)
    }

    var body: some View {
        let c = counts
        let maxCount = max(1, c.au, c.vst, c.vst3, c.aax, c.clap, c.lv2)

        VStack(spacing: 4) {
            MiniBarRow(label: "AU", count: c.au, maxCount: maxCount, color: .blue)
            MiniBarRow(label: "VST", count: c.vst, maxCount: maxCount, color: .green)
            MiniBarRow(label: "VST3", count: c.vst3, maxCount: maxCount, color: .teal)
            MiniBarRow(label: "AAX", count: c.aax, maxCount: maxCount, color: .purple)
        }
    }
}

struct MiniBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var fraction: Double {
        Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)

            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

#Preview {
    iOS_ContentView()
}
