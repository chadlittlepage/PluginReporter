// iOS_Preview_Standalone.swift
// Quick standalone preview - Copy this entire file into a new iOS project to see the UI
import SwiftUI

// MARK: - Standalone Preview App

@main
struct PreviewApp: App {
    var body: some Scene {
        WindowGroup {
            PreviewContainer()
        }
    }
}

struct PreviewContainer: View {
    @State private var selectedScreen = 0

    var body: some View {
        VStack {
            // Screen Selector
            Picker("Screen", selection: $selectedScreen) {
                Text("Main List").tag(0)
                Text("Plugin Detail").tag(1)
                Text("Stats").tag(2)
                Text("Filters").tag(3)
                Text("Settings").tag(4)
            }
            .pickerStyle(.segmented)
            .padding()

            // Show selected screen
            TabView(selection: $selectedScreen) {
                PreviewMainList()
                    .tag(0)

                NavigationView {
                    PreviewPluginDetail()
                }
                .tag(1)

                NavigationView {
                    PreviewStats()
                }
                .tag(2)

                PreviewFilters()
                    .tag(3)

                NavigationView {
                    PreviewSettings()
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

// MARK: - Screen 1: Main List

struct PreviewMainList: View {
    @State private var searchText = ""

    let samplePlugins = [
        ("2016 Stereo Room", "Eventide", "Reverb", "AAX"),
        ("304C", "Avid Technology", "EQ", "AAX"),
        ("304E", "Avid Technology", "EQ", "AAX"),
        ("ADPTR MetricAB", "Adptr", "Effect", "AAX"),
        ("ADPTR StreamLiner", "Adptr", "Effect", "VST"),
        ("AIRChorus", "AIR Music Technology", "Modulation", "AAX"),
        ("FabFilter Pro-Q 3", "FabFilter", "EQ", "VST3"),
        ("Valhalla Room", "Valhalla DSP", "Reverb", "AU"),
        ("Waves SSL E-Channel", "Waves", "Channel Strip", "AAX")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Card
                statsCard
                    .padding()

                // Plugin List
                List {
                    ForEach(samplePlugins, id: \.0) { plugin in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plugin.0)
                                .font(.headline)

                            HStack(spacing: 8) {
                                Text(plugin.1)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(plugin.2)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(plugin.3)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(typeColor(plugin.3).opacity(0.2))
                                    .foregroundColor(typeColor(plugin.3))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .searchable(text: $searchText, prompt: "Search plugins...")
            }
            .navigationTitle("Plugin Reporter")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Plugin Library")
                        .font(.headline)
                    Text("706 Total Plugins")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                    Text("Synced 5m ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Mini bar graphs
            VStack(spacing: 4) {
                MiniBarRow(label: "AU", count: 706, maxCount: 781, color: .blue)
                MiniBarRow(label: "VST", count: 473, maxCount: 781, color: .green)
                MiniBarRow(label: "VST3", count: 668, maxCount: 781, color: .teal)
                MiniBarRow(label: "AAX", count: 781, maxCount: 781, color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func typeColor(_ type: String) -> Color {
        switch type.uppercased() {
        case "AU": return .blue
        case "VST": return .green
        case "VST3": return .teal
        case "AAX": return .purple
        default: return .gray
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

// MARK: - Screen 2: Plugin Detail

struct PreviewPluginDetail: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("2016 Stereo Room")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("by Eventide")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                Divider()

                // Info Cards
                VStack(spacing: 12) {
                    DetailInfoRow(label: "Type", value: "AAX", color: .purple)
                    DetailInfoRow(label: "Style", value: "Reverb")
                    DetailInfoRow(label: "Version", value: "3.7.10")
                    DetailInfoRow(label: "Architecture", value: "Universal")
                    DetailInfoRow(label: "Date", value: "Mar 15, 2024")
                    DetailInfoRow(label: "Size", value: "45.2 MB")
                }
                .padding(.horizontal)

                Divider()

                // Path
                VStack(alignment: .leading, spacing: 8) {
                    Text("Path")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text("/Library/Application Support/Avid/Audio/Plug-Ins/2016 Stereo Room.aaxplugin")
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
                    Button {} label: {
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

                    Button {} label: {
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

                    Button {} label: {
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
    }
}

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

// MARK: - Screen 3: Stats

struct PreviewStats: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Total Card
                VStack(spacing: 12) {
                    Text("Total Plugins")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("706")
                        .font(.system(size: 60, weight: .bold, design: .rounded))

                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                            Text("Last synced: 5 min ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("From: MacBook Pro")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8)

                // Format Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plugin Formats")
                        .font(.headline)

                    VStack(spacing: 10) {
                        StatsBarRow(label: "AU", count: 706, maxCount: 781, color: .blue)
                        StatsBarRow(label: "VST", count: 473, maxCount: 781, color: .green)
                        StatsBarRow(label: "VST3", count: 668, maxCount: 781, color: .teal)
                        StatsBarRow(label: "AAX", count: 781, maxCount: 781, color: .purple)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8)

                // Top Publishers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Publishers")
                        .font(.headline)

                    VStack(spacing: 8) {
                        TopRow(rank: 1, name: "Eventide", count: 127)
                        Divider()
                        TopRow(rank: 2, name: "Avid Technology", count: 98)
                        Divider()
                        TopRow(rank: 3, name: "FabFilter", count: 45)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 8)
            }
            .padding()
        }
        .navigationTitle("Statistics")
    }
}

struct StatsBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var fraction: Double {
        Double(count) / Double(maxCount)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

struct TopRow: View {
    let rank: Int
    let name: String
    let count: Int

    var body: some View {
        HStack {
            Text("\(rank).")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            Text(name)
                .font(.body)

            Spacer()

            Text("\(count)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Screen 4: Filters

struct PreviewFilters: View {
    @State private var selectedFormats: Set<String> = ["AU", "VST3", "AAX"]

    var body: some View {
        NavigationView {
            Form {
                Section("Formats") {
                    ForEach(["AU", "VST", "VST3", "AAX", "CLAP", "LV2"], id: \.self) { format in
                        Toggle(format, isOn: Binding(
                            get: { selectedFormats.contains(format) },
                            set: { _ in }
                        ))
                    }
                }

                Section("Styles") {
                    Toggle("Reverb", isOn: .constant(true))
                    Toggle("EQ", isOn: .constant(false))
                    Toggle("Dynamics", isOn: .constant(false))
                }

                Section {
                    Button(role: .destructive) {
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear All Filters")
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {}
                }
            }
        }
    }
}

// MARK: - Screen 5: Settings

struct PreviewSettings: View {
    @State private var cloudSyncEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Sync with iCloud", isOn: $cloudSyncEnabled)

                if cloudSyncEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                            Text("Last synced: 5 min ago")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text("Synced from: MacBook Pro")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("iCloud Sync")
            }

            Section("Appearance") {
                Picker("Interface", selection: .constant(0)) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
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

#Preview {
    PreviewContainer()
}
