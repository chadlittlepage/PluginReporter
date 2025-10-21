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
    case fairlight = "Fairlight (DaVinci Resolve)"

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
        case .fairlight: return "drp"
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
            from: parsedProject.allPlugins,
            installedPlugins: installedPlugins
        )
        print("⏱️ Match \(parsedProject.allPlugins.count) plugins: \(Date().timeIntervalSince(matchStart))s")

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
        guard !newPlaylists.isEmpty else { return }

        let batchStart = Date()
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

        // Single save operation
        let saveStart = Date()
        savePlaylists()
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

        // Convert plugin type string to PluginFormat enum
        let pluginFormat = PluginFormat(rawValue: plugin.type) ?? .unknown

        // Create a playlist entry from the plugin
        let entry = DAWPlaylistEntry(
            pluginName: plugin.name,
            pluginManufacturer: plugin.publisher,
            trackName: "Custom",  // Custom playlists don't have tracks
            trackIndex: 0,
            deviceIndex: updatedPlaylist.entries.count,
            pluginFormat: pluginFormat,
            isInstalled: true,
            matchedPluginPath: plugin.path
        )

        // Check if plugin already exists in playlist
        guard !updatedPlaylist.entries.contains(where: { $0.pluginName == plugin.name && $0.pluginFormat == pluginFormat }) else {
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
                id: playlist.id,
                name: newName,
                dateImported: playlist.dateImported,
                entries: playlist.entries
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id,
                name: newName,
                sourceFile: playlist.sourceFile!,
                dawType: playlist.dawType!,
                dateImported: playlist.dateImported,
                entries: playlist.entries,
                tempo: playlist.tempo,
                sampleRate: playlist.sampleRate,
                version: playlist.version,
                key: playlist.key
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

        // Create updated playlist based on type
        let updated: DAWPlaylist
        if playlist.playlistType == .custom {
            updated = DAWPlaylist(
                id: playlist.id,
                name: playlist.name,
                dateImported: playlist.dateImported,
                entries: updatedEntries
            )
        } else {
            updated = DAWPlaylist(
                id: playlist.id,
                name: playlist.name,
                sourceFile: playlist.sourceFile!,
                dawType: playlist.dawType!,
                dateImported: playlist.dateImported,
                entries: updatedEntries,
                tempo: playlist.tempo,
                sampleRate: playlist.sampleRate,
                version: playlist.version,
                key: playlist.key
            )
        }

        playlists[index] = updated
        savePlaylists()
    }

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
        case "drp":
            return .fairlight
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
