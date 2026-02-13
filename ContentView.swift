import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Disambiguate project types in case of name collisions
typealias AppPluginItem = PluginItem
typealias AppPreferences = Preferences

/// Struct for decoding imported JSON plugin data
struct ImportedJSONPlugin: Codable {
    let id: UUID
    let rating: Int
    let name: String
    let publisher: String
    let type: String
    let style: String
    let version: String
    let architectures: String
    let date: String
    let size: String
    let requirement: String
    let obsolete: Bool
    let missing: Bool
    let track: String?
    let notes: String
    let path: String
}

struct ContentView: View {
    @EnvironmentObject private var scanner: PluginScanner
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var zoomState: ZoomState
    @StateObject private var appState = AppState()
    @State private var searchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var isExporting = false
    @State private var selectedRow: AppPluginItem.ID? = nil
    @FocusState private var searchFocused: Bool
    @State private var showFormatsPopover: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didCollapseSidebar: Bool = false
    @State private var showOverlaySidebar: Bool = false
    @State private var sortStatus: String = "Sorted by: Name (ascending)"
    @State private var suppressAnimations: Bool = false
    @State private var showDetailSheet: Bool = false

    // Force immediate bar graph display
    @State private var forceBarGraphDisplay: Bool = true

    // INSTANT bar graph - cached counts (only updates on batch completion)
    @State private var cachedBarCounts = FormatCounts()
    @State private var totalPluginCounts = FormatCounts()  // Unfiltered counts for playlist mode
    @State private var lastBarUpdateCount = 0

    // REACTIVE: Filtered plugins that updates automatically
    @State private var displayedPlugins: [AppPluginItem] = []

    // MARK: Batch uninstall state
    @State private var showBatchUninstall = false
    @State private var batchUninstallPlugins: [AppPluginItem] = []

    // MARK: Detail panel state
    @State private var showDetailPanel = false
    @State private var detailPanelRefreshTrigger = false  // Toggle to force refresh
    @State private var detailPanelTab: DetailTab = .metadata  // Current tab in detail panel

    // MARK: DAW Playlist state
    #if os(macOS)
    @State private var showPlaylistSidebar: Bool = false
    @State private var activePlaylistFilters: [DAWPlaylist] = []
    @StateObject private var playlistManager = DAWPlaylistManager.shared
    @State private var showDAWImport = false
    @State private var showCreateCustomPlaylist = false
    @State private var showDuplicatePlaylistWarning = false
    @State private var pendingImportURL: URL?
    @State private var existingPlaylistToReplace: DAWPlaylist?
    @State private var showJSONImportDialog = false
    @State private var pendingJSONImportURL: URL?

