//
//  DAWPlaylistManager.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Data Models

/// Type of playlist
enum PlaylistType: String, Codable {
    case dawImport   // Imported from a DAW project file
    case custom      // User-created custom playlist
}

/// A playlist created from a DAW project file (Ableton Live, Logic Pro, etc.) or custom user collection
struct DAWPlaylist: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let sourceFile: URL?  // nil for custom playlists
    let dawType: DAWType?  // nil for custom playlists
    let playlistType: PlaylistType
    let dateImported: Date
    var entries: [DAWPlaylistEntry]  // var to allow adding/removing plugins
    let tempo: Double?
    let sampleRate: Int?
    let version: String?
    let key: String?
    var rating: Int?  // 0-5 star rating for playlist

    // Initializer for DAW-imported playlists
    init(id: UUID = UUID(), name: String, sourceFile: URL, dawType: DAWType, dateImported: Date = Date(), entries: [DAWPlaylistEntry], tempo: Double? = nil, sampleRate: Int? = nil, version: String? = nil, key: String? = nil, rating: Int? = nil) {
        self.id = id
        self.name = name
        self.sourceFile = sourceFile
        self.dawType = dawType
        self.playlistType = .dawImport
        self.dateImported = dateImported
        self.entries = entries
        self.tempo = tempo
        self.sampleRate = sampleRate
        self.version = version
        self.key = key
        self.rating = rating
    }

    // Initializer for custom playlists
    init(id: UUID = UUID(), name: String, dateImported: Date = Date(), entries: [DAWPlaylistEntry] = [], tempo: Double? = nil, sampleRate: Int? = nil, version: String? = nil, key: String? = nil, rating: Int? = nil) {
        self.id = id
        self.name = name
        self.sourceFile = nil
        self.dawType = nil
        self.playlistType = .custom
        self.dateImported = dateImported
        self.entries = entries
        self.tempo = tempo
        self.sampleRate = sampleRate
        self.version = version
        self.key = key
        self.rating = rating
    }

    // Hashable conformance - hash based on unique ID only
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Equatable conformance - compare based on unique ID only
    static func == (lhs: DAWPlaylist, rhs: DAWPlaylist) -> Bool {
        lhs.id == rhs.id
    }

    /// All unique plugins in this playlist
    var uniquePlugins: [String] {
        Array(Set(entries.map { $0.name })).sorted()
    }

    /// Number of installed plugins
    var installedCount: Int {
        entries.filter { $0.isInstalled }.count
    }

    /// Number of missing plugins
    var missingCount: Int {
        entries.filter { !$0.isInstalled }.count
    }

    /// All unique track names
    var trackNames: [String] {
        Array(Set(entries.map { $0.trackName })).sorted()
    }

    /// Get entries for a specific track
    func entries(forTrack trackName: String) -> [DAWPlaylistEntry] {
        entries.filter { $0.trackName == trackName }
    }
}

/// An individual plugin entry in a DAW playlist
/// Field names now match PluginItem for consistency ("fill in the blanks" approach)
struct DAWPlaylistEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String  // Renamed from pluginName to match PluginItem
    var publisher: String  // Renamed from pluginManufacturer, mutable for AI enrichment
    let trackName: String
    let trackIndex: Int
    let deviceIndex: Int
    let type: String  // Renamed from pluginFormat (PluginFormat enum → String)
    let isInstalled: Bool
    let matchedPluginPath: String?  // Path to matched plugin if found

    // Optional metadata - parser fills if available, AI fills gaps
    var version: String  // Parser or AI filled
    var style: String  // Parser or AI filled
    var architectures: String  // Parser or AI filled
    var preset: String  // Parser filled - preset name used in the project

    init(id: UUID = UUID(), name: String, publisher: String, trackName: String, trackIndex: Int, deviceIndex: Int, type: String, isInstalled: Bool, matchedPluginPath: String? = nil, version: String = "", style: String = "", architectures: String = "", preset: String = "") {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.trackName = trackName
        self.trackIndex = trackIndex
        self.deviceIndex = deviceIndex
        self.type = type
        self.isInstalled = isInstalled
        self.matchedPluginPath = matchedPluginPath
        self.version = version
        self.style = style
        self.architectures = architectures
        self.preset = preset
    }

    // Custom encoding to save with new field names
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(trackName, forKey: .trackName)
        try container.encode(trackIndex, forKey: .trackIndex)
        try container.encode(deviceIndex, forKey: .deviceIndex)
        try container.encode(type, forKey: .type)
        try container.encode(isInstalled, forKey: .isInstalled)
        try container.encode(matchedPluginPath, forKey: .matchedPluginPath)
        try container.encode(version, forKey: .version)
        try container.encode(style, forKey: .style)
        try container.encode(architectures, forKey: .architectures)
        try container.encode(preset, forKey: .preset)
    }

    // Legacy initializer for backwards compatibility with saved data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)

        // Handle both old and new field names
        if let newName = try? container.decode(String.self, forKey: .name) {
            name = newName
        } else {
            name = try container.decode(String.self, forKey: .pluginName)
        }

        if let newPublisher = try? container.decode(String.self, forKey: .publisher) {
            publisher = newPublisher
        } else {
            publisher = try container.decode(String.self, forKey: .pluginManufacturer)
        }

        trackName = try container.decode(String.self, forKey: .trackName)
        trackIndex = try container.decode(Int.self, forKey: .trackIndex)
        deviceIndex = try container.decode(Int.self, forKey: .deviceIndex)

        if let newType = try? container.decode(String.self, forKey: .type) {
            type = newType
        } else {
            let format = try container.decode(PluginFormat.self, forKey: .pluginFormat)
            type = format.rawValue
        }

        isInstalled = try container.decode(Bool.self, forKey: .isInstalled)
        matchedPluginPath = try? container.decode(String?.self, forKey: .matchedPluginPath)

        // Handle AI-enriched fields from old format
        if let aiPub = try? container.decode(String.self, forKey: .aiEnrichedPublisher) {
            // If we have AI-enriched publisher and current is Unknown, use AI
            if publisher == "Unknown" || publisher.isEmpty {
                publisher = aiPub
            }
        }

        version = (try? container.decode(String.self, forKey: .version)) ??
                  (try? container.decode(String.self, forKey: .aiEnrichedVersion)) ?? ""
        style = (try? container.decode(String.self, forKey: .style)) ??
                (try? container.decode(String.self, forKey: .aiEnrichedStyle)) ?? ""
        architectures = (try? container.decode(String.self, forKey: .architectures)) ??
                        (try? container.decode(String.self, forKey: .aiEnrichedArchitectures)) ?? ""
        preset = (try? container.decode(String.self, forKey: .preset)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, publisher, trackName, trackIndex, deviceIndex, type, isInstalled, matchedPluginPath
        case version, style, architectures, preset
        // Legacy keys for backwards compatibility
        case pluginName, pluginManufacturer, pluginFormat
        case aiEnrichedPublisher, aiEnrichedVersion, aiEnrichedStyle, aiEnrichedArchitectures
    }

    // Hashable conformance - hash based on unique ID only
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Equatable conformance - compare based on unique ID only
    static func == (lhs: DAWPlaylistEntry, rhs: DAWPlaylistEntry) -> Bool {
        lhs.id == rhs.id
    }
}

