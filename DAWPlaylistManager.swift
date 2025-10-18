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

/// A playlist created from a DAW project file (Ableton Live, Logic Pro, etc.)
struct DAWPlaylist: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let sourceFile: URL
    let dawType: DAWType
    let dateImported: Date
    let entries: [DAWPlaylistEntry]
    let tempo: Double?
    let sampleRate: Int?
    let version: String?
    let key: String?

    init(id: UUID = UUID(), name: String, sourceFile: URL, dawType: DAWType, dateImported: Date = Date(), entries: [DAWPlaylistEntry], tempo: Double? = nil, sampleRate: Int? = nil, version: String? = nil, key: String? = nil) {
        self.id = id
        self.name = name
        self.sourceFile = sourceFile
        self.dawType = dawType
        self.dateImported = dateImported
        self.entries = entries
        self.tempo = tempo
        self.sampleRate = sampleRate
        self.version = version
        self.key = key
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
        Array(Set(entries.map { $0.pluginName })).sorted()
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
struct DAWPlaylistEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let pluginName: String
    let pluginManufacturer: String
    let trackName: String
    let trackIndex: Int
    let deviceIndex: Int
    let pluginFormat: PluginFormat
    let isInstalled: Bool
    let matchedPluginPath: String?  // Path to matched plugin if found

    init(id: UUID = UUID(),
         pluginName: String,
         pluginManufacturer: String,
         trackName: String,
         trackIndex: Int,
         deviceIndex: Int,
         pluginFormat: PluginFormat,
         isInstalled: Bool,
         matchedPluginPath: String? = nil) {
        self.id = id
        self.pluginName = pluginName
        self.pluginManufacturer = pluginManufacturer
        self.trackName = trackName
        self.trackIndex = trackIndex
        self.deviceIndex = deviceIndex
        self.pluginFormat = pluginFormat
        self.isInstalled = isInstalled
        self.matchedPluginPath = matchedPluginPath
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
enum DAWType: String, Codable, Hashable {
    case abletonLive = "Ableton Live"
    case logicPro = "Logic Pro"
    case cubase = "Cubase"
    case studioOne = "Studio One"
    case proTools = "Pro Tools"
    case bitwig = "Bitwig"

    var fileExtension: String {
        switch self {
        case .abletonLive: return "als"
        case .logicPro: return "logic"
        case .cubase: return "cpr"
        case .studioOne: return "song"
        case .proTools: return "ptx"
        case .bitwig: return "bwproject"
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

        // Determine DAW type from file extension
        let dawType = detectDAWType(from: url)

        await updateProgress(0.2)

        // Parse the project file using the parser registry
        let parsedProject: ParsedProject
        parsedProject = try DAWParserRegistry.shared.parseProject(url: url, dawType: dawType)

        await updateProgress(0.5)

        // Match plugins with installed ones
        let entries = PluginMatcher.createEntries(
            from: parsedProject.allPlugins,
            installedPlugins: installedPlugins
        )

        await updateProgress(0.8)

        // Create playlist
        let playlist = DAWPlaylist(
            name: parsedProject.name,
            sourceFile: url,
            dawType: dawType,
            dateImported: Date(),
            entries: entries,
            tempo: parsedProject.tempo,
            sampleRate: parsedProject.sampleRate,
            version: parsedProject.version,
            key: parsedProject.key
        )

        // Save playlist
        await MainActor.run {
            playlists.append(playlist)
            savePlaylists()
        }

        await updateProgress(1.0)

        return playlist
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

        let updated = DAWPlaylist(
            id: playlist.id,
            name: newName,
            sourceFile: playlist.sourceFile,
            dawType: playlist.dawType,
            dateImported: playlist.dateImported,
            entries: playlist.entries,
            tempo: playlist.tempo,
            sampleRate: playlist.sampleRate,
            version: playlist.version,
            key: playlist.key
        )

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
            let match = PluginMatcher.findMatch(
                pluginName: entry.pluginName,
                manufacturer: entry.pluginManufacturer,
                format: entry.pluginFormat,
                in: installedPlugins
            )

            return DAWPlaylistEntry(
                id: entry.id,
                pluginName: entry.pluginName,
                pluginManufacturer: entry.pluginManufacturer,
                trackName: entry.trackName,
                trackIndex: entry.trackIndex,
                deviceIndex: entry.deviceIndex,
                pluginFormat: entry.pluginFormat,
                isInstalled: match != nil,
                matchedPluginPath: match?.path
            )
        }

        let updated = DAWPlaylist(
            id: playlist.id,
            name: playlist.name,
            sourceFile: playlist.sourceFile,
            dawType: playlist.dawType,
            dateImported: playlist.dateImported,
            entries: updatedEntries,
            tempo: playlist.tempo,
            sampleRate: playlist.sampleRate,
            version: playlist.version,
            key: playlist.key
        )

        playlists[index] = updated
        savePlaylists()
    }

    // MARK: - Persistence

    private func savePlaylists() {
        guard let encoded = try? JSONEncoder().encode(playlists) else {
            print("❌ Failed to encode DAW playlists")
            return
        }

        CloudSyncStorage.shared.setData(encoded, forKey: storageKey)
    }

    private func loadPlaylists() {
        guard let data = CloudSyncStorage.shared.getData(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DAWPlaylist].self, from: data) else {
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
        case "logic":
            return .logicPro
        case "cpr":
            return .cubase
        case "song":
            return .studioOne
        case "ptx", "txt":
            // Pro Tools supports both .ptx (binary) and .txt (Session Info export)
            return .proTools
        case "bwproject":
            return .bitwig
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
                entry.pluginName.lowercased() == pluginName.lowercased()
            }
        }
    }
}

// MARK: - Plugin Matcher

/// Matches parsed plugins from DAW projects with installed plugins  
class PluginMatcher {

    static func findMatch(
        pluginName: String,
        manufacturer: String,
        format: PluginFormat,
        in installedPlugins: [PluginItem]
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
        from parsedPlugins: [ParsedPlugin],
        installedPlugins: [PluginItem]
    ) -> [DAWPlaylistEntry] {

        return parsedPlugins.map { parsed in
            let match = findMatch(
                pluginName: parsed.name,
                manufacturer: parsed.manufacturer,
                format: parsed.format,
                in: installedPlugins
            )

            return DAWPlaylistEntry(
                pluginName: parsed.name,
                pluginManufacturer: parsed.manufacturer,
                trackName: parsed.trackName,
                trackIndex: parsed.trackIndex,
                deviceIndex: parsed.deviceIndex,
                pluginFormat: parsed.format,
                isInstalled: match != nil,
                matchedPluginPath: match?.path
            )
        }
    }

    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name

        let suffixes = [" VST", " VST3", " AU", " AAX", " x64", " x86",
                       " (VST)", " (VST3)", " (AU)", " (AAX)",
                       " v2", " v3", " v4", " v5",
                       " 2", " 3", " 4", " 5"]

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
            totalPlugins: total,
            matchedPlugins: matched,
            missingPlugins: missing,
            matchRate: rate
        )
    }
}
