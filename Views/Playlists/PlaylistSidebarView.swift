//
//  PlaylistSidebarView.swift
//  Plugin Reporter
//
//  Created by Plugin Reporter on 2025-10-21.
//  Extracted from ContentView.swift
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// MARK: - Playlist Sidebar View with Keyboard Navigation

#if os(macOS)
struct PlaylistSidebarView: View {
    let playlists: [DAWPlaylist]
    @Binding var activePlaylists: [DAWPlaylist]
    @Binding var showDetailPanel: Bool
    let onSelect: ([DAWPlaylist], EventModifiers) -> Void
    let onDelete: (DAWPlaylist) -> Void
    let onEditMetadata: () -> Void  // Callback when Edit Metadata is clicked
    let onImport: () -> Void  // Callback when + button is clicked
    @ObservedObject var playlistManager: DAWPlaylistManager
    @EnvironmentObject private var prefs: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedIndex: Int = 0
    @State private var lastClickedIndex: Int = 0
    @FocusState private var isFocused: Bool
    @State private var playlistsToDelete: [DAWPlaylist] = []
    @State private var showDeleteConfirmation = false
    @State private var dropTargetPlaylistID: UUID? = nil  // Track which playlist is being targeted

    private var backgroundColor: Color {
        prefs.appearance == .space ? Color.black : Color(nsColor: .windowBackgroundColor)
    }

    private var secondaryTextColor: Color {
        colorScheme == .light ? Color.black.opacity(0.55) : .secondary
    }

