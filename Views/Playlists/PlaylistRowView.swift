//
//  PlaylistRowView.swift
//  Plugin Reporter
//
//  Created by Plugin Reporter on 2025-10-21.
//  Extracted from ContentView.swift
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Playlist Row View

#if os(macOS)
struct PlaylistRowView: View {
    let playlist: DAWPlaylist
    let isActive: Bool
    let isDropTarget: Bool  // New parameter for drop target state
    @State private var isHovered = false
    var onDelete: (() -> Void)? = nil
    var onRatingChange: ((Int) -> Void)? = nil
    @EnvironmentObject private var prefs: AppPreferences

    private var rowBackground: Color {
        // Drop target gets special highlighting
        if isDropTarget {
            return Color.accentColor.opacity(0.3)
        }

        // Active highlight color based on playlist type
        let activeColor = playlist.playlistType == .custom ? Color.yellow : Color.green

        if prefs.appearance == .space {
            // Space mode: dark grey background
            if isActive {
                return activeColor.opacity(0.2)
            } else if isHovered {
                return Color.white.opacity(0.15)
            } else {
                return Color.white.opacity(0.1)
            }
        } else {
            // Other modes: existing behavior
            if isActive {
                return activeColor.opacity(0.2)
            } else if isHovered {
                return Color.secondary.opacity(0.2)
            } else {
                return Color.secondary.opacity(0.1)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack(alignment: .bottomTrailing) {
                        // Main icon - different for custom vs DAW playlists
                        let mainIcon = playlist.playlistType == .custom ? "folder.fill" : "music.note.list"
                        let iconColor: Color = playlist.playlistType == .custom ? .yellow : .green

                        Image(systemName: isActive ? "checkmark.circle.fill" : mainIcon)
                            .foregroundColor(iconColor)
                            .font(.title3)

                        // Show "+" badge when this is a drop target
                        if isDropTarget {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                                .background(Color(nsColor: .windowBackgroundColor))
                                .clipShape(Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.name)
                            .font(.headline)
                            .lineLimit(1)

                        // Show version if available, otherwise fall back to dawType or "Custom"
                        Text(playlist.version ?? (playlist.dawType?.rawValue ?? "Custom"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.trailing, 24)  // Make room for delete button

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption2)
                        Text("\(playlist.entries.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("\(playlist.installedCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.green)

                    Spacer()
                }

                // 5-Star Rating Display (always visible and clickable)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: (playlist.rating ?? 0) >= star ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor((playlist.rating ?? 0) >= star ? .yellow : .gray.opacity(0.3))
                            .onTapGesture {
                                // If clicking the current rating, unset it (set to 0)
                                // Otherwise, set to the clicked star
                                let newRating = (playlist.rating == star) ? 0 : star
                                onRatingChange?(newRating)
                            }
                    }
                }

                HStack {
                    Text("\(playlist.dateImported.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Blue chevron aligned with timestamp
                    if !isActive {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(12)
            .background(rowBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        playlist.playlistType == .custom ? Color.yellow : Color.green,
                        lineWidth: isActive ? 2 : 1
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }

            // Delete button in top-right corner (show on hover OR when active/selected)
            if isHovered || isActive {
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .padding(8)
                .offset(x: 4, y: -4)
            }
        }
    }
}
#endif
