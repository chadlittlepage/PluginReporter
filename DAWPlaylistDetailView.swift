//
//  DAWPlaylistDetailView.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import SwiftUI

/// Detailed view of a DAW playlist showing plugins grouped by track
struct DAWPlaylistDetailView: View {

    let playlist: DAWPlaylist

    @EnvironmentObject var appState: AppState
    @StateObject private var playlistManager = DAWPlaylistManager.shared

    @State private var searchText = ""
    @State private var showOnlyMissing = false
    @State private var expandedTracks: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {

            // Header
            PlaylistHeader(playlist: playlist)

            Divider()

            // Toolbar
            HStack(spacing: 16) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search plugins...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 250)

                // Filter
                Toggle(isOn: $showOnlyMissing) {
                    Label("Missing Only", systemImage: "exclamationmark.triangle")
                }
                .toggleStyle(.button)

                Spacer()

                // Actions
                Menu {
                    Button(action: { rescanPlaylist() }) {
                        Label("Re-scan Plugins", systemImage: "arrow.clockwise")
                    }

                    Button(action: { exportPlaylist() }) {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: { deletePlaylist() }) {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
            }
            .padding()

            Divider()

            // Track list
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredTracks, id: \.self) { trackName in
                        TrackSection(
                            trackName: trackName,
                            entries: filteredEntries(for: trackName),
                            isExpanded: expandedTracks.contains(trackName),
                            onToggle: { toggleTrack(trackName) }
                        )
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Filtering

    private var filteredTracks: [String] {
        let tracks = PluginMatcher.sortedTrackNames(playlist.entries)

        return tracks.filter { trackName in
            let entries = filteredEntries(for: trackName)
            return !entries.isEmpty
        }
    }

    private func filteredEntries(for trackName: String) -> [DAWPlaylistEntry] {
        var entries = playlist.entries(forTrack: trackName)

        // Filter by search
        if !searchText.isEmpty {
            entries = entries.filter {
                $0.pluginName.localizedCaseInsensitiveContains(searchText) ||
                $0.pluginManufacturer.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by missing
        if showOnlyMissing {
            entries = entries.filter { !$0.isInstalled }
        }

        return entries
    }

    // MARK: - Actions

    private func toggleTrack(_ trackName: String) {
        if expandedTracks.contains(trackName) {
            expandedTracks.remove(trackName)
        } else {
            expandedTracks.insert(trackName)
        }
    }

    private func rescanPlaylist() {
        playlistManager.rescanPlaylist(playlist, installedPlugins: appState.all)
    }

    private func exportPlaylist() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(playlist.name).csv"
        panel.title = "Export Playlist to CSV"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let csvContent = generateCSV()
                try csvContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                AppLogger.error("Failed to export CSV: \(error.localizedDescription)")
            }
        }
    }

    private func generateCSV() -> String {
        var csv = "Track,Plugin Name,Manufacturer,Format,Status,Device Index\n"

        for trackName in PluginMatcher.sortedTrackNames(playlist.entries) {
            let entries = playlist.entries(forTrack: trackName)
            for entry in entries {
                let status = entry.isInstalled ? "Installed" : "Missing"
                let row = "\"\(trackName)\",\"\(entry.pluginName)\",\"\(entry.pluginManufacturer)\",\"\(entry.pluginFormat.rawValue)\",\"\(status)\",\(entry.deviceIndex + 1)\n"
                csv += row
            }
        }

        return csv
    }

    private func deletePlaylist() {
        playlistManager.deletePlaylist(playlist)
    }
}

// MARK: - Playlist Header

private struct PlaylistHeader: View {

    let playlist: DAWPlaylist

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        Text(playlist.dawType.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text("Imported \(playlist.dateImported, style: .relative)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // Stats
            HStack(spacing: 24) {
                StatBox(
                    title: "Total Plugins",
                    value: "\(playlist.entries.count)",
                    icon: "square.grid.3x3",
                    color: .blue
                )

                StatBox(
                    title: "Installed",
                    value: "\(playlist.installedCount)",
                    icon: "checkmark.circle",
                    color: .green
                )

                StatBox(
                    title: "Missing",
                    value: "\(playlist.missingCount)",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )

                StatBox(
                    title: "Tracks",
                    value: "\(playlist.trackNames.count)",
                    icon: "waveform",
                    color: .purple
                )

                Spacer()
            }
        }
        .padding()
    }
}

private struct StatBox: View {

    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Track Section

private struct TrackSection: View {

    let trackName: String
    let entries: [DAWPlaylistEntry]
    let isExpanded: Bool
    let onToggle: () -> Void

    var installedCount: Int {
        entries.filter { $0.isInstalled }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Track header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)

                    Text(trackName)
                        .font(.headline)

                    Spacer()

                    // Plugin count badge
                    Text("\(installedCount)/\(entries.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(installedCount == entries.count ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(installedCount == entries.count ? .green : .orange)
                        .cornerRadius(4)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Plugin list
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(entries) { entry in
                        PluginEntryRow(entry: entry)
                    }
                }
                .padding(.leading, 32)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Plugin Entry Row

private struct PluginEntryRow: View {

    let entry: DAWPlaylistEntry

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: entry.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(entry.isInstalled ? .green : .orange)
                .frame(width: 20)

            // Plugin info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.pluginName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(entry.pluginManufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(entry.pluginFormat.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !entry.isInstalled {
                        Text("• Not Installed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Device index
            Text("#\(entry.deviceIndex + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(entry.isInstalled ? Color.clear : Color.orange.opacity(0.05))
        .cornerRadius(6)
    }
}