    private var sortedPlaylists: [DAWPlaylist] {
        // First, filter by star ratings if any selected
        var filtered = playlists
        if !playlistManager.selectedPlaylistStarRatings.isEmpty {
            filtered = filtered.filter { playlist in
                guard let rating = playlist.rating else { return false }
                return playlistManager.selectedPlaylistStarRatings.contains(rating)
            }
        }

        // Filter by DAW types if any selected
        if !playlistManager.selectedDAWTypes.isEmpty {
            filtered = filtered.filter { playlist in
                guard let dawType = playlist.dawType else { return false }
                return playlistManager.selectedDAWTypes.contains(dawType)
            }
        }

        // Filter by missing plugins if enabled
        if playlistManager.showOnlyMissingPlaylists {
            filtered = filtered.filter { playlist in
                playlist.entries.contains { entry in !entry.isInstalled }
            }
        }

        // Then, apply sorting
        switch playlistManager.playlistSortOption {
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateImported:
            return filtered.sorted { $0.dateImported > $1.dateImported }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            if prefs.appearance == .space {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
            } else if colorScheme == .light {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 1)
            } else {
                Divider()
            }
            contentView
        }
        .frame(width: 350)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
        .overlay(
            Rectangle()
                .fill(prefs.appearance == .space ? Color.white.opacity(0.15) : (colorScheme == .light ? Color.black.opacity(0.5) : Color.clear))
                .frame(height: 1),
            alignment: .top
        )
        .onAppear {
            isFocused = true
        }
        .alert(playlistsToDelete.count > 1 ? "Remove Playlists?" : "Remove Playlist?",
               isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                playlistsToDelete = []
            }
            Button("Remove", role: .destructive) {
                // Use batch delete for undo support
                if playlistsToDelete.count > 1 {
                    playlistManager.deletePlaylists(playlistsToDelete)
                    // Remove from active filters
                    let idsToDelete = Set(playlistsToDelete.map { $0.id })
                    activePlaylists.removeAll { idsToDelete.contains($0.id) }
                    // MUST update displayed plugins after removing filters!
                    onSelect(activePlaylists, [])
                } else if let playlist = playlistsToDelete.first {
                    onDelete(playlist)
                }
                playlistsToDelete = []
            }
        } message: {
            if playlistsToDelete.count == 1, let playlist = playlistsToDelete.first {
                Text("Are you sure you want to remove the playlist \"\(playlist.name)\"?")
            } else if playlistsToDelete.count > 1 {
                let playlistNames = playlistsToDelete.map { "• \($0.name)" }.joined(separator: "\n")
                Text("Are you sure you want to remove the following playlists?\n\n\(playlistNames)")
            }
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("DAW Playlists")
                    .font(.system(size: 12, weight: .medium))

                if playlists.count > 0 {
                    Text("(\(playlists.count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }

                // + Button moved next to count
                Button(action: onImport) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Create Custom Playlist")
            }

            Spacer()

            // Sort/Filter Menu
            Menu {
                Section(header: Text("Sort By")) {
                    if playlistManager.playlistSortOption == .dateImported {
                        Button(action: { playlistManager.playlistSortOption = .dateImported }) {
                            Text("Date Imported")
                        }
                        .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                    } else {
                        Button(action: { playlistManager.playlistSortOption = .dateImported }) {
                            Text("Date Imported")
                        }
                    }

                    if playlistManager.playlistSortOption == .name {
                        Button(action: { playlistManager.playlistSortOption = .name }) {
                            Text("Name")
                        }
                        .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                    } else {
                        Button(action: { playlistManager.playlistSortOption = .name }) {
                            Text("Name")
                        }
                    }
                }

                Section(header: Text("Filter By")) {
                    if playlistManager.showOnlyMissingPlaylists {
                        Button(action: { playlistManager.showOnlyMissingPlaylists.toggle() }) {
                            Text("Missing")
                        }
                        .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                    } else {
                        Button(action: { playlistManager.showOnlyMissingPlaylists.toggle() }) {
                            Text("Missing")
                        }
                    }
                    // DAW Type submenu
                    Menu {
                        ForEach(DAWType.allCases, id: \.self) { dawType in
                            Button(action: {
                                if playlistManager.selectedDAWTypes.contains(dawType) {
                                    playlistManager.selectedDAWTypes.remove(dawType)
                                } else {
                                    playlistManager.selectedDAWTypes.insert(dawType)
                                }
                            }) {
                                HStack {
                                    Text(dawType.rawValue)
                                    Spacer()
                                    if playlistManager.selectedDAWTypes.contains(dawType) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("DAW Type")
                            Spacer()
                        }
                    }

                    // Rating submenu
                    Menu {
                        Button(action: {
                            if playlistManager.selectedPlaylistStarRatings.contains(5) {
                                playlistManager.selectedPlaylistStarRatings.remove(5)
                            } else {
                                playlistManager.selectedPlaylistStarRatings.insert(5)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("⭐️⭐️⭐️⭐️⭐️")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .fixedSize()
                                Spacer()
                                if playlistManager.selectedPlaylistStarRatings.contains(5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        Button(action: {
                            if playlistManager.selectedPlaylistStarRatings.contains(4) {
                                playlistManager.selectedPlaylistStarRatings.remove(4)
                            } else {
                                playlistManager.selectedPlaylistStarRatings.insert(4)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("⭐️⭐️⭐️⭐️")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .fixedSize()
                                Spacer()
                                if playlistManager.selectedPlaylistStarRatings.contains(4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        Button(action: {
                            if playlistManager.selectedPlaylistStarRatings.contains(3) {
                                playlistManager.selectedPlaylistStarRatings.remove(3)
                            } else {
                                playlistManager.selectedPlaylistStarRatings.insert(3)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("⭐️⭐️⭐️")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .fixedSize()
                                Spacer()
                                if playlistManager.selectedPlaylistStarRatings.contains(3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        Button(action: {
                            if playlistManager.selectedPlaylistStarRatings.contains(2) {
                                playlistManager.selectedPlaylistStarRatings.remove(2)
                            } else {
                                playlistManager.selectedPlaylistStarRatings.insert(2)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("⭐️⭐️")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .fixedSize()
                                Spacer()
                                if playlistManager.selectedPlaylistStarRatings.contains(2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }

                        Button(action: {
                            if playlistManager.selectedPlaylistStarRatings.contains(1) {
                                playlistManager.selectedPlaylistStarRatings.remove(1)
                            } else {
                                playlistManager.selectedPlaylistStarRatings.insert(1)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("⭐️")
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .fixedSize()
                                Spacer()
                                if playlistManager.selectedPlaylistStarRatings.contains(1) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Rating")
                            Spacer()
                        }
                    }
                }

                // Clear All section
                Section {
                    Button(action: {
                        playlistManager.playlistSortOption = .dateImported
                        playlistManager.selectedPlaylistStarRatings.removeAll()
                        playlistManager.selectedDAWTypes.removeAll()
                        playlistManager.showOnlyMissingPlaylists = false
                    }) {
                        Text("Clear All")
                    }
                    .keyboardShortcut(KeyEquivalent("x"), modifiers: [])
                    .foregroundStyle(.white)
                }
            } label: {
                Image(systemName: "line.3.horizontal.circle")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .help("Sort and Filter Playlists")
        }
        .padding(15)
    }

    @ViewBuilder
    private var contentView: some View {
        if playlists.isEmpty {
            emptyStateView
        } else {
            playlistListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(secondaryTextColor)

            Text("No Playlists")
                .font(.headline)
                .foregroundColor(secondaryTextColor)

            Text("Import an Ableton Live project to get started")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var playlistListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(sortedPlaylists.enumerated()), id: \.element.id) { index, playlist in
                        playlistButton(index: index, playlist: playlist)
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, 16)
                .padding(.vertical, 16)
            }
            .focusable()
            .focused($isFocused)
            .applyIfAvailableMac14FocusDisabled()
            .onMoveCommand { direction in
                handleKeyboardNavigation(direction: direction, proxy: proxy)
            }
            .onDeleteCommand {
                handleDeleteKey()
            }
            .onAppear {
                // Select the first active playlist if any
                if let firstActive = activePlaylists.first,
                   let index = sortedPlaylists.firstIndex(where: { $0.id == firstActive.id }) {
                    selectedIndex = index
                }
                isFocused = true
            }
        }
    }

    private func playlistButton(index: Int, playlist: DAWPlaylist) -> some View {
        Button(action: {
            #if os(macOS)
            let modifiers = NSEvent.modifierFlags

            // Control-click is handled by contextMenu, so skip it here
            if !modifiers.contains(.control) {
                var eventMods: EventModifiers = []

                if modifiers.contains(.shift) {
                    eventMods.insert(.shift)
                    // Shift-click: select range from lastClickedIndex to current index
                    let start = min(lastClickedIndex, index)
                    let end = max(lastClickedIndex, index)
                    let rangeSelection = Array(sortedPlaylists[start...end])
                    onSelect(rangeSelection, eventMods)
                    selectedIndex = index
                } else if modifiers.contains(.command) {
                    eventMods.insert(.command)
                    // CMD-click: toggle single item
                    onSelect([playlist], eventMods)
                    lastClickedIndex = index
                    selectedIndex = index
                } else {
                    // Normal click: single selection
                    onSelect([playlist], eventMods)
                    lastClickedIndex = index
                    selectedIndex = index
                }
            }
            #else
            onSelect([playlist], [])
            selectedIndex = index
            lastClickedIndex = index
            #endif
        }) {
            PlaylistRowView(
                playlist: playlist,
                isActive: activePlaylists.contains(where: { $0.id == playlist.id }),
                isDropTarget: dropTargetPlaylistID == playlist.id,
                onDelete: {
                    // If this playlist is part of a multi-selection, delete all selected
                    // Otherwise, just delete this one
                    if activePlaylists.contains(where: { $0.id == playlist.id }) && activePlaylists.count > 1 {
                        playlistsToDelete = activePlaylists
                    } else {
                        playlistsToDelete = [playlist]
                    }
                    showDeleteConfirmation = true
                },
                onRatingChange: { newRating in
                    updatePlaylistRating(playlist, rating: newRating)
                }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Context menu for Control-click / Right-click
            let selectedCount = activePlaylists.count
            let isPartOfSelection = activePlaylists.contains(where: { $0.id == playlist.id })

            // Edit Metadata - only for single playlist
            if selectedCount == 1 && isPartOfSelection {
                Button {
                    // Clear plugin selection and show playlist metadata
                    onEditMetadata()
                    showDetailPanel = true
                } label: {
                    Label("Edit Metadata", systemImage: "pencil")
                }

                Divider()
            }

            Button(role: .destructive) {
                // Delete all selected playlists if this is part of selection
                if isPartOfSelection && selectedCount > 1 {
                    playlistsToDelete = activePlaylists
                } else {
                    playlistsToDelete = [playlist]
                }
                showDeleteConfirmation = true
            } label: {
                if isPartOfSelection && selectedCount > 1 {
                    Label("Remove \(selectedCount) Playlists", systemImage: "trash")
                } else {
                    Label("Remove Playlist", systemImage: "trash")
                }
            }
        }
        .id(index)
        #if os(macOS)
        .onDrop(of: [UTType(exportedAs: "com.vibeaudio.pluginreporter.plugin")], isTargeted: Binding(
            get: { dropTargetPlaylistID == playlist.id },
            set: { isTargeted in
                print("🎯 Drop target changed for \(playlist.name): \(isTargeted)")
                // Only show drop target for custom playlists
                if isTargeted && playlist.playlistType == .custom {
                    dropTargetPlaylistID = playlist.id
                } else if !isTargeted && dropTargetPlaylistID == playlist.id {
                    dropTargetPlaylistID = nil
                }
            }
        )) { providers in
            print("🎁 Drop received on \(playlist.name) with \(providers.count) provider(s)")

            // Only allow drops on custom playlists
            guard playlist.playlistType == .custom else {
                print("⚠️ Cannot drop on DAW playlists (read-only)")
                return false
            }

            handlePluginDrop(providers: providers, to: playlist)
            return true
        }
        #endif
    }

    private func handleKeyboardNavigation(direction: MoveCommandDirection, proxy: ScrollViewProxy) {
        #if os(macOS)
        let modifiers = NSEvent.modifierFlags
        let isShift = modifiers.contains(.shift)
        #else
        let isShift = false
        #endif

        switch direction {
        case .down:
            // Arrow Down
            moveSelection(delta: 1, proxy: proxy, extendSelection: isShift)
        case .up:
            // Arrow Up
            moveSelection(delta: -1, proxy: proxy, extendSelection: isShift)
        default:
            break
        }
    }

    private func handleDeleteKey() {
        // Delete all active playlists when Delete key is pressed
        guard !activePlaylists.isEmpty else { return }

        playlistsToDelete = activePlaylists
        showDeleteConfirmation = true
    }

    private func moveSelection(delta: Int, proxy: ScrollViewProxy, extendSelection: Bool) {
        guard !playlists.isEmpty else { return }

        let newIndex = min(max(selectedIndex + delta, 0), playlists.count - 1)

        if newIndex != selectedIndex {
            selectedIndex = newIndex

            if extendSelection {
                // Shift+Arrow: extend selection from lastClickedIndex to new position
                let start = min(lastClickedIndex, newIndex)
                let end = max(lastClickedIndex, newIndex)
                let rangeSelection = Array(playlists[start...end])
                onSelect(rangeSelection, .shift)
            } else {
                // Normal arrow: single selection
                onSelect([sortedPlaylists[newIndex]], [])
                lastClickedIndex = newIndex
            }

            // Scroll to keep selection visible (no animation to reduce flicker)
            proxy.scrollTo(newIndex, anchor: .center)
        }
    }

    #if os(macOS)
    private func handlePluginDrop(providers: [NSItemProvider], to playlist: DAWPlaylist) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: "com.vibeaudio.pluginreporter.plugin") { data, error in
                guard let data = data else {
                    print("⚠️ Failed to load drag data: \(error?.localizedDescription ?? "unknown error")")
                    return
                }

                guard let pluginData = try? JSONDecoder().decode(PluginDragData.self, from: data) else {
                    print("⚠️ Failed to decode plugin data")
                    return
                }

                // Process all plugins in the drag
                DispatchQueue.main.async {
                    var addedCount = 0
                    for pluginInfo in pluginData.plugins {
                        // Create a PluginItem from the drag data
                        let plugin = PluginItem(
                            name: pluginInfo.name,
                            publisher: pluginInfo.publisher,
                            type: pluginInfo.type,
                            path: pluginInfo.path
                        )

                        self.playlistManager.addPlugin(plugin, to: playlist)
                        addedCount += 1
                    }

                    if addedCount > 1 {
                        print("✅ Added \(addedCount) plugins to \(playlist.name)")
                    } else if addedCount == 1 {
                        print("✅ Added \(pluginData.plugins[0].name) to \(playlist.name)")
                    }
                }
            }
        }
    }
    #endif

    private func updatePlaylistRating(_ playlist: DAWPlaylist, rating: Int) {
        // Create updated playlist with new rating
        let updated: DAWPlaylist
        if playlist.playlistType == .custom {
            updated = DAWPlaylist(
                id: playlist.id,
                name: playlist.name,
                dateImported: playlist.dateImported,
                entries: playlist.entries,
                tempo: playlist.tempo,
                sampleRate: playlist.sampleRate,
                version: playlist.version,
                key: playlist.key,
                rating: rating
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id,
                name: playlist.name,
                sourceFile: playlist.sourceFile!,
                dawType: playlist.dawType!,
                dateImported: playlist.dateImported,
                entries: playlist.entries,
                tempo: playlist.tempo,
                sampleRate: playlist.sampleRate,
                version: playlist.version,
                key: playlist.key,
                rating: rating
            )
        }

        // Update in manager
        playlistManager.updatePlaylist(updated)
    }
}
#endif
