//
//  DAWImportView.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import SwiftUI

#if os(macOS)
import AppKit

/// macOS view for importing DAW projects
struct DAWImportView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scanner: PluginScanner
    @ObservedObject private var playlistManager = DAWPlaylistManager.shared

    @State private var showImportDialog = false
    @State private var showSuccess = false
    @State private var importedPlaylist: DAWPlaylist?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {

            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Import DAW Project")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import plugins from any of 18 supported DAWs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)

            Spacer()

            // Import button or progress
            if playlistManager.isImporting {
                VStack(spacing: 16) {
                    ProgressView(value: playlistManager.importProgress) {
                        Text("Importing project...")
                            .font(.subheadline)
                    }
                    .progressViewStyle(.linear)
                    .frame(width: 300)

                    Text("\(Int(playlistManager.importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: selectProjectFile) {
                    Label("Select Project File", systemImage: "folder")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()

            // Recent playlists
            if !playlistManager.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Imports")
                        .font(.headline)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(playlistManager.playlistsByDate.prefix(5))) { playlist in
                                PlaylistRow(playlist: playlist)
                            }
                        }
                    }
                    .frame(height: 200)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Import Successful", isPresented: $showSuccess) {
            Button("OK") {
                showSuccess = false
            }
        } message: {
            if let playlist = importedPlaylist {
                let stats = PluginMatcher.calculateStats(for: playlist.entries)
                Text("Imported \(stats.totalPlugins) plugins from \(playlist.name)\n\n✅ \(stats.matchedPlugins) installed\n❌ \(stats.missingPlugins) missing")
            }
        }
        .alert("Import Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Actions

    private func selectProjectFile() {
        let panel = NSOpenPanel()
        panel.title = "Select DAW Project"
        panel.message = "Choose a project file from any of 18 supported DAWs"

        // All 18 supported DAW file extensions
        panel.allowedContentTypes = [
            .init(filenameExtension: "als"), .init(filenameExtension: "logicx"), .init(filenameExtension: "band"), .init(filenameExtension: "concert"), .init(filenameExtension: "cpr"), .init(filenameExtension: "npr"), .init(filenameExtension: "song"), .init(filenameExtension: "ptx"), .init(filenameExtension: "txt"), .init(filenameExtension: "bwproject"), .init(filenameExtension: "reason"), .init(filenameExtension: "rpp"), .init(filenameExtension: "motu"), .init(filenameExtension: "flp"), .init(filenameExtension: "tracktionedit"), // Tracktion
            .init(filenameExtension: "ardour"), .init(filenameExtension: "mixbus"), .init(filenameExtension: "xrns")        // Renoise
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task {
                await importProject(url: url)
            }
        }
    }

    private func importProject(url: URL) async {
        do {
            let plugins = scanner.plugins.map(AppPluginItem.init)
            let playlist = try await playlistManager.importProject(
                url: url, installedPlugins: plugins
            )

            await MainActor.run {
                // Add playlist to manager (triggers AI enrichment)
                playlistManager.addPlaylists([playlist])

                importedPlaylist = playlist
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Playlist Row

private struct PlaylistRow: View {

    let playlist: DAWPlaylist

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: dawIcon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("\(playlist.entries.count) plugins", systemImage: "square.grid.3x3")
                        .font(.caption)

                    if playlist.missingCount > 0 {
                        Label("\(playlist.missingCount) missing", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if #available(macOS 12.0, *) {
                        Text(playlist.dateImported, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(dateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Stats badge
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(playlist.installedCount)/\(playlist.entries.count)")
                    .font(.headline)
                    .foregroundColor(playlist.missingCount == 0 ? .green : .orange)

                Text("installed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: playlist.dateImported, relativeTo: Date())
    }

    // MARK: - Helpers

    private var dawIcon: String {
        guard let dawType = playlist.dawType else {
            return "music.note"  // Default for custom playlists
        }

        switch dawType {
        case .abletonLive: return "waveform"
        case .logicPro: return "music.quarternote.3"
        case .garageBand: return "guitars"
        case .mainStage: return "play.circle"
        case .studioOne: return "music.note.house.fill"
        case .cubase: return "square.grid.3x3.square"
        case .nuendo: return "square.grid.3x3.fill.square"
        case .digitalPerformer: return "metronome.fill"
        case .reaper: return "slider.horizontal.3"
        case .reason: return "line.3.crossed.swirl.circle.fill"
        case .proTools: return "waveform.path.ecg"
        case .bitwig: return "circle.hexagongrid.fill"
        case .flStudio: return "waveform.path.badge.plus"
        case .tracktion: return "waveform.badge.magnifyingglass"
        case .ardour: return "waveform.circle"
        case .mixbus: return "slider.vertical.3"
        case .renoise: return "square.grid.3x2"
        }
    }
}

#endif