    // Pre-created panel for INSTANT access
    private let dawPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        // ALL 18 DAW formats supported!
        panel.allowedFileTypes = [
            "als",          // Ableton Live
            "song",         // Studio One
            "rpp",          // Reaper
            "bwproject",    // Bitwig
            "txt", "ptx",   // Pro Tools
            "cpr", "npr",   // Cubase/Nuendo
            "reason", "rns",// Reason
            "motu",         // Digital Performer
            "xrns",         // Renoise
            "flp",          // FL Studio
            "tracktionedit",// Tracktion
            "ardour",       // Ardour
            "mixbus",       // Mixbus
            "drp",          // Fairlight
            "band",         // GarageBand
            "logicx",       // Logic Pro
            "concert"       // MainStage
        ]
        return panel
    }()
    #endif

    private func toggleDetailPanel() {
        showDetailPanel.toggle()

        // If opening panel and no selection, select first plugin
        if showDetailPanel && appState.selected.isEmpty && !displayedPlugins.isEmpty {
            appState.selected = [displayedPlugins[0]]
        }
    }

    private func updateDisplayedPlugins() {
        let allPlugins = scanner.plugins.map(AppPluginItem.init)

        // Check if playlist is active - if so, skip ALL filters initially and apply them after playlist filtering
        #if os(macOS)
        let hasActivePlaylist = !activePlaylistFilters.isEmpty
        #else
        let hasActivePlaylist = false
        #endif

        var filtered: [AppPluginItem]

        if hasActivePlaylist {
            // When playlist is active, don't filter yet - we'll filter the playlist results
            filtered = allPlugins
        } else {
            // Normal filtering when no playlist is active
            filtered = FastFilterEngine.filter(
                plugins: allPlugins,
                formats: prefs.selectedFormats,
                publishers: prefs.selectedPublishers,
                styles: prefs.selectedStyles,
                searchText: searchText
            )

            // Apply star rating filter if any selected
            if !prefs.selectedStarRatings.isEmpty {
                let ratingsManager = RatingsManager.shared
                filtered = filtered.filter { plugin in
                    let rating = ratingsManager.getRating(forName: plugin.name)
                    return prefs.selectedStarRatings.contains(rating)
                }
            }
        }

        // Apply playlist filter if active
        #if os(macOS)
        if !activePlaylistFilters.isEmpty {
            // Optimized single-pass playlist filtering using FilterUtils
            // Build track map and collect all entries in one pass
            var allPlaylistEntries: [DAWPlaylistEntry] = []
            for activePlaylist in activePlaylistFilters {
                allPlaylistEntries.append(contentsOf: activePlaylist.entries)
            }

            let playlistTrackMap = FilterUtils.buildPluginTrackMap(from: allPlaylistEntries)

            // Single-pass: find installed plugins and build missing set simultaneously
            var installedPlugins: [AppPluginItem] = []
            var installedKeys = Set<String>()

            for plugin in filtered {
                let key = FilterUtils.makePluginKey(name: plugin.name, type: plugin.type)
                if let trackNames = playlistTrackMap[key] {
                    var updatedPlugin = plugin
                    updatedPlugin.trackName = trackNames.joined(separator: ", ")
                    updatedPlugin.missing = false
                    installedPlugins.append(updatedPlugin)
                    installedKeys.insert(key)
                }
            }

            // Single-pass: create missing plugins with deduplication
            let uniqueMissing = FilterUtils.deduplicatePlugins(
                allPlaylistEntries.compactMap { entry -> AppPluginItem? in
                    let key = FilterUtils.makePluginKey(name: entry.pluginName, format: entry.pluginFormat)
                    guard !installedKeys.contains(key) else { return nil }

                    let trackNames = playlistTrackMap[key]?.joined(separator: ", ") ?? ""
                    return AppPluginItem(
                        name: entry.pluginName,
                        publisher: "",
                        version: "",
                        type: entry.pluginFormat.rawValue,
                        style: "",
                        architectures: "",
                        date: nil,
                        sizeBytes: 0,
                        path: "",
                        runtimeRequirement: "",
                        obsolete: false,
                        trackName: trackNames,
                        missing: true
                    )
                },
                keyExtractor: { FilterUtils.makePluginKey(name: $0.name, type: $0.type) }
            )

            // Combine installed and missing plugins
            filtered = installedPlugins + uniqueMissing

            // NOW apply ALL filters to the playlist results (format, publisher, style, search, ratings)
            filtered = FastFilterEngine.filter(
                plugins: filtered,
                formats: prefs.selectedFormats,
                publishers: prefs.selectedPublishers,
                styles: prefs.selectedStyles,
                searchText: searchText
            )

            // Apply star rating filter if any selected
            if !prefs.selectedStarRatings.isEmpty {
                let ratingsManager = RatingsManager.shared
                filtered = filtered.filter { plugin in
                    let rating = ratingsManager.getRating(forName: plugin.name)
                    return prefs.selectedStarRatings.contains(rating)
                }
            }
        }
        #endif

        displayedPlugins = filtered

        // Restore selection from IDs after filtering
        appState.restoreSelection(from: displayedPlugins)
    }

    private func handleSearchTextChange(_ newValue: String) {
        // Debounce search to improve typing performance
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }
            updateDisplayedPlugins()
        }
    }

    private var appBG: Color {
        // Space mode: pure black background
        if prefs.appearance.usesTrueBlack {
            return Color.black
        }
        // Regular dark mode: dark gray (matching iOS/iPadOS)
        else if colorScheme == .dark {
            return Color(red: 28/255, green: 28/255, blue: 30/255)
        }
        // Light mode: white to match listing background
        else {
            return Color.white
        }
    }

    // Toggle format filter when bar is clicked
    private func toggleFormat(_ format: PluginFormat) {
        if prefs.selectedFormats.contains(format) {
            prefs.selectedFormats.remove(format)
        } else {
            prefs.selectedFormats.insert(format)
        }
        updateDisplayedPlugins()
    }

    // Batch uninstall all plugins of a specific format
    private func batchUninstallFormat(_ formatLabel: String) {
        let allPlugins = scanner.plugins.map(AppPluginItem.init)

        // Filter plugins by format
        let pluginsToUninstall = allPlugins.filter { plugin in
            if formatLabel == "OBSLT" {
                return plugin.obsolete
            } else {
                return plugin.type.uppercased() == formatLabel.uppercased()
            }
        }

        guard !pluginsToUninstall.isEmpty else { return }

        batchUninstallPlugins = pluginsToUninstall
        showBatchUninstall = true
    }

    // MARK: - Extracted Views for Type Checking

    @ViewBuilder
    private var compactHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("Filters") {
                    AnimationHelper.withSnappyAnimation(reduceMotion) {
                        showOverlaySidebar.toggle()
                    }
                }
                #if os(macOS)
                .buttonStyle(SpaceModeButtonStyle())
                #else
                .buttonStyle(.bordered)
                #endif

                ZStack(alignment: .trailing) {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.trailing, searchText.isEmpty ? 10 : 30) // Extra padding for clear button
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(colorScheme == .light ? Color.white.opacity(0.1) : Color.black.opacity(0.18)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(searchFocused ? Color.accentColor : (colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.25)), lineWidth: 1)
                        )
                        .focused($searchFocused)

                    // Clear button - only visible when text is present
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clears the search field")
                    }
                }

                Button("Scan") {
                    Task { @MainActor in
                        scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:)))
                    }
                }
                    .disabled(scanner.isScanning)
                    #if os(macOS)
                    .buttonStyle(SpaceModeButtonStyle())
                    #else
                    .buttonStyle(.bordered)
                    #endif

                if let firstSelected = appState.selected.first {
                    AISuggestionsButton(plugin: firstSelected, ownedPlugins: [])
                }
            }

            HStack {
                if !scanner.isScanning {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                            .accessibilityHidden(true)
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Scanner ready")
                }

                Menu {
                    Button("Export CSV") { ExportManager.exportCSV(rows: displayedPlugins) }
                    Button("Export JSON") { ExportManager.exportJSON(rows: displayedPlugins) }
                    Button("Export HTML") { ExportManager.exportHTML(rows: displayedPlugins) }
                    #if os(macOS)
                    Button("Export PDF") {
                        // Use Quick Export with Page Setup settings
                        quickExportPDF(plugins: displayedPlugins, preferences: prefs)
                    }
                    #endif
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .menuStyle(.borderlessButton)
                Spacer()
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var wideHeaderView: some View {
        HStack(spacing: 8) {
            #if os(macOS)
            Button(action: {
                AnimationHelper.withSnappyAnimation(reduceMotion) {
                    showPlaylistSidebar.toggle()
                }
            }) {
                Image(systemName: showPlaylistSidebar ? "sidebar.left" : "sidebar.left")
                    .foregroundColor(showPlaylistSidebar ? .accentColor : .primary)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(showPlaylistSidebar ? "Hide DAW Playlists" : "Show DAW Playlists")
            .help(showPlaylistSidebar ? "Hide DAW Playlists" : "Show DAW Playlists")
            #endif

            Button("Filters") {
                AnimationHelper.withSnappyAnimation(reduceMotion) {
                    showOverlaySidebar.toggle()
                }
            }
            .buttonStyle(.bordered)

            ZStack(alignment: .trailing) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.trailing, searchText.isEmpty ? 10 : 30) // Extra padding for clear button
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(colorScheme == .light ? Color.white.opacity(0.1) : Color.black.opacity(0.18)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(searchFocused ? Color.accentColor : (colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.25)), lineWidth: 1)
                    )
                    .focused($searchFocused)

                // Clear button - only visible when text is present
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .accessibilityHint("Clears the search field")
                }
            }
            .frame(width: 300)

            Button("Scan") {
                Task { @MainActor in
                    scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:)))
                }
            }
                .disabled(scanner.isScanning)
                .buttonStyle(SpaceModeButtonStyle())

            #if os(macOS)
            Button("DAW Import") {
                importDAWProject()
            }
            .buttonStyle(SpaceModeButtonStyle())
            #endif

            Spacer()

            if let firstSelected = appState.selected.first {
                AISuggestionsButton(plugin: firstSelected, ownedPlugins: [])
            }

            Spacer()

            if !scanner.isScanning {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                        .accessibilityHidden(true)
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Scanner ready")
            }

            Menu {
                #if os(macOS)
                Button("Export PDF") {
                    // Use Quick Export with Page Setup settings
                    quickExportPDF(plugins: displayedPlugins, preferences: prefs)
                }
                #endif
                Button("Export CSV") { ExportManager.exportCSV(rows: displayedPlugins) }
                Button("Export HTML") { ExportManager.exportHTML(rows: displayedPlugins) }
                Button("Export JSON") { ExportManager.exportJSON(rows: displayedPlugins) }
            } label: {
                Text("Export")
            }
            .menuIndicator(.hidden)
            .buttonStyle(SpaceModeButtonStyle())

            Button(action: toggleDetailPanel) {
                Image(systemName: "sidebar.right")
                    .foregroundColor((showDetailPanel && showPlaylistSidebar && activePlaylistFilters.count == 1) ? .accentColor : .white)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(showDetailPanel ? "Hide Detail Panel" : "Show Detail Panel")
            .help(showDetailPanel ? "Hide Detail Panel" : "Show Detail Panel")
            .padding(.trailing, 8)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if hSizeClass == .compact {
                compactHeaderView
            } else {
                wideHeaderView
            }

            instantBarsWithBatchedCounts(rows: displayedPlugins)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .background(appBG)
                    
                Divider()
                mainContentWithDetailPanel
                Divider()
                ZStack {
                    // Centered items count
                    Text("\(displayedPlugins.count) items")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Left-aligned sort status
                    HStack {
                        Text(sortStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var bodyWithoutModifiers: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 10)
            mainContentView
            Spacer().frame(width: 10)
        }
    }

    var body: some View {
        bodyWithSidebars
            .background(appBG)
            .clipped()
            .sheet(isPresented: $showDetailSheet) { detailSheet }
            .sheet(isPresented: $showBatchUninstall) { batchUninstallSheet }
            #if os(macOS)
            .sheet(isPresented: $showCreateCustomPlaylist) {
                CreateCustomPlaylistView(playlistManager: playlistManager) { newPlaylist in
                    // After creating, just open the sidebar but DON'T filter
                    // This lets users see all plugins to drag into the new playlist
                    showPlaylistSidebar = true
                    // DON'T auto-select the playlist - let user drag plugins to it
                    // activePlaylistFilters = [newPlaylist]
                    // updateDisplayedPlugins()
                }
            }
            #endif
            #if os(macOS)
            .alert("Replace Existing Playlist?", isPresented: $showDuplicatePlaylistWarning) {
                Button("Cancel", role: .cancel) {
                    pendingImportURL = nil
                    existingPlaylistToReplace = nil
                }
                Button("Replace", role: .destructive) {
                    if let url = pendingImportURL {
                        performImport(url: url, replacingPlaylist: existingPlaylistToReplace)
                    }
                    pendingImportURL = nil
                    existingPlaylistToReplace = nil
                }
            } message: {
                if let existingPlaylist = existingPlaylistToReplace {
                    Text("A playlist named \"\(existingPlaylist.name)\" already exists. Do you want to replace it with the new version?")
                }
            }
            .alert("Import JSON", isPresented: $showJSONImportDialog) {
                Button("Plugin Listing") {
                    if let url = pendingJSONImportURL {
                        performJSONImportToListing(url: url)
                    }
                    pendingJSONImportURL = nil
                }
                Button("New Playlist") {
                    if let url = pendingJSONImportURL {
                        performJSONImportToPlaylist(url: url)
                    }
                    pendingJSONImportURL = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingJSONImportURL = nil
                }
            } message: {
                Text("Would you like to import ratings and notes to the Plugin Listing, or create a new Playlist?")
            }
            #endif
            .onAppear {
                // Defer heavy processing to let UI appear instantly
                setupNotificationListeners()

                // Update plugins after a tiny delay for instant UI
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    updateDisplayedPlugins()
                }
            }
            #if os(macOS)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleFileDrop(providers: providers)
                return true
            }
            #endif
            .onChange(of: appState.selected) { _ in handleSelectionChange() }
            .onChange(of: prefs.selectedFormats) { _ in updateDisplayedPlugins() }
            .onChange(of: prefs.selectedPublishers) { _ in updateDisplayedPlugins() }
            .onChange(of: prefs.selectedStyles) { _ in updateDisplayedPlugins() }
            .onChange(of: prefs.selectedStarRatings) { _ in updateDisplayedPlugins() }
            .onChange(of: searchText) { newValue in handleSearchTextChange(newValue) }
            .onChange(of: scanner.plugins.count) { _ in
                updateDisplayedPlugins()
                // Update total unfiltered counts for playlist mode bar graph
                let allPlugins = scanner.plugins.map(AppPluginItem.init)
                totalPluginCounts = quickCount(rows: allPlugins)
            }
            #if os(macOS)
            .overlay {
                if playlistManager.isImporting {
                    dawImportProgressOverlay
                }
            }
            #endif
    }

    @ViewBuilder
    private var bodyWithSidebars: some View {
        bodyWithoutModifiers
            .overlay(alignment: .leading) { filterSidebarOverlay }
            .animation(suppressAnimations ? nil : AnimationHelper.snappy(reduceMotion), value: showOverlaySidebar)
            .animation(suppressAnimations ? nil : AnimationHelper.snappy(reduceMotion), value: showPlaylistSidebar)
            .transaction { tx in if suppressAnimations { tx.animation = nil } }
    }

    @ViewBuilder
    private var detailSheet: some View {
        if let item = appState.selected.first {
            PluginDetailView(item: item)
        }
    }

    @ViewBuilder
    private var batchUninstallSheet: some View {
        UninstallConfirmationView(
            plugins: batchUninstallPlugins,
            onComplete: { result in
                Task { @MainActor in
                    scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:)))
                }
            }
        )
    }

    #if os(macOS)
    @ViewBuilder
    private var dawImportProgressOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)

                // Title
                Text("Importing DAW Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: playlistManager.importProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 300)
                        .tint(.white)

                    Text("\(Int(playlistManager.importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
        }
    }
    #endif

    private func handleSelectionChange() {
        if hSizeClass == .compact {
            showDetailSheet = (appState.selected.first != nil)
        }
        appState.updateSelectionIDs()
    }

    private func handleAppearanceChange(_ newValue: AppPreferences.Appearance) {
        if newValue == AppPreferences.Appearance.system {
            suppressAnimations = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                suppressAnimations = false
            }
        }
    }

    #if os(macOS)
    private func importDAWProject() {
        // Use pre-created panel - should be INSTANT!
        let response = dawPanel.runModal()
        if response == .OK {
            let urls = dawPanel.urls

            // Import all selected files IN PARALLEL for speed!
            Task { @MainActor in
                var importedPlaylists: [DAWPlaylist] = []

                await withTaskGroup(of: DAWPlaylist?.self) { group in
                    for url in urls {
                        group.addTask {
                            await self.performImportAsync(url: url)
                        }
                    }

                    for await playlist in group {
                        if let playlist = playlist {
                            importedPlaylists.append(playlist)
                        }
                    }
                }

                // After all imports complete, batch-add them (ONE @Published update!)
                if !importedPlaylists.isEmpty {
                    playlistManager.addPlaylists(importedPlaylists)

                    // Activate them and open playlist sidebar
                    self.activePlaylistFilters = importedPlaylists
                    self.showPlaylistSidebar = true
                    self.updateDisplayedPlugins()
                }
            }
        }
    }

    private func performImportAsync(url: URL) async -> DAWPlaylist? {
        do {
            let installedPlugins = scanner.plugins.map(AppPluginItem.init)
            let playlist = try await playlistManager.importProject(url: url, installedPlugins: installedPlugins)

            await MainActor.run {
                AppLogger.info("✅ Imported \(playlist.name)")
            }

            return playlist
        } catch {
            await MainActor.run {
                AppLogger.error("❌ Failed to import \(url.lastPathComponent): \(error.localizedDescription)")
            }
            return nil
        }
    }

    private func performImport(url: URL, replacingPlaylist: DAWPlaylist?) {
        Task {
            // If replacing, delete the old one BEFORE importing the new one
            if let oldPlaylist = replacingPlaylist {
                await MainActor.run {
                    AppLogger.info("Removing existing playlist '\(oldPlaylist.name)' before importing new version")
                    self.playlistManager.deletePlaylist(oldPlaylist)
                    if let index = self.activePlaylistFilters.firstIndex(where: { $0.id == oldPlaylist.id }) {
                        self.activePlaylistFilters.remove(at: index)
                    }
                }
            }

            do {
                let installedPlugins = self.scanner.plugins.map(AppPluginItem.init)
                let playlist = try await self.playlistManager.importProject(url: url, installedPlugins: installedPlugins)

                await MainActor.run {
                    // Add the playlist to the manager (batch method works for single playlist too)
                    self.playlistManager.addPlaylists([playlist])

                    // Open the playlist sidebar and select the newly imported playlist
                    self.showPlaylistSidebar = true
                    self.activePlaylistFilters = [playlist]
                    // Apply the playlist filter to show only plugins used in this project
                    self.updateDisplayedPlugins()
                    AppLogger.info("Successfully imported playlist: \(playlist.name)")
                }
            } catch {
                await MainActor.run {
                    AppLogger.error("Failed to import DAW project: \(error.localizedDescription)")

                    // Show error alert to user
                    let alert = NSAlert()
                    alert.messageText = "DAW Import Failed"
                    alert.informativeText = "Failed to import project: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.title = "Import JSON"
        panel.message = "Choose a JSON file exported from Plugin Reporter"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self.pendingJSONImportURL = url
                self.showJSONImportDialog = true
            }
        }
    }

    private func performJSONImportToListing(url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let importedPlugins = try decoder.decode([ImportedJSONPlugin].self, from: data)

                await MainActor.run {
                    // Import ratings and notes for matching plugins
                    var ratingsImported = 0
                    var notesImported = 0

                    for plugin in importedPlugins {
                        // Match by path for exact matching
                        if plugin.rating > 0 {
                            RatingsManager.shared.setRating(for: plugin.path, rating: plugin.rating)
                            ratingsImported += 1
                        }
                        if !plugin.notes.isEmpty {
                            NotesManager.shared.setNote(for: plugin.path, note: plugin.notes)
                            notesImported += 1
                        }
                    }

                    AppLogger.info("JSON import to listing: \(ratingsImported) ratings, \(notesImported) notes")

                    // Show success alert
                    let alert = NSAlert()
                    alert.messageText = "Import Complete"
                    alert.informativeText = "Imported \(ratingsImported) ratings and \(notesImported) notes to Plugin Listing."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            } catch {
                await MainActor.run {
                    AppLogger.error("Failed to import JSON: \(error.localizedDescription)")
                    let alert = NSAlert()
                    alert.messageText = "Import Failed"
                    alert.informativeText = "Failed to import JSON file: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    private func performJSONImportToPlaylist(url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let importedPlugins = try decoder.decode([ImportedJSONPlugin].self, from: data)

                await MainActor.run {
                    // Create a new playlist with the imported plugins
                    let playlistName = url.deletingPathExtension().lastPathComponent

                    // Create custom playlist entries from imported JSON
                    let entries = importedPlugins.map { plugin in
                        DAWPlaylistEntry(
                            pluginName: plugin.name,
                            pluginManufacturer: plugin.publisher,
                            trackName: plugin.track ?? "Imported",
                            trackIndex: 0,
                            deviceIndex: 0,
                            pluginFormat: PluginFormat(rawValue: plugin.type) ?? .VST3,
                            isInstalled: !plugin.missing,
                            matchedPluginPath: plugin.path
                        )
                    }

                    // Create custom playlist
                    let playlist = DAWPlaylist(
                        name: playlistName,
                        entries: entries
                    )

                    // Add to playlist manager
                    self.playlistManager.addCustomPlaylist(playlist)

                    // Also import ratings and notes
                    var ratingsImported = 0
                    var notesImported = 0

                    for plugin in importedPlugins {
                        if plugin.rating > 0 {
                            RatingsManager.shared.setRating(for: plugin.path, rating: plugin.rating)
                            ratingsImported += 1
                        }
                        if !plugin.notes.isEmpty {
                            NotesManager.shared.setNote(for: plugin.path, note: plugin.notes)
                            notesImported += 1
                        }
                    }

                    AppLogger.info("JSON import to playlist '\(playlistName)': \(entries.count) plugins, \(ratingsImported) ratings, \(notesImported) notes")

                    // Open playlist sidebar and select the newly imported playlist
                    self.showPlaylistSidebar = true
                    self.activePlaylistFilters = [playlist]

                    // Show success alert
                    let alert = NSAlert()
                    alert.messageText = "Import Complete"
                    alert.informativeText = "Created playlist '\(playlistName)' with \(entries.count) plugins.\nImported \(ratingsImported) ratings and \(notesImported) notes."
                    alert.alertStyle = .informational
                    alert.runModal()
                }
            } catch {
                await MainActor.run {
                    AppLogger.error("Failed to import JSON: \(error.localizedDescription)")
                    let alert = NSAlert()
                    alert.messageText = "Import Failed"
                    alert.informativeText = "Failed to import JSON file: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        // Supported DAW file extensions
        let supportedExtensions = [
            "als", "logicx", "band", "concert", "cpr", "npr", "song",
            "ptx", "txt", "bwproject", "reason", "rpp", "motu", "flp",
            "tracktionedit", "ardour", "mixbus", "xrns", "drp"
        ]

        guard !providers.isEmpty else { return false }

        // Process all providers (multiple files)
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                guard let data = urlData as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                let fileExtension = url.pathExtension.lowercased()

                // Check if it's a supported DAW file
                guard supportedExtensions.contains(fileExtension) else {
                    print("❌ Unsupported file type: .\(fileExtension)")
                    return
                }

                print("📥 Dropped DAW file: \(url.lastPathComponent)")

                // Check for duplicate playlist
                DispatchQueue.main.async {
                    let projectName = url.deletingPathExtension().lastPathComponent

                    if let existing = self.playlistManager.playlists.first(where: { $0.name == projectName }) {
                        // Show duplicate warning
                        self.pendingImportURL = url
                        self.existingPlaylistToReplace = existing
                        self.showDuplicatePlaylistWarning = true
                    } else {
                        // Import directly
                        self.performImport(url: url, replacingPlaylist: nil)
                    }
                }
            }
        }

        return true
    }
    #endif

    @ViewBuilder
    private var filterSidebarOverlay: some View {
        if showOverlaySidebar {
            ZStack(alignment: .leading) {
                // Slide-over panel
                    VStack(alignment: .leading, spacing: 12) {
                        // Top padding to prevent cutoff
                        Spacer().frame(height: 30)
                        
                        // Header with title and close button
                        ZStack {
                            // Centered title
                            Text("Filters")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            // Close button aligned to trailing edge (top right corner)
                            HStack {
                                Spacer()
                                Button(action: {
                                    AnimationHelper.withSnappyAnimation(reduceMotion) {
                                        showOverlaySidebar = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(6)
                                        .background(Circle().fill(Color.white.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Close filters")
                                .accessibilityHint("Closes the filter sidebar")
                                .offset(x: 8, y: -8)  // Push into top right corner
                            }
                        }
                        .padding(.horizontal, 4)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)  // 10px padding above Type
                            FormatsCloud(selectedFormats: $prefs.selectedFormats, useFullObsoleteLabel: true)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)  // Additional padding between Type and cloud
                                .padding(.bottom, 10)  // 10px padding under OBSLT
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)  // 10px padding above Rating
                            StarsSelector(selectedStarRatings: $prefs.selectedStarRatings)
                                .padding(.bottom, 10)  // 10px padding below Rating
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Styles")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)  // 10px padding above Styles
                            StyleDropdown(
                                allStyles: Array(Set(scanner.plugins.map(\.style).filter { !$0.isEmpty })).sorted(),
                                selectedStyles: $prefs.selectedStyles
                            )
                            .padding(.bottom, 10)  // 10px padding below All Styles
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Publishers")
                                .padding(.top, 10)  // 10px padding above Publishers
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            PublisherDropdown(
                                allPublishers: Array(Set(scanner.plugins.map(\.publisher))).sorted(),
                                selectedPublishers: $prefs.selectedPublishers
                            )
                        }

                        Divider()
                            .padding(.top, 10)

                        // Clear Filters button
                        if !prefs.selectedFormats.isEmpty || !prefs.selectedStarRatings.isEmpty || !prefs.selectedStyles.isEmpty || !prefs.selectedPublishers.isEmpty {
                            Button {
                                prefs.selectedFormats.removeAll()
                                prefs.selectedStarRatings.removeAll()
                                prefs.selectedStyles.removeAll()
                                prefs.selectedPublishers.removeAll()
                                updateDisplayedPlugins()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .accessibilityHidden(true)
                                    Text("Clear Filters")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear all filters")
                            .accessibilityHint("Removes all active format, style, publisher, and rating filters")
                            .padding(.top, 10)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .frame(width: 260)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(appBG)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 0)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            .allowsHitTesting(true)  // Panel captures its own taps
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var playlistSidebarPanel: some View {
        #if os(macOS)
        if showPlaylistSidebar {
            PlaylistSidebarView(
                playlists: playlistManager.playlists.sorted(by: { $0.dateImported > $1.dateImported }),
                activePlaylists: $activePlaylistFilters,
                showDetailPanel: $showDetailPanel,
                onSelect: { playlists, modifiers in
                    // Handle selection based on modifier keys
                    // This receives an array of playlists to select

                    if modifiers.isEmpty {
                        // Check if clicking on an already-selected playlist
                        let clickingAlreadySelected = (activePlaylistFilters.count == 1 &&
                                                      playlists.count == 1 &&
                                                      activePlaylistFilters.first?.id == playlists.first?.id)

                        // No modifiers: replace selection
                        activePlaylistFilters = playlists

                        if clickingAlreadySelected {
                            // Clicking on already-selected playlist
                            print("🎵 Clicking already-selected playlist, sidecar open: \(showDetailPanel)")
                            // Only show playlist metadata if sidecar is already open
                            if showDetailPanel {
                                print("   → Clearing plugin selection (had \(appState.selected.count) selected)")
                                // Clear plugin selection FIRST
                                appState.selected = []
                                // Force refresh on next run loop to ensure selection is cleared
                                Task { @MainActor in
                                    detailPanelRefreshTrigger.toggle()
                                    print("   → Toggled refresh trigger to \(detailPanelRefreshTrigger)")
                                }
                            }
                            // If sidecar is closed, do nothing (don't open it)
                            // DON'T call updateDisplayedPlugins() - it would restore the plugin selection!
                        } else {
                            print("🎵 Clicking different playlist")
                            // Clicking on a different playlist
                            // Clear plugin selection, open sidecar, and show playlist metadata
                            appState.selected = []
                            detailPanelRefreshTrigger.toggle()
                            showDetailPanel = true
                            // Defer expensive filtering for instant UI response (especially during arrow key navigation)
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                                updateDisplayedPlugins()
                            }
                        }
                    } else if modifiers.contains(.shift) {
                        // Shift: set range selection (already computed by view)
                        activePlaylistFilters = playlists
                        // Clear plugin selection, toggle refresh, and show detail panel
                        appState.selected = []
                        detailPanelRefreshTrigger.toggle()
                        showDetailPanel = true
                        // Defer for instant response
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                            updateDisplayedPlugins()
                        }
                    } else if modifiers.contains(.command) {
                        // CMD: toggle individual playlist
                        if let playlist = playlists.first {
                            if let index = activePlaylistFilters.firstIndex(where: { $0.id == playlist.id }) {
                                activePlaylistFilters.remove(at: index)
                            } else {
                                activePlaylistFilters.append(playlist)
                            }
                        }
                        // Show detail panel if we have exactly one playlist selected
                        if activePlaylistFilters.count == 1 {
                            // Clear plugin selection and toggle refresh trigger
                            appState.selected = []
                            detailPanelRefreshTrigger.toggle()
                            showDetailPanel = true
                        }
                        // Defer for instant response
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                            updateDisplayedPlugins()
                        }
                    }
                },
                onDelete: { playlist in
                    playlistManager.deletePlaylist(playlist)
                    if let index = activePlaylistFilters.firstIndex(where: { $0.id == playlist.id }) {
                        activePlaylistFilters.remove(at: index)
                    }
                    updateDisplayedPlugins()
                },
                onEditMetadata: {
                    // Clear plugin selection when Edit Metadata is clicked on a playlist
                    appState.selected = []
                    // Force detail panel refresh to show playlist metadata
                    detailPanelRefreshTrigger.toggle()
                },
                onImport: {
                    showCreateCustomPlaylist = true
                },
                playlistManager: playlistManager
            )
        }
        #endif
    }

    // MARK: - Bar Graph Helpers

    private func instantBarsWithBatchedCounts(rows: [AppPluginItem]) -> some View {
        // INSTANT bar graph - recalculates on EVERY change for instant feedback
        let currentCount = rows.count

        // Always update immediately - no batching delay
        let shouldUpdate = true

        if shouldUpdate {
            // Update cache
            Task { @MainActor in
                self.lastBarUpdateCount = currentCount
                self.cachedBarCounts = self.quickCount(rows: rows)
                // Also update total unfiltered counts for playlist mode
                let allPlugins = scanner.plugins.map(AppPluginItem.init)
                self.totalPluginCounts = self.quickCount(rows: allPlugins)
            }
        }

        // When playlists are open, show total counts; otherwise show filtered counts
        let displayCounts = showPlaylistSidebar ? totalPluginCounts : cachedBarCounts
        let playlistCounts = cachedBarCounts  // Filtered counts for playlist mode
        let isEmpty = scanner.plugins.isEmpty

        // Use MAX count method (like normal mode) for consistent bar sizing
        let maxCount = Swift.max(1, playlistCounts.au, playlistCounts.vst, playlistCounts.vst3, playlistCounts.aax, playlistCounts.clap, playlistCounts.lv2, playlistCounts.obsolete, playlistCounts.missing)

        return VStack(alignment: .leading, spacing: 6) {
            // When playlist sidebar is open, show bars for types that exist in library OR in playlist
            // Otherwise, only show bars when count > 0
            if showPlaylistSidebar {
                // Playlist mode: show bars for types in library or playlist, with bar length based on playlist counts
                if displayCounts.au > 0 || playlistCounts.au > 0 {
                    BarRow(
                        label: "AU", value: playlistCounts.au,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.au) / Double(maxCount),
                        color: .blue,
                        onTap: { toggleFormat(.AU) },
                        isSelected: prefs.selectedFormats.contains(.AU),
                        onUninstall: { batchUninstallFormat("AU") }
                    )
                }
                if displayCounts.vst > 0 || playlistCounts.vst > 0 {
                    BarRow(
                        label: "VST", value: playlistCounts.vst,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.vst) / Double(maxCount),
                        color: .green,
                        onTap: { toggleFormat(.VST) },
                        isSelected: prefs.selectedFormats.contains(.VST),
                        onUninstall: { batchUninstallFormat("VST") }
                    )
                }
                if displayCounts.vst3 > 0 || playlistCounts.vst3 > 0 {
                    BarRow(
                        label: "VST3", value: playlistCounts.vst3,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.vst3) / Double(maxCount),
                        color: .teal,
                        onTap: { toggleFormat(.VST3) },
                        isSelected: prefs.selectedFormats.contains(.VST3),
                        onUninstall: { batchUninstallFormat("VST3") }
                    )
                }
                if displayCounts.aax > 0 || playlistCounts.aax > 0 {
                    BarRow(
                        label: "AAX", value: playlistCounts.aax,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.aax) / Double(maxCount),
                        color: .purple,
                        onTap: { toggleFormat(.AAX) },
                        isSelected: prefs.selectedFormats.contains(.AAX),
                        onUninstall: { batchUninstallFormat("AAX") }
                    )
                }
                if displayCounts.clap > 0 || playlistCounts.clap > 0 {
                    BarRow(
                        label: "CLAP", value: playlistCounts.clap,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.clap) / Double(maxCount),
                        color: .orange,
                        onTap: { toggleFormat(.CLAP) },
                        isSelected: prefs.selectedFormats.contains(.CLAP),
                        onUninstall: { batchUninstallFormat("CLAP") }
                    )
                }
                if displayCounts.lv2 > 0 || playlistCounts.lv2 > 0 {
                    BarRow(
                        label: "LV2", value: playlistCounts.lv2,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.lv2) / Double(maxCount),
                        color: .gray,
                        onTap: { toggleFormat(.LV2) },
                        isSelected: prefs.selectedFormats.contains(.LV2),
                        onUninstall: { batchUninstallFormat("LV2") }
                    )
                }
                if displayCounts.obsolete > 0 || playlistCounts.obsolete > 0 {
                    BarRow(
                        label: "OBSLT", value: playlistCounts.obsolete,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.obsolete) / Double(maxCount),
                        color: .red,
                        onTap: { toggleFormat(.OBSLT) },
                        isSelected: prefs.selectedFormats.contains(.OBSLT),
                        onUninstall: { batchUninstallFormat("OBSLT") }
                    )
                }
                if playlistCounts.missing > 0 {
                    BarRow(
                        label: "MISNG", value: playlistCounts.missing,
                        fraction: isEmpty ? 0.0 : Double(playlistCounts.missing) / Double(maxCount),
                        color: .red
                    )
                }
            } else {
                // Normal mode: show bars for types that exist in library (total > 0), using total counts for bar lengths
                let counts = cachedBarCounts  // Filtered counts for display
                let totalCounts = totalPluginCounts  // Unfiltered counts for bar fractions
                let maxCount = Swift.max(1, totalCounts.au, totalCounts.vst, totalCounts.vst3, totalCounts.aax, totalCounts.clap, totalCounts.lv2, totalCounts.obsolete)
                let hasData = currentCount > 0

                if totalCounts.au > 0 {
                    BarRow(
                        label: "AU", value: counts.au,
                        fraction: hasData ? Double(totalCounts.au) / Double(maxCount) : 0.0,
                        color: Color.blue,
                        onTap: { toggleFormat(.AU) },
                        isSelected: prefs.selectedFormats.contains(.AU),
                        onUninstall: { batchUninstallFormat("AU") }
                    )
                }
                if totalCounts.vst > 0 {
                    BarRow(
                        label: "VST", value: counts.vst,
                        fraction: hasData ? Double(totalCounts.vst) / Double(maxCount) : 0.0,
                        color: Color.green,
                        onTap: { toggleFormat(.VST) },
                        isSelected: prefs.selectedFormats.contains(.VST),
                        onUninstall: { batchUninstallFormat("VST") }
                    )
                }
                if totalCounts.vst3 > 0 {
                    BarRow(
                        label: "VST3", value: counts.vst3,
                        fraction: hasData ? Double(totalCounts.vst3) / Double(maxCount) : 0.0,
                        color: Color.teal,
                        onTap: { toggleFormat(.VST3) },
                        isSelected: prefs.selectedFormats.contains(.VST3),
                        onUninstall: { batchUninstallFormat("VST3") }
                    )
                }
                if totalCounts.aax > 0 {
                    BarRow(
                        label: "AAX", value: counts.aax,
                        fraction: hasData ? Double(totalCounts.aax) / Double(maxCount) : 0.0,
                        color: Color.purple,
                        onTap: { toggleFormat(.AAX) },
                        isSelected: prefs.selectedFormats.contains(.AAX),
                        onUninstall: { batchUninstallFormat("AAX") }
                    )
                }
                if totalCounts.clap > 0 {
                    BarRow(
                        label: "CLAP", value: counts.clap,
                        fraction: hasData ? Double(totalCounts.clap) / Double(maxCount) : 0.0,
                        color: Color.orange,
                        onTap: { toggleFormat(.CLAP) },
                        isSelected: prefs.selectedFormats.contains(.CLAP),
                        onUninstall: { batchUninstallFormat("CLAP") }
                    )
                }
                if totalCounts.lv2 > 0 {
                    BarRow(
                        label: "LV2", value: counts.lv2,
                        fraction: hasData ? Double(totalCounts.lv2) / Double(maxCount) : 0.0,
                        color: Color.gray,
                        onTap: { toggleFormat(.LV2) },
                        isSelected: prefs.selectedFormats.contains(.LV2),
                        onUninstall: { batchUninstallFormat("LV2") }
                    )
                }
                if totalCounts.obsolete > 0 {
                    BarRow(
                        label: "OBSLT", value: counts.obsolete,
                        fraction: hasData ? Double(totalCounts.obsolete) / Double(maxCount) : 0.0,
                        color: Color.red,
                        onTap: { toggleFormat(.OBSLT) },
                        isSelected: prefs.selectedFormats.contains(.OBSLT),
                        onUninstall: { batchUninstallFormat("OBSLT") }
                    )
                }
            }

            // Action buttons
            barGraphActionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
        .id(cachedBarCounts) // Only re-render when cached counts actually change
    }

    // Main content with optional detail panel (extracted to reduce type-checking complexity)
    @ViewBuilder
    private var mainContentWithDetailPanel: some View {
        HStack(spacing: 0) {
            #if os(macOS)
            // DAW Playlists Panel - Left side
            playlistSidebarPanel
            #endif

            ZStack {
                appBG
                PlatformTable(
                    rows: displayedPlugins,
                    selection: $appState.selected,
                    sortStatus: $sortStatus,
                    showDetailPanel: $showDetailPanel,
                    detailPanelTab: $detailPanelTab,
                    onPluginsDeleted: {
                        Task { @MainActor in
                            scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:)))
                        }
                    }
                )
                .id(displayedPlugins.map(\.id))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }

            #if os(macOS)
            // Detail Panel - Priority:
            // 1. Bulk edit when multiple plugins selected
            // 2. Plugin detail when single plugin selected
            // 3. Playlist metadata when playlist sidebar is open, a playlist is selected, and NO plugins selected
            // 4. Plugin detail panel (empty) as default
            Group {
                if appState.selected.count > 1 {
                    BulkEditPanel(
                        plugins: appState.selected,
                        isVisible: $showDetailPanel
                    )
                    .onAppear { print("📊 Detail Panel: Showing BulkEditPanel") }
                } else if appState.selected.count == 1 {
                    PluginDetailPanel(
                        plugin: appState.selected.first,
                        isVisible: $showDetailPanel,
                        selectedTab: $detailPanelTab
                    )
                    .onAppear { print("📊 Detail Panel: Showing PluginDetailPanel for \(appState.selected.first?.name ?? "unknown")") }
                } else if showPlaylistSidebar && activePlaylistFilters.count == 1 {
                    PlaylistMetadataPanel(
                        playlist: activePlaylistFilters.first,
                        isVisible: $showDetailPanel
                    )
                    .onAppear { print("📊 Detail Panel: Showing PlaylistMetadataPanel for \(activePlaylistFilters.first?.name ?? "unknown")") }
                } else {
                    PluginDetailPanel(
                        plugin: nil,
                        isVisible: $showDetailPanel,
                        selectedTab: $detailPanelTab
                    )
                    .onAppear { print("📊 Detail Panel: Showing empty PluginDetailPanel") }
                }
            }
            .id(detailPanelRefreshTrigger)  // Force rebuild when trigger toggles
            #endif
        }
    }

    // Bar graph action buttons (extracted to reduce type-checking complexity)
    @ViewBuilder
    private var barGraphActionButtons: some View {
        #if os(macOS)
        // Action buttons arranged horizontally
        let hasPlaylist = !activePlaylistFilters.isEmpty
        let hasFilters = !prefs.selectedFormats.isEmpty || !prefs.selectedStarRatings.isEmpty

        if hasPlaylist || hasFilters {
            HStack(spacing: 8) {
                // Close Playlist button (when playlist is active)
                if hasPlaylist {
                    Button {
                        activePlaylistFilters.removeAll()
                        updateDisplayedPlugins()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                                .accessibilityHidden(true)
                            Text("Close Playlists").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close playlists")
                    .accessibilityHint("Closes all active DAW playlist filters")
                }

                // Clear Filters button (when format or rating filters are selected)
                if hasFilters {
                    Button {
                        prefs.selectedFormats.removeAll()
                        prefs.selectedStarRatings.removeAll()
                        updateDisplayedPlugins()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                                .accessibilityHidden(true)
                            Text("Clear Filters").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filters")
                    .accessibilityHint("Clears format and rating filters")
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        #else
        if !prefs.selectedFormats.isEmpty || !prefs.selectedStarRatings.isEmpty {
            Button {
                prefs.selectedFormats.removeAll()
                prefs.selectedStarRatings.removeAll()
                updateDisplayedPlugins()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        .accessibilityHidden(true)
                    Text("Clear Filter").font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.red)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear filter")
            .accessibilityHint("Clears all active filters")
            .padding(.top, 4)
        }
        #endif
    }

    // Ultra-fast counting helper (now uses shared utility)
    private func quickCount(rows: [AppPluginItem]) -> FormatCounts {
        return countFormats(for: rows)
    }

    // MARK: - Menu Bar Notification Handlers

    private func setupNotificationListeners() {
        #if os(macOS)
        // File menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ImportDAWProject"), object: nil, queue: .main) { [self] _ in
            self.importDAWProject()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ImportJSON"), object: nil, queue: .main) { [self] _ in
            self.importJSON()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportCSV"), object: nil, queue: .main) { [self] _ in
            ExportManager.exportCSV(rows: self.displayedPlugins)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportJSON"), object: nil, queue: .main) { [self] _ in
            ExportManager.exportJSON(rows: self.displayedPlugins)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportHTML"), object: nil, queue: .main) { [self] _ in
            ExportManager.exportHTML(rows: self.displayedPlugins)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExportPDF"), object: nil, queue: .main) { [self] _ in
            // Quick export using Page Setup settings (landscape by default)
            let plugins = self.displayedPlugins
            print("🔵 ContentView: Sending \(plugins.count) plugins to Quick Export")
            print("🔵 First 5: \(plugins.prefix(5).map { $0.name })")
            quickExportPDF(plugins: plugins, preferences: self.prefs)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowPageSetup"), object: nil, queue: .main) { [self] _ in
            // Show Page Setup with current displayed plugins (matches what will be exported)
            let plugins = self.displayedPlugins
            print("🔵 ContentView: Sending \(plugins.count) plugins to Page Setup")
            print("🔵 First 5: \(plugins.prefix(5).map { $0.name })")
            showCustomPageSetup(preferences: self.prefs, plugins: plugins)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("PrintPlugins"), object: nil, queue: .main) { [self] _ in
            // Print current displayed plugins using Page Setup settings
            print("🖨️ Print button clicked")
            print("📐 Margins from prefs: T=\(self.prefs.pdfTopMargin), B=\(self.prefs.pdfBottomMargin), L=\(self.prefs.pdfLeftMargin), R=\(self.prefs.pdfRightMargin)")
            print("📄 Page: \(self.prefs.pdfPage.rawValue), Landscape: \(self.prefs.pdfLandscape)")

            let plugins = self.displayedPlugins

            // Create a copy of NSPrintInfo to configure with our preferences
            let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo

            var pageSize = self.prefs.pdfPage.sizePoints
            if self.prefs.pdfLandscape {
                pageSize = CGSize(width: pageSize.height, height: pageSize.width)
            }
            // Set paper size and orientation
            printInfo.paperSize = pageSize
            printInfo.orientation = self.prefs.pdfLandscape ? .landscape : .portrait

            // CRITICAL: Set margins in the dictionary to make them stick in the print panel
            printInfo.dictionary()[NSPrintInfo.AttributeKey.leftMargin] = self.prefs.pdfLeftMargin
            printInfo.dictionary()[NSPrintInfo.AttributeKey.rightMargin] = self.prefs.pdfRightMargin
            printInfo.dictionary()[NSPrintInfo.AttributeKey.topMargin] = self.prefs.pdfTopMargin
            printInfo.dictionary()[NSPrintInfo.AttributeKey.bottomMargin] = self.prefs.pdfBottomMargin

            // Also set via properties
            printInfo.leftMargin = self.prefs.pdfLeftMargin
            printInfo.rightMargin = self.prefs.pdfRightMargin
            printInfo.topMargin = self.prefs.pdfTopMargin
            printInfo.bottomMargin = self.prefs.pdfBottomMargin

            print("✅ Set printInfo margins: T=\(printInfo.topMargin), B=\(printInfo.bottomMargin), L=\(printInfo.leftMargin), R=\(printInfo.rightMargin)")

            // Also update the shared instance so createPrintablePluginView can use it
            NSPrintInfo.shared.paperSize = pageSize
            NSPrintInfo.shared.orientation = self.prefs.pdfLandscape ? .landscape : .portrait
            NSPrintInfo.shared.leftMargin = self.prefs.pdfLeftMargin
            NSPrintInfo.shared.rightMargin = self.prefs.pdfRightMargin
            NSPrintInfo.shared.topMargin = self.prefs.pdfTopMargin
            NSPrintInfo.shared.bottomMargin = self.prefs.pdfBottomMargin

            let printView = createPrintablePluginView(plugins: plugins, preferences: self.prefs)

            if let window = NSApp.keyWindow {
                let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)

                // Generate filename with timestamp (same as Quick Export)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = formatter.string(from: Date())
                let defaultName = "Plugins_\(timestamp)"

                // Set the job title which becomes the default filename when saving as PDF
                printOperation.jobTitle = defaultName

                // Access the print panel and update it with our settings
                let printPanel = printOperation.printPanel
                printPanel.options.insert(.showsPaperSize)
                printPanel.options.insert(.showsOrientation)

                // Force the panel to use our printInfo
                printOperation.printInfo.leftMargin = self.prefs.pdfLeftMargin
                printOperation.printInfo.rightMargin = self.prefs.pdfRightMargin
                printOperation.printInfo.topMargin = self.prefs.pdfTopMargin
                printOperation.printInfo.bottomMargin = self.prefs.pdfBottomMargin

                print("🖨️ Final check before panel - margins: T=\(printOperation.printInfo.topMargin), B=\(printOperation.printInfo.bottomMargin), L=\(printOperation.printInfo.leftMargin), R=\(printOperation.printInfo.rightMargin)")
                print("📄 Default filename: \(defaultName)")

                // Run as a free-floating window instead of modal sheet
                // This allows moving and resizing freely
                DispatchQueue.main.async {
                    printOperation.run()
                }
            }
        }

        // View menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleFilters"), object: nil, queue: .main) { [self] _ in
            AnimationHelper.withSnappyAnimation(self.reduceMotion) {
                self.showOverlaySidebar.toggle()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("TogglePlaylists"), object: nil, queue: .main) { [self] _ in
            AnimationHelper.withSnappyAnimation(self.reduceMotion) {
                self.showPlaylistSidebar.toggle()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleMetadata"), object: nil, queue: .main) { [self] _ in
            self.toggleDetailPanel()
        }

        // Plugins menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ScanPlugins"), object: nil, queue: .main) { [self] _ in
            Task { @MainActor in
                self.scanner.scan(extraPaths: self.prefs.extraScanPaths.map(URL.init(fileURLWithPath:)))
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowInFinder"), object: nil, queue: .main) { [self] _ in
            guard !self.appState.selected.isEmpty else { return }
            let urls = self.appState.selected.map { URL(fileURLWithPath: $0.path) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("CheckUpdate"), object: nil, queue: .main) { [self] _ in
            guard let plugin = self.appState.selected.first else { return }
            if let url = URL(string: "https://\(self.generateWebsiteURL(for: plugin.publisher))") {
                NSWorkspace.shared.open(url)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("EditMetadata"), object: nil, queue: .main) { [self] _ in
            guard !self.appState.selected.isEmpty else { return }
            self.detailPanelTab = .metadata
            self.showDetailPanel = true
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowLicense"), object: nil, queue: .main) { [self] _ in
            guard !self.appState.selected.isEmpty else { return }
            self.detailPanelTab = .license
            self.showDetailPanel = true
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("UninstallSelected"), object: nil, queue: .main) { [self] _ in
            guard !self.appState.selected.isEmpty else { return }
            self.batchUninstallPlugins = self.appState.selected
            self.showBatchUninstall = true
        }

        // Playlists menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NewPlaylist"), object: nil, queue: .main) { [self] _ in
            self.showCreateCustomPlaylist = true
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("PlaylistSortDateImported"), object: nil, queue: .main) { _ in
            // This will need to access the PlaylistSidebarView state - posting notification for now
            NotificationCenter.default.post(name: NSNotification.Name("SetPlaylistSort"), object: "dateImported")
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("PlaylistSortName"), object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("SetPlaylistSort"), object: "name")
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("PlaylistFilterMissing"), object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("TogglePlaylistFilterMissing"), object: nil)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("PlaylistClearAllFilters"), object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: NSNotification.Name("ClearPlaylistFilters"), object: nil)
        }
        #endif
    }

    private func generateWebsiteURL(for publisher: String) -> String {
        let clean = publisher.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "inc", with: "")
            .replacingOccurrences(of: "llc", with: "")
            .replacingOccurrences(of: "gmbh", with: "")

        return "\(clean).com"
    }
}

// MARK: - Summary Bars Helper
// Extracted to: Components/SummaryBars.swift

// MARK: - Filter Dropdowns
// Extracted to: Components/FilterDropdowns.swift

// MARK: - iOS Detail View
// Extracted to: Views/PluginDetailView.swift

// MARK: - Rating Selector Component
// Extracted to: Components/StarsSelector.swift

// MARK: - Zoom Environment
// Extracted to: Helpers/ZoomEnvironment.swift

// MARK: - Playlist Components
// Note: PlaylistSidebarView and PlaylistRowView have been extracted to separate files:
// - Views/Playlists/PlaylistSidebarView.swift
// - Views/Playlists/PlaylistRowView.swift

// MARK: - Space Mode Button Style
// Extracted to: Styles/SpaceModeButtonStyle.swift


// MARK: - Fast Filter Engine (NEW - SIMPLE & CORRECT)

// FastFilterEngine moved to separate file: FastFilterEngine.swift
