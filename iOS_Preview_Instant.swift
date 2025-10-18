// iOS_Preview_Instant.swift
// INSTANT PREVIEW - Copy ALL of this into your Xcode Playground

import SwiftUI
import PlaygroundSupport

// Plugin List Screen
struct PluginListScreen: View {
    let plugins = [
        ("2016 Stereo Room", "Eventide", "Reverb", "AAX"),
        ("304C", "Avid Technology", "EQ", "AAX"),
        ("ADPTR MetricAB", "Adptr", "Effect", "AAX"),
        ("FabFilter Pro-Q 3", "FabFilter", "EQ", "VST3"),
        ("Valhalla Room", "Valhalla DSP", "Reverb", "AU"),
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

                    // Bar graphs
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("AU")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(height: 4)
                            Text("706")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        HStack(spacing: 8) {
                            Text("VST")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(height: 4)
                            Text("473")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        HStack(spacing: 8) {
                            Text("VST3")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.teal)
                                .frame(height: 4)
                            Text("668")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        HStack(spacing: 8) {
                            Text("AAX")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(height: 4)
                            Text("781")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()

                // Plugin List
                List {
                    ForEach(plugins, id: \.0) { plugin in
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
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Plugin Reporter")
        }
    }
}

// Show it!
PlaygroundPage.current.setLiveView(PluginListScreen())
