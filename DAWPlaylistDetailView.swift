//
//  DAWPlaylistDetailView.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import SwiftUI
import AppKit

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
                            trackName: trackName, entries: filteredEntries(for: trackName), isExpanded: expandedTracks.contains(trackName), onToggle: { toggleTrack(trackName) }
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
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.publisher.localizedCaseInsensitiveContains(searchText)
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
        var csv = "Track,Plugin Name,Manufacturer,Format,Status,Device Index,Preset\n"

        for trackName in PluginMatcher.sortedTrackNames(playlist.entries) {
            let entries = playlist.entries(forTrack: trackName)
            for entry in entries {
                let status = entry.isInstalled ? "Installed" : "Missing"
                let preset = entry.preset.isEmpty ? "" : entry.preset
                let row = "\"\(trackName)\",\"\(entry.name)\",\"\(entry.publisher)\",\"\(entry.type)\",\"\(status)\",\(entry.deviceIndex + 1),\"\(preset)\"\n"
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
                    title: "Total Plugins", value: "\(playlist.entries.count)", icon: "square.grid.3x3", color: .blue
                )

                StatBox(
                    title: "Installed", value: "\(playlist.installedCount)", icon: "checkmark.circle", color: .green
                )

                StatBox(
                    title: "Missing", value: "\(playlist.missingCount)", icon: "exclamationmark.triangle", color: .orange
                )

                StatBox(
                    title: "Tracks", value: "\(playlist.trackNames.count)", icon: "waveform", color: .purple
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

// MARK: - Custom Resizable Window
// Moved to: Helpers/ResizableWindow.swift

// MARK: - Plugin Entry Row

private struct PluginEntryRow: View {

    let entry: DAWPlaylistEntry
    @EnvironmentObject var appState: AppState

    // Keep strong reference to window
    @State private var aiSuggestionsWindow: ResizableWindow?

    var body: some View {
        _ = print("🖥️ [DISPLAY] Rendering plugin entry:")
        _ = print("   • name: '\(entry.name)'")
        _ = print("   • publisher: '\(entry.publisher)'")
        _ = print("   • type: '\(entry.type)'")
        _ = print("   • isInstalled: \(entry.isInstalled)")
        _ = print("   • version: '\(entry.version)'")
        _ = print("   • style: '\(entry.style)'")
        _ = print("   • architectures: '\(entry.architectures)'")

        return HStack(spacing: 12) {
            // Status icon
            Image(systemName: entry.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(entry.isInstalled ? .green : .orange)
                .frame(width: 20)

            // Plugin info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    // Display publisher directly - parser filled, AI validated/enriched
                    Text(entry.publisher)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(entry.type)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !entry.isInstalled {
                        Text("• Not Installed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Show enriched metadata for missing plugins (parser or AI filled)
                if !entry.isInstalled {
                    HStack(spacing: 8) {
                        if !entry.version.isEmpty {
                            Text("v\(entry.version)")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }

                        if !entry.style.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(entry.style)
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }

                        if !entry.architectures.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(entry.architectures)
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }

                // Show preset for all plugins (installed or not)
                if !entry.preset.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                            .foregroundColor(.purple.opacity(0.7))
                        Text("Preset: \(entry.preset)")
                            .font(.caption2)
                            .foregroundColor(.purple.opacity(0.9))
                    }
                }
            }

            Spacer()

            // AI Suggestions button for missing plugins
            if !entry.isInstalled {
                Button {
                    openAISuggestionsWindow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Your Alternatives")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Find owned plugins that can replace this missing plugin")
            }

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

    private func openAISuggestionsWindow() {
        // Create plugin item from entry
        let pluginItem = PluginItem(
            name: entry.name, publisher: entry.publisher, version: entry.version, type: entry.type, style: entry.style, architectures: "", date: nil, sizeBytes: 0, path: "", runtimeRequirement: "", obsolete: false
        )

        let hostingView = NSHostingView(
            rootView: AISuggestionsView(plugin: pluginItem, ownedPlugins: appState.all)
                .environmentObject(appState)
        )

        // Configure hosting view to respect minimum size constraints
        hostingView.autoresizingMask = [.width, .height]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        // Close existing window if any
        aiSuggestionsWindow?.close()

        // Use custom window class
        let window = ResizableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false
        )

        window.contentView = hostingView
        window.title = "AI Suggestions - \(entry.name)"
        window.minSize = NSSize(width: 520, height: 700)
        window.maxSize = NSSize(width: 1200, height: 1000)
        window.contentMinSize = NSSize(width: 520, height: 700)
        window.contentMaxSize = NSSize(width: 1200, height: 1000)
        window.isReleasedWhenClosed = false

        // Explicitly enable resizing
        window.styleMask.insert(.resizable)

        // CRITICAL: Store strong reference to prevent window from being reset
        aiSuggestionsWindow = window

        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}