/// Supported DAW types
public enum DAWType: String, Codable, Hashable, CaseIterable {
    case abletonLive = "Ableton Live"
    case logicPro = "Logic Pro"
    case garageBand = "GarageBand"
    case mainStage = "MainStage"
    case cubase = "Cubase"
    case nuendo = "Nuendo"
    case studioOne = "Studio One"
    case proTools = "Pro Tools"
    case bitwig = "Bitwig"
    case reason = "Reason Studios"
    case reaper = "Reaper"
    case digitalPerformer = "Digital Performer"
    case flStudio = "FL Studio"
    case tracktion = "Tracktion Waveform"
    case ardour = "Ardour"
    case mixbus = "Mixbus"
    case renoise = "Renoise"

    var fileExtension: String {
        switch self {
        case .abletonLive: return "als"
        case .logicPro: return "logic"
        case .garageBand: return "band"
        case .mainStage: return "concert"
        case .cubase: return "cpr"
        case .nuendo: return "npr"
        case .studioOne: return "song"
        case .proTools: return "ptx"
        case .bitwig: return "bwproject"
        case .reason: return "reason"
        case .reaper: return "rpp"
        case .digitalPerformer: return "motu"
        case .flStudio: return "flp"
        case .tracktion: return "tracktionedit"
        case .ardour: return "ardour"
        case .mixbus: return "mixbus"
        case .renoise: return "xrns"
        }
    }
}

// MARK: - Manager

/// Manages DAW playlists - importing, storing, and accessing
@MainActor
class DAWPlaylistManager: ObservableObject {

    static let shared = DAWPlaylistManager()

    @Published private(set) var playlists: [DAWPlaylist] = []
    @Published private(set) var isImporting = false
    @Published private(set) var importProgress: Double = 0.0
    @Published private(set) var lastError: Error?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    // Playlist UI state
    @Published var playlistSortOption: PlaylistSortOption = .dateImported
    @Published var showOnlyMissingPlaylists: Bool = false
    @Published var selectedPlaylistStarRatings: Set<Int> = []
    @Published var selectedDAWTypes: Set<DAWType> = []

    enum PlaylistSortOption: String {
        case dateImported
        case name
    }

    private let storageKey = "DAWPlaylists"
    private var cancellables = Set<AnyCancellable>()

    #if os(macOS)
    let undoManager = UndoManager()
    #endif

    private init() {
        loadPlaylists()
    }

    // MARK: - Import

