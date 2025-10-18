//
//  PlaylistMetadataPanel.swift
//  Plugin Reporter
//
//  Editable metadata panel for DAW playlists
//

import SwiftUI

#if os(macOS)
struct PlaylistMetadataPanel: View {
    let playlist: DAWPlaylist?
    @Binding var isVisible: Bool

    @StateObject private var playlistManager = DAWPlaylistManager.shared
    @EnvironmentObject private var prefs: Preferences

    @State private var editedName: String = ""
    @State private var editedTempo: String = ""
    @State private var editedSampleRate: String = ""
    @State private var editedKey: String = ""
    @State private var editedVersion: String = ""

    private let panelWidth: CGFloat = 350

    private var backgroundColor: Color {
        prefs.appearance == .space ? Color.black : Color(nsColor: .windowBackgroundColor)
    }

    private var textFieldBackground: Color {
        prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(nsColor: .textBackgroundColor)
    }

    var body: some View {
        if isVisible, let playlist = playlist {
            VStack(alignment: .leading, spacing: 0) {
                // Title (matching DAW Playlists sidebar style)
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text("Metadata")
                        .font(.headline)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 17)

                Divider()

                // Header
                headerSection(playlist: playlist)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Project Info Section
                        projectInfoSection(playlist: playlist)

                        Divider()

                        // Editable Metadata Section
                        metadataSection(playlist: playlist)

                        Divider()

                        // Statistics Section
                        statisticsSection(playlist: playlist)
                    }
                    .padding(16)
                }
            }
            .frame(width: panelWidth)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1),
                alignment: .leading
            )
            .onAppear {
                // Initialize edit fields with current values
                editedName = playlist.name
                editedTempo = playlist.tempo.map { String(format: "%.1f", $0) } ?? ""
                editedSampleRate = playlist.sampleRate.map { String($0) } ?? ""
                editedKey = playlist.key ?? ""
                editedVersion = playlist.version ?? ""
            }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(playlist: DAWPlaylist) -> some View {
        HStack(spacing: 12) {
            // Playlist icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.6), Color.green.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Image(systemName: "music.note.list")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(playlist.dawType.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(playlist.dateImported.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Project Info Section

    @ViewBuilder
    private func projectInfoSection(playlist: DAWPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Info")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Source File", value: playlist.sourceFile.lastPathComponent)
                infoRow(label: "Path", value: playlist.sourceFile.path)
                infoRow(label: "DAW Type", value: playlist.dawType.rawValue)
                infoRow(label: "Imported", value: playlist.dateImported.formatted(date: .long, time: .standard))
            }
        }
    }

    // MARK: - Metadata Section (Editable)

    @ViewBuilder
    private func metadataSection(playlist: DAWPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Playlist name", text: $editedName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(textFieldBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editedName) { newValue in
                            updatePlaylistMetadata(playlist, name: newValue)
                        }
                }

                // Tempo/BPM
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "metronome")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        Text("Tempo (BPM)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField("120.0", text: $editedTempo)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(textFieldBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editedTempo) { newValue in
                            if let tempo = Double(newValue) {
                                updatePlaylistMetadata(playlist, tempo: tempo)
                            }
                        }
                }

                // Sample Rate
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("Sample Rate (Hz)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField("44100", text: $editedSampleRate)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(textFieldBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editedSampleRate) { newValue in
                            if let sampleRate = Int(newValue) {
                                updatePlaylistMetadata(playlist, sampleRate: sampleRate)
                            }
                        }
                }

                // Musical Key
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.pink)
                        Text("Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField("C", text: $editedKey)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(textFieldBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editedKey) { newValue in
                            updatePlaylistMetadata(playlist, key: newValue)
                        }
                }

                // Version
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAW Version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Version", text: $editedVersion)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(textFieldBackground)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: editedVersion) { newValue in
                            updatePlaylistMetadata(playlist, version: newValue)
                        }
                }
            }
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private func statisticsSection(playlist: DAWPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                statRow(label: "Total Plugins", value: "\(playlist.entries.count)", color: .blue)
                statRow(label: "Installed", value: "\(playlist.installedCount)", color: .green)
                statRow(label: "Missing", value: "\(playlist.missingCount)", color: .red)
                statRow(label: "Unique Plugins", value: "\(playlist.uniquePlugins.count)", color: .purple)
                statRow(label: "Tracks", value: "\(playlist.trackNames.count)", color: .orange)
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Update Logic

    private func updatePlaylistMetadata(
        _ playlist: DAWPlaylist,
        name: String? = nil,
        tempo: Double? = nil,
        sampleRate: Int? = nil,
        key: String? = nil,
        version: String? = nil
    ) {
        // Create updated playlist
        let updated = DAWPlaylist(
            id: playlist.id,
            name: name ?? playlist.name,
            sourceFile: playlist.sourceFile,
            dawType: playlist.dawType,
            dateImported: playlist.dateImported,
            entries: playlist.entries,
            tempo: tempo ?? playlist.tempo,
            sampleRate: sampleRate ?? playlist.sampleRate,
            version: version ?? playlist.version,
            key: key ?? playlist.key
        )

        // Update in manager
        playlistManager.updatePlaylist(updated)
    }
}

// Preview
struct PlaylistMetadataPanel_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistMetadataPanel(
            playlist: DAWPlaylist(
                name: "Test Project",
                sourceFile: URL(fileURLWithPath: "/test.als"),
                dawType: .abletonLive,
                entries: [],
                tempo: 120.0,
                sampleRate: 44100,
                version: "Ableton Live 11",
                key: "C"
            ),
            isVisible: .constant(true)
        )
        .frame(height: 600)
    }
}
#endif
