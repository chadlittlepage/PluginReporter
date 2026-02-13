//
//  CreateCustomPlaylistView.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/19/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import SwiftUI

#if os(macOS)
/// View for creating a new custom playlist
struct CreateCustomPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playlistManager: DAWPlaylistManager

    @State private var playlistName: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var onCreate: (DAWPlaylist) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Create Custom Playlist")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Build your own curated collection of plugins")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist Name")
                    .font(.headline)

                TextField("e.g., Favorite Reverbs, Mixing Chain, Best Synths", text: $playlistName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)
                    .onSubmit {
                        createPlaylist()
                    }

                Text("Give your playlist a descriptive name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createPlaylist()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(playlistName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 300)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a playlist name"
            showError = true
            return
        }

        // Check for duplicate names
        if playlistManager.playlists.contains(where: { $0.name == trimmedName }) {
            errorMessage = "A playlist named \"\(trimmedName)\" already exists"
            showError = true
            return
        }

        // Create the playlist
        let newPlaylist = playlistManager.createCustomPlaylist(name: trimmedName)

        // Call the completion handler
        onCreate(newPlaylist)

        // Dismiss the sheet
        dismiss()
    }
}
#endif