    /// Import a DAW project file and create a playlist
    func importProject(url: URL, installedPlugins: [PluginItem]) async throws -> DAWPlaylist {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isImporting = false
                importProgress = 0.0
            }
        }

        let startTime = Date()

        // Determine DAW type from file extension
        let dawType = detectDAWType(from: url)
        print("⏱️ Detect DAW type: \(Date().timeIntervalSince(startTime))s")

        await updateProgress(0.2)

        // Parse the project file using the parser registry
        let parseStart = Date()
        let parsedProject: ParsedProject
        parsedProject = try DAWParserRegistry.shared.parseProject(url: url, dawType: dawType)
        print("⏱️ Parse project: \(Date().timeIntervalSince(parseStart))s")

        await updateProgress(0.5)

        // Match plugins with installed ones
        let matchStart = Date()
        let entries = PluginMatcher.createEntries(
            from: parsedProject.allPlugins, installedPlugins: installedPlugins
        )
        print("⏱️ Match \(parsedProject.allPlugins.count) plugins: \(Date().timeIntervalSince(matchStart))s")

        await updateProgress(0.8)

        // Create playlist
        let playlist = DAWPlaylist(
            name: parsedProject.name, sourceFile: url, dawType: dawType, dateImported: Date(), entries: entries, tempo: parsedProject.tempo, sampleRate: parsedProject.sampleRate, version: parsedProject.version, key: parsedProject.key
        )

        // Note: We DO NOT append to playlists here during import!
        // This prevents triggering @Published updates on every import.
        // The caller is responsible for batching updates.
        // For individual imports, use addPlaylist() instead.
        print("⏱️ Playlist created (not saved yet - batching for performance)")

        await updateProgress(1.0)

        print("⏱️ TOTAL IMPORT TIME: \(Date().timeIntervalSince(startTime))s")

        return playlist
    }

    // MARK: - Custom Playlists

    /// Create a new custom playlist
    func createCustomPlaylist(name: String) -> DAWPlaylist {
        let playlist = DAWPlaylist(name: name, entries: [])

        #if os(macOS)
        // Register undo
        undoManager.registerUndo(withTarget: self) { manager in
            manager.deletePlaylist(playlist)
        }
        undoManager.setActionName("Create Playlist")
        updateUndoState()
        #endif

        playlists.append(playlist)
        savePlaylists()

        return playlist
    }

    /// Add a custom playlist with pre-populated entries (for JSON import)
    func addCustomPlaylist(_ playlist: DAWPlaylist) {
        guard playlist.playlistType == .custom else {
            print("⚠️ Can only add custom playlists with this method")
            return
        }

        #if os(macOS)
        // Register undo
        undoManager.registerUndo(withTarget: self) { manager in
            manager.deletePlaylist(playlist)
        }
        undoManager.setActionName("Import Playlist")
        updateUndoState()
        #endif

        playlists.append(playlist)
        savePlaylists()
    }

    /// Batch add multiple playlists at once (for bulk DAW imports)
    /// This triggers only ONE @Published update instead of N updates
    func addPlaylists(_ newPlaylists: [DAWPlaylist]) {
        guard !newPlaylists.isEmpty else {
            print("⚠️ addPlaylists called with empty array")
            return
        }

        let batchStart = Date()
        print("🚀 addPlaylists() called with \(newPlaylists.count) playlists")
        for (index, playlist) in newPlaylists.enumerated() {
            print("   [\(index+1)] \(playlist.name) - \(playlist.entries.count) entries")
        }
        print("⏱️ Starting batch add of \(newPlaylists.count) playlists...")

        #if os(macOS)
        // Register undo for batch operation
        undoManager.registerUndo(withTarget: self) { manager in
            for playlist in newPlaylists.reversed() {
                manager.deletePlaylist(playlist)
            }
        }
        undoManager.setActionName("Import \(newPlaylists.count) Projects")
        updateUndoState()
        #endif

        // Single append operation triggers ONE @Published update
        playlists.append(contentsOf: newPlaylists)

        let appendTime = Date().timeIntervalSince(batchStart)
        print("⏱️   - Batch append time: \(appendTime)s")

        // Enrich missing plugins with AI metadata
        let enrichStart = Date()
        for playlist in newPlaylists {
            enrichMissingPluginMetadata(playlist)
        }
        let enrichTime = Date().timeIntervalSince(enrichStart)
        print("⏱️   - AI enrichment time: \(enrichTime)s")

        // Single save operation (enrichment already saves, but ensure consistency)
        let saveStart = Date()
        let saveTime = Date().timeIntervalSince(saveStart)
        print("⏱️   - Batch save time: \(saveTime)s")

        let totalTime = Date().timeIntervalSince(batchStart)
        print("⏱️ TOTAL BATCH ADD TIME: \(totalTime)s for \(newPlaylists.count) playlists")
    }

    /// Add a plugin to a custom playlist
    func addPlugin(_ plugin: PluginItem, to playlist: DAWPlaylist) {
        guard playlist.playlistType == .custom else {
            print("⚠️ Can only add plugins to custom playlists")
            return
        }

        guard var updatedPlaylist = playlists.first(where: { $0.id == playlist.id }) else {
            print("⚠️ Playlist not found")
            return
        }

        // Create a playlist entry from the plugin
        let entry = DAWPlaylistEntry(
            name: plugin.name, publisher: plugin.publisher, trackName: "Custom", trackIndex: 0, deviceIndex: updatedPlaylist.entries.count, type: plugin.type, isInstalled: true, matchedPluginPath: plugin.path, version: plugin.version, style: plugin.style, architectures: plugin.architectures
        )

        // Check if plugin already exists in playlist
        guard !updatedPlaylist.entries.contains(where: { $0.name == plugin.name && $0.type == plugin.type }) else {
            print("ℹ️ Plugin already in playlist")
            return
        }

        updatedPlaylist.entries.append(entry)

        // Update the playlist in the array
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }

    /// Remove a plugin from a custom playlist
    func removePlugin(_ entry: DAWPlaylistEntry, from playlist: DAWPlaylist) {
        guard playlist.playlistType == .custom else {
            print("⚠️ Can only remove plugins from custom playlists")
            return
        }

        guard var updatedPlaylist = playlists.first(where: { $0.id == playlist.id }) else {
            print("⚠️ Playlist not found")
            return
        }

        updatedPlaylist.entries.removeAll { $0.id == entry.id }

        // Update the playlist in the array
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }

    // MARK: - Management

    /// Delete a playlist
    func deletePlaylist(_ playlist: DAWPlaylist) {
        #if os(macOS)
        // Register undo
        undoManager.registerUndo(withTarget: self) { manager in
            manager.restorePlaylist(playlist)
        }
        undoManager.setActionName("Delete Playlist")
        updateUndoState()
        #endif

        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    /// Restore a deleted playlist (for undo)
    func restorePlaylist(_ playlist: DAWPlaylist) {
        #if os(macOS)
        // Register redo
        undoManager.registerUndo(withTarget: self) { manager in
            manager.deletePlaylist(playlist)
        }
        undoManager.setActionName("Delete Playlist")
        updateUndoState()
        #endif

        playlists.append(playlist)
        // Sort by date to maintain order
        playlists.sort { $0.dateImported > $1.dateImported }
        savePlaylists()
    }

    /// Delete multiple playlists
    func deletePlaylists(_ playlistsToDelete: [DAWPlaylist]) {
        #if os(macOS)
        // Register undo for batch deletion
        undoManager.registerUndo(withTarget: self) { manager in
            manager.restorePlaylists(playlistsToDelete)
        }
        undoManager.setActionName(playlistsToDelete.count == 1 ? "Delete Playlist" : "Delete \(playlistsToDelete.count) Playlists")
        updateUndoState()
        #endif

        let idsToDelete = Set(playlistsToDelete.map { $0.id })
        playlists.removeAll { idsToDelete.contains($0.id) }
        savePlaylists()
    }

    /// Restore multiple playlists (for undo)
    private func restorePlaylists(_ playlistsToRestore: [DAWPlaylist]) {
        #if os(macOS)
        // Register redo
        undoManager.registerUndo(withTarget: self) { manager in
            manager.deletePlaylists(playlistsToRestore)
        }
        undoManager.setActionName(playlistsToRestore.count == 1 ? "Delete Playlist" : "Delete \(playlistsToRestore.count) Playlists")
        updateUndoState()
        #endif

        playlists.append(contentsOf: playlistsToRestore)
        // Sort by date to maintain order
        playlists.sort { $0.dateImported > $1.dateImported }
        savePlaylists()
    }

    #if os(macOS)
    /// Update the published undo/redo state
    private func updateUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }

    /// Perform undo and update state
    func performUndo() {
        undoManager.undo()
        updateUndoState()
    }

    /// Perform redo and update state
    func performRedo() {
        undoManager.redo()
        updateUndoState()
    }
    #endif

    /// Rename a playlist
    func renamePlaylist(_ playlist: DAWPlaylist, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }

        // Create updated playlist based on type
        let updated: DAWPlaylist
        if playlist.playlistType == .custom {
            updated = DAWPlaylist(
                id: playlist.id, name: newName, dateImported: playlist.dateImported, entries: playlist.entries
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id, name: newName, sourceFile: playlist.sourceFile!, dawType: playlist.dawType!, dateImported: playlist.dateImported, entries: playlist.entries, tempo: playlist.tempo, sampleRate: playlist.sampleRate, version: playlist.version, key: playlist.key
            )
        }

        playlists[index] = updated
        savePlaylists()
    }

    /// Update a playlist (for metadata editing)
    func updatePlaylist(_ updated: DAWPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == updated.id }) else { return }
        playlists[index] = updated
        savePlaylists()
    }

    /// Re-scan a playlist to update installation status
    func rescanPlaylist(_ playlist: DAWPlaylist, installedPlugins: [PluginItem]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }

        // Re-match all entries
        let updatedEntries = playlist.entries.map { entry -> DAWPlaylistEntry in
            // Convert type string to PluginFormat enum for matching
            let format = PluginFormat(rawValue: entry.type) ?? .VST3
            let match = PluginMatcher.findMatch(
                pluginName: entry.name, manufacturer: entry.publisher, format: format, in: installedPlugins
            )

            // If plugin is now installed, pull metadata from matched plugin
            var updatedEntry = entry
            if let matched = match {
                // Fill in metadata from installed plugin
                if updatedEntry.version.isEmpty {
                    updatedEntry.version = matched.version
                }
                if updatedEntry.style.isEmpty {
                    updatedEntry.style = matched.style
                }
                if updatedEntry.architectures.isEmpty {
                    updatedEntry.architectures = matched.architectures
                }
            }

            return DAWPlaylistEntry(
                id: updatedEntry.id, name: updatedEntry.name, publisher: updatedEntry.publisher, trackName: updatedEntry.trackName, trackIndex: updatedEntry.trackIndex, deviceIndex: updatedEntry.deviceIndex, type: updatedEntry.type, isInstalled: match != nil, matchedPluginPath: match?.path, version: updatedEntry.version, style: updatedEntry.style, architectures: updatedEntry.architectures
            )
        }

        // Create updated playlist based on type
        let updated: DAWPlaylist
        if playlist.playlistType == .custom {
            updated = DAWPlaylist(
                id: playlist.id, name: playlist.name, dateImported: playlist.dateImported, entries: updatedEntries
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id, name: playlist.name, sourceFile: playlist.sourceFile!, dawType: playlist.dawType!, dateImported: playlist.dateImported, entries: updatedEntries, tempo: playlist.tempo, sampleRate: playlist.sampleRate, version: playlist.version, key: playlist.key
            )
        }

        playlists[index] = updated
        savePlaylists()
    }

    // MARK: - AI Metadata Enrichment

    /// Enriches missing plugins with AI-generated metadata
    /// AI fills gaps (Unknown → detected) and validates parser data
    func enrichMissingPluginMetadata(_ playlist: DAWPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            print("⚠️ Playlist not found in manager")
            return
        }

        print("🔍 Starting AI enrichment & validation for playlist: \(playlist.name)")
        print("   Total entries: \(playlist.entries.count)")
        let missingCount = playlist.entries.filter { !$0.isInstalled }.count
        print("   Missing plugins: \(missingCount)")

        var validationWarnings = 0
        var gapsFilled = 0

        // Enrich entries that need metadata (missing or incomplete)
        let enrichedEntries = playlist.entries.enumerated().map { (index, entry) -> DAWPlaylistEntry in
            // Skip if plugin doesn't need any enrichment
            let needsEnrichment = entry.style.isEmpty || entry.version.isEmpty || entry.architectures.isEmpty
            guard needsEnrichment else {
                print("   ⏩ Entry #\(index + 1) SKIPPED (metadata complete): '\(entry.name)'")
                return entry
            }

            print("\n   🤖 [AI ENRICHMENT] Processing entry #\(index + 1):")
            print("      📥 BEFORE enrichment:")
            print("         • name: '\(entry.name)'")
            print("         • publisher: '\(entry.publisher)'")
            print("         • type: '\(entry.type)'")
            print("         • version: '\(entry.version)'")
            print("         • style: '\(entry.style)'")
            print("         • architectures: '\(entry.architectures)'")

            // Get AI metadata for validation/enrichment
            let aiMetadata = getAIPluginMetadata(
                pluginName: entry.name, manufacturer: entry.publisher
            )

            print("      🧠 AI returned:")
            print("         • publisher: '\(aiMetadata.publisher)'")
            print("         • version: '\(aiMetadata.version)'")
            print("         • style: '\(aiMetadata.style)'")
            print("         • architectures: '\(aiMetadata.architectures)'")

            var updatedEntry = entry

            // PUBLISHER: Fill if Unknown/empty, validate if parser found something
            if entry.publisher.isEmpty || entry.publisher == "Unknown" {
                if !aiMetadata.publisher.isEmpty && aiMetadata.publisher != "Unknown" {
                    updatedEntry.publisher = aiMetadata.publisher
                    print("      ✨ AI filled publisher gap: '\(entry.name)' → \(aiMetadata.publisher)")
                    gapsFilled += 1
                } else {
                    print("      ⚠️ AI could not fill publisher gap (AI also returned Unknown)")
                }
            } else {
                // Parser found a publisher - validate it with AI
                if !aiMetadata.publisher.isEmpty && aiMetadata.publisher != "Unknown" &&
                   aiMetadata.publisher != entry.publisher {
                    print("      ⚠️ AI validation mismatch: '\(entry.name)' - Parser: '\(entry.publisher)' vs AI: '\(aiMetadata.publisher)'")
                    validationWarnings += 1
                    // Keep parser's value, but log the mismatch for debugging
                } else {
                    print("      ✅ Parser publisher validated (matches AI or AI couldn't determine)")
                }
            }

            // VERSION: Only fill for installed plugins (we can't guess missing plugin versions)
            if entry.isInstalled && entry.version.isEmpty && !aiMetadata.version.isEmpty {
                updatedEntry.version = aiMetadata.version
                print("      ✨ AI filled version: '\(aiMetadata.version)'")
                gapsFilled += 1
            }

            // STYLE: Fill if empty (useful for both installed and missing)
            if entry.style.isEmpty && !aiMetadata.style.isEmpty {
                updatedEntry.style = aiMetadata.style
                print("      ✨ AI filled style: '\(aiMetadata.style)'")
                gapsFilled += 1
            }

            // ARCHITECTURES: Only fill for installed plugins (missing plugins have no architecture)
            if entry.isInstalled && entry.architectures.isEmpty && !aiMetadata.architectures.isEmpty {
                updatedEntry.architectures = aiMetadata.architectures
                print("      ✨ AI filled architectures: '\(aiMetadata.architectures)'")
                gapsFilled += 1
            }

            print("      📤 AFTER enrichment:")
            print("         • name: '\(updatedEntry.name)'")
            print("         • publisher: '\(updatedEntry.publisher)'")
            print("         • type: '\(updatedEntry.type)'")
            print("         • version: '\(updatedEntry.version)'")
            print("         • style: '\(updatedEntry.style)'")
            print("         • architectures: '\(updatedEntry.architectures)'")

            return updatedEntry
        }

        // Create updated playlist
        let updated: DAWPlaylist
        if playlist.playlistType == .custom {
            updated = DAWPlaylist(
                id: playlist.id, name: playlist.name, dateImported: playlist.dateImported, entries: enrichedEntries
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id, name: playlist.name, sourceFile: playlist.sourceFile!, dawType: playlist.dawType!, dateImported: playlist.dateImported, entries: enrichedEntries, tempo: playlist.tempo, sampleRate: playlist.sampleRate, version: playlist.version, key: playlist.key
            )
        }

        playlists[index] = updated
        savePlaylists()

        // Summary
        print("   📊 AI Enrichment Complete:")
        print("      • Gaps filled: \(gapsFilled) fields")
        print("      • Validation warnings: \(validationWarnings) mismatches")
        if validationWarnings > 0 {
            print("      ⚠️ Review validation warnings above - they may indicate parser bugs")
        }
        if gapsFilled > 0 {
            print("      ✅ AI successfully filled \(gapsFilled) empty fields")
        }
    }

    // MARK: - AI Plugin Metadata Database

    private struct PluginMetadata {
        let publisher: String
        let version: String
        let style: String
        let architectures: String
    }

    private func getAIPluginMetadata(pluginName: String, manufacturer: String) -> PluginMetadata {
        let normalized = pluginName.lowercased().trimmingCharacters(in: .whitespaces)

        print("      🔎 getAIPluginMetadata for '\(pluginName)' (manufacturer: '\(manufacturer)')")

        // 1. Check known plugin database first (exact match)
        if let metadata = knownPluginMetadata[normalized] {
            print("      ✅ Found exact match in database")
            return metadata
        }

        // 2. Try partial matching with database entries
        for (key, metadata) in knownPluginMetadata {
            if normalized.contains(key) || key.contains(normalized) {
                print("      ✅ Found partial match: '\(key)'")
                return metadata
            }
        }

        // 3. Extract manufacturer from plugin name itself
        let detectedPublisher = detectPublisherFromName(pluginName)
        print("      🏢 Detected publisher: \(detectedPublisher ?? "nil")")

        // 4. Check by manufacturer field or detected publisher
        let publisherToUse = detectedPublisher ?? (manufacturer.isEmpty ? nil : manufacturer)

        if let publisher = publisherToUse {
            let publisherLower = publisher.lowercased()
            if let defaultMetadata = manufacturerDefaults[publisherLower] {
                return PluginMetadata(
                    publisher: publisher, version: defaultMetadata.version, style: detectPluginStyle(from: pluginName), architectures: defaultMetadata.architectures
                )
            }
        }

        // 5. Default generic metadata
        let style = detectPluginStyle(from: pluginName)
        let result = PluginMetadata(
            publisher: publisherToUse ?? "Unknown", version: "Latest", style: style, architectures: "Universal"
        )
        print("      📦 Final metadata - Publisher: \(result.publisher), Style: \(result.style)")
        return result
    }

    /// Detects the publisher/manufacturer from the plugin name
    private func detectPublisherFromName(_ pluginName: String) -> String? {
        let lower = pluginName.lowercased()

        // Known manufacturer patterns in plugin names
        if lower.contains("fabfilter") { return "FabFilter" }
        if lower.contains("waves") { return "Waves" }
        if lower.contains("valhalla") { return "Valhalla DSP" }
        if lower.contains("soundtoys") { return "Soundtoys" }
        if lower.contains("izotope") { return "iZotope" }
        if lower.contains("slate") { return "Slate Digital" }
        if lower.contains("native instruments") || lower.contains("kontakt") || lower.contains("massive") || lower.contains("reaktor") { return "Native Instruments" }
        if lower.contains("serum") || lower.contains("lfo tool") { return "Xfer Records" }
        if lower.contains("arturia") { return "Arturia" }
        if lower.contains("omnisphere") || lower.contains("keyscape") || lower.contains("trilian") { return "Spectrasonics" }
        if lower.contains("output") { return "Output" }
        if lower.contains("u-he") || lower.contains("diva") || lower.contains("zebra") || lower.contains("repro") { return "u-he" }
        if lower.contains("plugin alliance") || lower.contains("bx_") || lower.contains("brainworx") { return "Plugin Alliance" }
        if lower.contains("softube") { return "Softube" }
        if lower.contains("celemony") || lower.contains("melodyne") { return "Celemony" }
        if lower.contains("auto-tune") || lower.contains("antares") { return "Antares" }
        if lower.contains("spitfire") { return "Spitfire Audio" }
        if lower.contains("ssl ") || lower.starts(with: "ssl") { return "Solid State Logic" }
        if lower.contains("uad ") || lower.contains("universal audio") { return "Universal Audio" }
        if lower.contains("avid") || lower.contains("pro tools") { return "Avid" }
        if lower.contains("lexicon") { return "Lexicon" }
        if lower.contains("eventide") { return "Eventide" }
        if lower.contains("dmg") { return "DMG Audio" }
        if lower.contains("cytomic") { return "Cytomic" }
        if lower.contains("goodhertz") { return "Goodhertz" }
        if lower.contains("kilohearts") { return "Kilohearts" }
        if lower.contains("sugar bytes") { return "Sugar Bytes" }
        if lower.contains("vengeance") { return "Vengeance Sound" }
        if lower.contains("sylenth") { return "LennarDigital" }
        if lower.contains("reveal sound") { return "Reveal Sound" }
        if lower.contains("xln audio") || lower.contains("addictive") { return "XLN Audio" }
        if lower.contains("toontrack") { return "Toontrack" }
        if lower.contains("heavyocity") { return "Heavyocity" }
        if lower.contains("eastwest") || lower.contains("east west") { return "EastWest" }
        if lower.contains("komplete") { return "Native Instruments" }
        if lower.contains("abbey road") { return "Waves" }
        if lower.contains("cla-") { return "Waves" }
        if lower.contains("api ") { return "Waves" }  // API plugins usually from Waves or UAD
        if lower.contains("neve ") { return "Waves" }  // Neve plugins from multiple vendors
        if lower.contains("pultec") { return "Waves" }  // Pultec emulations
        if lower.contains("1176") || lower.contains("la-2a") || lower.contains("la-3a") { return "Universal Audio" }
        if lower.contains("fairchild") { return "Universal Audio" }
        if lower.contains("emt ") { return "Universal Audio" }

        return nil
    }

    private func detectPluginStyle(from pluginName: String) -> String {
        let lower = pluginName.lowercased()

        // Channel Strip (check first - more specific)
        if lower.contains("channel strip") || lower.contains("channel-strip") {
            return "Channel Strip"
        }

        // EQ / Filter
        if lower.contains(" eq ") || lower.contains("-eq-") || lower.contains(" eq-") ||
           lower.contains("-eq ") || lower.starts(with: "eq ") || lower.hasSuffix(" eq") ||
           lower.contains("equalizer") || lower.contains("filter") || lower.contains("pro-q") {
            return "EQ / Filter"
        }

        // Compressor (before general dynamics)
        if lower.contains("compressor") || lower.contains("comp ") ||
           lower.contains("-comp") || lower.contains("pro-c") {
            return "Compressor"
        }

        // Limiter
        if lower.contains("limiter") || lower.contains("pro-l") {
            return "Limiter"
        }

        // Gate / Expander
        if lower.contains("gate") || lower.contains("expander") {
            return "Gate / Expander"
        }

        // De-esser
        if lower.contains("de-esser") || lower.contains("deesser") ||
           lower.contains("de esser") || lower.contains("pro-ds") {
            return "De-esser"
        }

        // Multiband
        if lower.contains("multiband") || lower.contains("multi-band") ||
           lower.contains("pro-mb") {
            return "Multiband Dynamics"
        }

        // General Dynamics (after specific types)
        if lower.contains("dynamics") || lower.contains("compander") {
            return "Dynamics"
        }

        // Reverb
        if lower.contains("reverb") || lower.contains("verb") || lower.contains("room") ||
           lower.contains("hall") || lower.contains("plate") || lower.contains("spring") ||
           lower.contains("chamber") || lower.contains("pro-r") {
            return "Reverb"
        }

        // Delay / Echo
        if lower.contains("delay") || lower.contains("echo") {
            return "Delay / Echo"
        }

        // Chorus
        if lower.contains("chorus") {
            return "Chorus"
        }

        // Flanger
        if lower.contains("flanger") {
            return "Flanger"
        }

        // Phaser
        if lower.contains("phaser") {
            return "Phaser"
        }

        // Modulation (general)
        if lower.contains("modulation") || lower.contains("modulator") ||
           lower.contains("tremolo") || lower.contains("vibrato") {
            return "Modulation"
        }

        // Distortion / Saturation
        if lower.contains("distortion") || lower.contains("overdrive") ||
           lower.contains("fuzz") || lower.contains("saturator") ||
           lower.contains("saturation") || lower.contains("tube") ||
           lower.contains("valve") || lower.contains("tape") || lower.contains("pro-d") {
            return "Distortion / Saturation"
        }

        // Transient / Envelope
        if lower.contains("transient") || lower.contains("shaper") ||
           lower.contains("envelope") {
            return "Transient Shaper"
        }

        // Pitch / Harmony
        if lower.contains("pitch") || lower.contains("harmonizer") ||
           lower.contains("autotune") || lower.contains("auto-tune") ||
           lower.contains("melodyne") {
            return "Pitch Correction"
        }

        // Spatial / Stereo
        if lower.contains("spatial") || lower.contains("stereo") ||
           lower.contains("width") || lower.contains("imager") ||
           lower.contains("panorama") || lower.contains("pan ") {
            return "Spatial / Stereo"
        }

        // Metering / Analysis
        if lower.contains("analyzer") || lower.contains("meter") ||
           lower.contains("spectrum") || lower.contains("scope") ||
           lower.contains("loudness") || lower.contains("pro-a") {
            return "Metering / Analysis"
        }

        // Synthesizer
        if lower.contains("synth") || lower.contains("synthesizer") ||
           lower.contains("oscillator") {
            return "Synthesizer"
        }

        // Sampler / Drums
        if lower.contains("sampler") || lower.contains("drum") ||
           lower.contains("kontakt") || lower.contains("battery") {
            return "Sampler / Drums"
        }

        // Enhancer / Exciter
        if lower.contains("enhancer") || lower.contains("exciter") ||
           lower.contains("aural") {
            return "Enhancer / Exciter"
        }

        // Vocoder
        if lower.contains("vocoder") {
            return "Vocoder"
        }

        // Utility
        if lower.contains("utility") || lower.contains("gain") ||
           lower.contains("trim") {
            return "Utility"
        }

        return "Effect / Processor"
    }

    private let knownPluginMetadata: [String: PluginMetadata] = [
        // FabFilter
        "fabfilter pro-q 3": PluginMetadata(publisher: "FabFilter", version: "3.x", style: "EQ / Filter", architectures: "Universal"), "fabfilter pro-q 2": PluginMetadata(publisher: "FabFilter", version: "2.x", style: "EQ / Filter", architectures: "Universal"), "fabfilter pro-c 2": PluginMetadata(publisher: "FabFilter", version: "2.x", style: "Dynamics", architectures: "Universal"), "fabfilter pro-l 2": PluginMetadata(publisher: "FabFilter", version: "2.x", style: "Dynamics", architectures: "Universal"), "fabfilter pro-mb": PluginMetadata(publisher: "FabFilter", version: "1.x", style: "Dynamics", architectures: "Universal"), "fabfilter pro-r": PluginMetadata(publisher: "FabFilter", version: "2.x", style: "Time-Based", architectures: "Universal"), "fabfilter saturn 2": PluginMetadata(publisher: "FabFilter", version: "2.x", style: "Distortion / Saturation", architectures: "Universal"), "waves cla-76": PluginMetadata(publisher: "Waves", version: "Latest", style: "Dynamics", architectures: "Universal"), "waves cla-2a": PluginMetadata(publisher: "Waves", version: "Latest", style: "Dynamics", architectures: "Universal"), "waves ssl e-channel": PluginMetadata(publisher: "Waves", version: "Latest", style: "Channel Strip", architectures: "Universal"), "waves h-reverb": PluginMetadata(publisher: "Waves", version: "Latest", style: "Time-Based", architectures: "Universal"), "waves q10": PluginMetadata(publisher: "Waves", version: "Latest", style: "EQ / Filter", architectures: "Universal"), "valhalla vintageverb": PluginMetadata(publisher: "Valhalla DSP", version: "Latest", style: "Time-Based", architectures: "Universal"), "valhalla room": PluginMetadata(publisher: "Valhalla DSP", version: "Latest", style: "Time-Based", architectures: "Universal"), "valhalla delay": PluginMetadata(publisher: "Valhalla DSP", version: "Latest", style: "Time-Based", architectures: "Universal"), "soundtoys echoboy": PluginMetadata(publisher: "Soundtoys", version: "Latest", style: "Time-Based", architectures: "Universal"), "soundtoys decapitator": PluginMetadata(publisher: "Soundtoys", version: "Latest", style: "Distortion / Saturation", architectures: "Universal"), "izotope ozone": PluginMetadata(publisher: "iZotope", version: "11.x", style: "Mastering", architectures: "Universal"), "izotope neutron": PluginMetadata(publisher: "iZotope", version: "5.x", style: "Mixing", architectures: "Universal"), "izotope rx": PluginMetadata(publisher: "iZotope", version: "11.x", style: "Audio Repair", architectures: "Universal"), "kontakt": PluginMetadata(publisher: "Native Instruments", version: "7.x", style: "Sampler / Drum", architectures: "Universal"), "massive x": PluginMetadata(publisher: "Native Instruments", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "serum": PluginMetadata(publisher: "Xfer Records", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "omnisphere": PluginMetadata(publisher: "Spectrasonics", version: "2.x", style: "Synthesizer / Instrument", architectures: "Universal"), "melodyne": PluginMetadata(publisher: "Celemony", version: "5.x", style: "Pitch / Time", architectures: "Universal"), "auto-tune pro": PluginMetadata(publisher: "Antares", version: "Latest", style: "Pitch / Time", architectures: "Universal")
    ]

    private let manufacturerDefaults: [String: PluginMetadata] = [
        "fabfilter": PluginMetadata(publisher: "FabFilter", version: "Latest", style: "Effect / Processor", architectures: "Universal"), "waves": PluginMetadata(publisher: "Waves", version: "Latest", style: "Effect / Processor", architectures: "Universal"), "valhalla": PluginMetadata(publisher: "Valhalla DSP", version: "Latest", style: "Time-Based", architectures: "Universal"), "soundtoys": PluginMetadata(publisher: "Soundtoys", version: "Latest", style: "Effect / Processor", architectures: "Universal"), "izotope": PluginMetadata(publisher: "iZotope", version: "Latest", style: "Effect / Processor", architectures: "Universal"), "native instruments": PluginMetadata(publisher: "Native Instruments", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "xfer": PluginMetadata(publisher: "Xfer Records", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "spectrasonics": PluginMetadata(publisher: "Spectrasonics", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "arturia": PluginMetadata(publisher: "Arturia", version: "Latest", style: "Synthesizer / Instrument", architectures: "Universal"), "slate digital": PluginMetadata(publisher: "Slate Digital", version: "Latest", style: "Effect / Processor", architectures: "Universal")
    ]

    // MARK: - Persistence

    private func savePlaylists() {
        let encodeStart = Date()
        guard let encoded = try? JSONEncoder().encode(playlists) else {
            print("❌ Failed to encode DAW playlists")
            return
        }
        let encodeTime = Date().timeIntervalSince(encodeStart)
        print("⏱️   - JSON encode time: \(encodeTime)s (\(encoded.count) bytes)")

        let saveStart = Date()
        CloudSyncStorage.shared.setData(encoded, forKey: storageKey)
        let saveTime = Date().timeIntervalSince(saveStart)
        print("⏱️   - Storage write time: \(saveTime)s")
    }

    private func loadPlaylists() {
        guard let data = CloudSyncStorage.shared.getData(forKey: storageKey), let decoded = try? JSONDecoder().decode([DAWPlaylist].self, from: data) else {
            return
        }

        playlists = decoded
    }

    // MARK: - Helpers

    private func detectDAWType(from url: URL) -> DAWType {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "als": 
            return .abletonLive
        case "logic", "logicx": 
            return .logicPro
        case "band": 
            return .garageBand
        case "concert": 
            return .mainStage
        case "cpr": 
            return .cubase
        case "npr": 
            return .nuendo
        case "song": 
            return .studioOne
        case "rpp", "rpp-bak": 
            return .reaper
        case "reason", "rns": 
            return .reason
        case "ptx", "txt": 
            // Pro Tools supports both .ptx (binary) and .txt (Session Info export)
            return .proTools
        case "bwproject": 
            return .bitwig
        case "flp": 
            return .flStudio
        case "xrns": 
            return .renoise
        case "motu": 
            return .digitalPerformer
        case "ardour": 
            return .ardour
        case "mixbus": 
            return .mixbus
        case "tracktionedit": 
            return .tracktion
        default: 
            return .abletonLive // Default
        }
    }

    @MainActor
    private func updateProgress(_ progress: Double) async {
        importProgress = progress
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unsupportedDAWType(DAWType)
        case parsingFailed(Error)
        case noPluginsFound

        var errorDescription: String? {
            switch self {
            case .unsupportedDAWType(let type): 
                return "\(type.rawValue) projects are not yet supported. Currently only Ableton Live (.als) is supported."
            case .parsingFailed(let error): 
                return "Failed to parse project file: \(error.localizedDescription)"
            case .noPluginsFound: 
                return "No plugins found in the project file."
            }
        }
    }
}

// MARK: - Statistics

extension DAWPlaylistManager {

    /// Get total number of unique plugins across all playlists
    var totalUniquePlugins: Int {
        let allPluginNames = playlists.flatMap { $0.uniquePlugins }
        return Set(allPluginNames).count
    }

    /// Get total number of playlists
    var totalPlaylists: Int {
        playlists.count
    }

    /// Get playlists sorted by date (newest first)
    var playlistsByDate: [DAWPlaylist] {
        playlists.sorted { $0.dateImported > $1.dateImported }
    }

    /// Get playlists sorted by name
    var playlistsByName: [DAWPlaylist] {
        playlists.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Find playlists containing a specific plugin
    func playlists(containing pluginName: String) -> [DAWPlaylist] {
        playlists.filter { playlist in
            playlist.entries.contains { entry in
                entry.name.lowercased() == pluginName.lowercased()
            }
        }
    }
}

// MARK: - Plugin Matcher

/// Matches parsed plugins from DAW projects with installed plugins  
class PluginMatcher {

    static func findMatch(
        pluginName: String, manufacturer: String, format: PluginFormat, in installedPlugins: [PluginItem]
    ) -> PluginItem? {

        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased() &&
            $0.type.lowercased() == format.rawValue.lowercased()
        }) {
            return match
        }

        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased()
        }) {
            return match
        }

        if !manufacturer.isEmpty && manufacturer.lowercased() != "unknown" {
            if let match = installedPlugins.first(where: {
                $0.name.lowercased() == pluginName.lowercased() &&
                $0.publisher.lowercased().contains(manufacturer.lowercased())
            }) {
                return match
            }
        }

        let cleanedName = cleanPluginName(pluginName)
        if let match = installedPlugins.first(where: {
            cleanPluginName($0.name).lowercased() == cleanedName.lowercased()
        }) {
            return match
        }

        if pluginName.count > 4 {
            if let match = installedPlugins.first(where: {
                $0.name.lowercased().contains(pluginName.lowercased()) ||
                pluginName.lowercased().contains($0.name.lowercased())
            }) {
                return match
            }
        }

        return nil
    }

    static func createEntries(
        from parsedPlugins: [ParsedPlugin], installedPlugins: [PluginItem]
    ) -> [DAWPlaylistEntry] {

        return parsedPlugins.map { parsed in
            // Convert type string to PluginFormat enum for matching
            let format = PluginFormat(rawValue: parsed.type) ?? .VST3
            let match = findMatch(
                pluginName: parsed.name, manufacturer: parsed.publisher, format: format, in: installedPlugins
            )

            // If plugin is installed, pull metadata from matched plugin
            // Otherwise, use metadata from DAW project file (if available)
            let version = match?.version ?? parsed.version
            let style = match?.style ?? ""
            let architectures = match?.architectures ?? ""
            let preset = parsed.preset  // Always use preset from DAW project

            return DAWPlaylistEntry(
                name: parsed.name, publisher: parsed.publisher, trackName: parsed.trackName, trackIndex: parsed.trackIndex, deviceIndex: parsed.deviceIndex, type: parsed.type, isInstalled: match != nil, matchedPluginPath: match?.path, version: version, style: style, architectures: architectures, preset: preset
            )
        }
    }

    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name

        let suffixes = [" VST", " VST3", " AU", " AAX", " x64", " x86", " (VST)", " (VST3)", " (AU)", " (AAX)", " v2", " v3", " v4", " v5", " 2", " 3", " 4", " 5"]

        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }

        let prefixes = ["VST:", "VST3:", "AU:", "AAX:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        return cleaned
    }

    struct MatchStats {
        let totalPlugins: Int
        let matchedPlugins: Int
        let missingPlugins: Int
        let matchRate: Double

        var matchPercentage: Int {
            Int(matchRate * 100)
        }
    }

    static func calculateStats(for entries: [DAWPlaylistEntry]) -> MatchStats {
        let total = entries.count
        let matched = entries.filter { $0.isInstalled }.count
        let missing = total - matched
        let rate = total > 0 ? Double(matched) / Double(total) : 0.0

        return MatchStats(
            totalPlugins: total, matchedPlugins: matched, missingPlugins: missing, matchRate: rate
        )
    }
}