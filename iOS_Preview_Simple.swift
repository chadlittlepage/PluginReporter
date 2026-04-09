// iOS_Preview_Simple.swift
// SIMPLE PREVIEW - Just paste this into Xcode Playground to see the UI instantly!
// File → New → Playground → iOS → Blank → Paste this code

import PlaygroundSupport
import SwiftUI

// MARK: - Main Container

struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PluginListPreview()
                .tabItem {
                    Label("Plugins", systemImage: "music.note.list")
                }
                .tag(0)

            StatsPreview()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)
        }
    }
}

// MARK: - Plugin List Screen

struct PluginListPreview: View {
    @State private var searchText = ""

    let plugins = [
        ("2016 Stereo Room", "Eventide", "Reverb", "AAX"),
        ("304C", "Avid Technology", "EQ", "AAX"),
        ("ADPTR MetricAB", "Adptr", "Effect", "AAX"),
        ("FabFilter Pro-Q 3", "FabFilter", "EQ", "VST3"),
        ("Valhalla Room", "Valhalla DSP", "Reverb", "AU")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Card
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

                    // Mini bars
                    VStack(spacing: 4) {
                        BarRow(label: "AU", count: 706, color: .blue)
                        BarRow(label: "VST", count: 473, color: .green)
                        BarRow(label: "VST3", count: 668, color: .teal)
                        BarRow(label: "AAX", count: 781, color: .purple)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding()

                // List
                List(plugins, id: \.0) { plugin in
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
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                }
                .searchable(text: $searchText)
            }
            .navigationTitle("Plugin Reporter")
        }
    }
}

struct BarRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(height: 4)

            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Stats Screen

struct StatsPreview: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total
                    VStack(spacing: 12) {
                        Text("Total Plugins")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("706")
                            .font(.system(size: 60, weight: .bold))

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundColor(.green)
                            Text("Last synced: 5 min ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 4)

                    // Formats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plugin Formats")
                            .font(.headline)

                        FormatBar(label: "AU", count: 706, color: .blue)
                        FormatBar(label: "VST", count: 473, color: .green)
                        FormatBar(label: "VST3", count: 668, color: .teal)
                        FormatBar(label: "AAX", count: 781, color: .purple)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 4)
                }
                .padding()
            }
            .navigationTitle("Statistics")
        }
    }
}

struct FormatBar: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)

            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(height: 8)

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// Show the preview - IMPORTANT: This line makes it show!
PlaygroundPage.current.setLiveView(MainView())
