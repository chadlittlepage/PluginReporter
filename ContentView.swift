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
                    withAnimation(.snappy(duration: 0.2)) {
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
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                withAnimation(.snappy(duration: 0.2)) {
                    showPlaylistSidebar.toggle()
                }
            }) {
                Image(systemName: showPlaylistSidebar ? "sidebar.left" : "sidebar.left")
                    .foregroundColor(showPlaylistSidebar ? .accentColor : .primary)
            }
            .buttonStyle(.bordered)
            .help(showPlaylistSidebar ? "Hide DAW Playlists" : "Show DAW Playlists")
            #endif

            Button("Filters") {
                withAnimation(.snappy(duration: 0.2)) {
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
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            .animation(suppressAnimations ? nil : .snappy(duration: 0.2), value: showOverlaySidebar)
            .animation(suppressAnimations ? nil : .snappy(duration: 0.2), value: showPlaylistSidebar)
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
                                    withAnimation(.snappy(duration: 0.2)) {
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
                                    Text("Clear Filters")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
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
                            Text("Close Playlists").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
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
                            Text("Clear Filters").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
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
                    Text("Clear Filter").font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.red)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
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
            withAnimation(.snappy(duration: 0.2)) {
                self.showOverlaySidebar.toggle()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("TogglePlaylists"), object: nil, queue: .main) { [self] _ in
            withAnimation(.snappy(duration: 0.2)) {
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

// MARK: - Summary Bars Helper (outside ContentView)

private func summaryBarsFromList(rows: [AppPluginItem]) -> some View {
    // INSTANT bar graph - direct counting without function call overhead
    var counts = FormatCounts()

    // Ultra-fast counting - single pass, no function calls
    if !rows.isEmpty {
        for row in rows {
            switch row.type {
            case "AU":   counts.au += 1
            case "VST":  counts.vst += 1
            case "VST3": counts.vst3 += 1
            case "AAX":  counts.aax += 1
            case "CLAP": counts.clap += 1
            case "LV2":  counts.lv2 += 1
            default:
                switch row.type.uppercased() {
                case "AU":   counts.au += 1
                case "VST":  counts.vst += 1
                case "VST3": counts.vst3 += 1
                case "AAX":  counts.aax += 1
                case "CLAP": counts.clap += 1
                case "LV2":  counts.lv2 += 1
                default: break
                }
            }
            if row.obsolete { counts.obsolete += 1 }
        }
    }

    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)
    let hasData = !rows.isEmpty

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .id(rows.count) // Force re-render only when count changes
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

private func summaryBars(rows: [ScannerPluginItem]) -> some View {
    // INSTANT bar graph display
    let counts = formatCounts(for: rows)
    let hasData = !rows.isEmpty
    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

// FormatCounts now defined in FormatCounts+Extensions.swift
// Keep local helpers for iOS compatibility
private func formatCountsFromList(for rows: [AppPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in rows {
        counts.increment(for: item.type)
        if item.obsolete { counts.obsolete += 1 }
        if item.missing { counts.missing += 1 }
    }
    return counts
}

private func formatCounts(for rows: [ScannerPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in rows {
        counts.increment(for: item.type)
        if item.obsolete { counts.obsolete += 1 }
    }
    return counts
}

private struct BarRow: View {
    let label: String
    let value: Int
    let fraction: Double
    let color: Color
    var onTap: (() -> Void)? = nil  // Optional click handler
    var isSelected: Bool = false     // Show if this format is filtered
    var onUninstall: (() -> Void)? = nil  // Optional uninstall handler
    var playlistCount: Int? = nil  // Optional playlist-specific count

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let textColor: Color = {
            if isSelected {
                return color
            } else if colorScheme == .light {
                // Light mode: 55% darker text (was 30%, now adding 25% more)
                return Color.black.opacity(0.8)
            } else {
                return .secondary
            }
        }()

        HStack(spacing: 8) {
            Text(label)
                .frame(width: 50, alignment: .leading)
                .font(.caption)
                .foregroundStyle(textColor)
                .fontWeight(isSelected ? .bold : .regular)

            ZStack(alignment: .leading) {
                // Background - fills available space
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: isSelected ? 8 : 6)

                // Foreground - scales with fraction
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: isSelected ? 8 : 6)
                }
                .frame(height: isSelected ? 8 : 6)
            }
            .frame(maxWidth: .infinity)

            // Show playlist count + total if available, otherwise just total
            if let playlistCount = playlistCount {
                HStack(spacing: 4) {
                    Text("\(playlistCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                        .monospacedDigit()
                    Text("/")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(value)")
                        .font(.caption2)
                        .fontWeight(isSelected ? .bold : .semibold)
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                }
                .frame(width: 70, alignment: .trailing)
            } else {
                Text("\(value)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundStyle(textColor)
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 14)
        .opacity(isSelected ? 1.0 : 0.8)  // Match iOS: selected = full opacity, unselected = dimmed
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            onTap?()
        }
        .onHover { isHovering in
            #if os(macOS)
            if onTap != nil {
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
        }
        #if os(macOS)
        .contextMenu {
            if value > 0, let onUninstall = onUninstall {
                Button("Uninstall All \(label) Plugins (\(value))") {
                    onUninstall()
                }
            }
        }
        #endif
    }
}

// Helper for Canvas rounded rect
private struct RoundedRect: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        return Path(roundedRect: self.rect, cornerRadius: cornerRadius)
    }
}

// MARK: - Publisher Dropdown Helper

private struct PublisherDropdown: View {
    let allPublishers: [String]
    @Binding var selectedPublishers: Set<String>
    @State private var showingPopover = false
    
    private var displayText: String {
        if selectedPublishers.isEmpty {
            return "All Publishers"
        } else if selectedPublishers.count == 1 {
            return selectedPublishers.first ?? "All Publishers"
        } else {
            return "\(selectedPublishers.count) Publishers"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Publishers") {
                    selectedPublishers.removeAll()
                }
                
                Divider()
                
                ForEach(allPublishers.filter { !$0.isEmpty }, id: \.self) { publisher in
                    Button(action: {
                        if selectedPublishers.contains(publisher) {
                            selectedPublishers.remove(publisher)
                        } else {
                            selectedPublishers.insert(publisher)
                        }
                    }) {
                        HStack {
                            Text(publisher)
                            Spacer()
                            if selectedPublishers.contains(publisher) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)
            
            if !selectedPublishers.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedPublishers).sorted(), id: \.self) { publisher in
                            HStack {
                                Text(publisher)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedPublishers.remove(publisher)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}

// MARK: - Style Dropdown Helper

private struct StyleDropdown: View {
    let allStyles: [String]
    @Binding var selectedStyles: Set<String>
    @State private var showingPopover = false

    private var displayText: String {
        if selectedStyles.isEmpty {
            return "All Styles"
        } else if selectedStyles.count == 1 {
            return selectedStyles.first ?? "All Styles"
        } else {
            return "\(selectedStyles.count) Styles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Styles") {
                    selectedStyles.removeAll()
                }

                Divider()

                ForEach(allStyles.filter { !$0.isEmpty }, id: \.self) { style in
                    Button(action: {
                        if selectedStyles.contains(style) {
                            selectedStyles.remove(style)
                        } else {
                            selectedStyles.insert(style)
                        }
                    }) {
                        HStack {
                            Text(style)
                            Spacer()
                            if selectedStyles.contains(style) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)

            if !selectedStyles.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedStyles).sorted(), id: \.self) { style in
                            HStack {
                                Text(style)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedStyles.remove(style)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}

// MARK: - Compact Detail View (iOS)
private struct PluginDetailView: View {
    let item: AppPluginItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Publisher", value: item.publisher)
                    LabeledContent("Version", value: item.version)
                    LabeledContent("Type", value: item.type)
                }
                Section(header: Text("Compatibility")) {
                    LabeledContent("Architectures", value: item.architectures)
                    LabeledContent("Requirement", value: item.runtimeRequirement)
                    LabeledContent("Obsolete", value: item.obsolete ? "Yes" : "No")
                }
                Section(header: Text("File")) {
                    LabeledContent("Date", value: item.dateString)
                    LabeledContent("Size", value: item.sizeString)
                    LabeledContent("Path", value: item.path)
                }
            }
            .navigationTitle("Details")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }
}

// MARK: - Rating Selector Component (visual star icons)

struct StarsSelector: View {
    @Binding var selectedStarRatings: Set<Int>

    private func toggle(rating: Int) {
        if selectedStarRatings.contains(rating) {
            selectedStarRatings.remove(rating)
        } else {
            selectedStarRatings.insert(rating)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Display stars from 5 down to 1
            ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                starRow(rating: rating)
            }
        }
    }

    @ViewBuilder private func starRow(rating: Int) -> some View {
        let isSelected = selectedStarRatings.contains(rating)
        Button(action: { toggle(rating: rating) }) {
            HStack(spacing: 3) {
                ForEach(1...rating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 11.2))
                        .foregroundColor(.yellow)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Size Multiplier Environment Key (Vector Zoom)
private struct SizeMultiplierKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var sizeMultiplier: CGFloat {
        get { self[SizeMultiplierKey.self] }
        set { self[SizeMultiplierKey.self] = newValue }
    }
}

// MARK: - Scaled Font Modifier
struct ScaledFont: ViewModifier {
    @Environment(\.sizeMultiplier) var multiplier
    var size: CGFloat
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        content.font(.system(size: size * multiplier, weight: weight))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

// MARK: - Playlist Sidebar View with Keyboard Navigation

#if os(macOS)
private struct PlaylistSidebarView: View {
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

// MARK: - Playlist Row View

#if os(macOS)
private struct PlaylistRowView: View {
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

// MARK: - Custom Button Style for Space Mode
#if os(macOS)
struct SpaceModeButtonStyle: ButtonStyle {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let backgroundColor: Color = {
            if prefs.appearance == .space {
                return Color(red: 25/255, green: 25/255, blue: 25/255)
            } else if colorScheme == .dark {
                return Color(red: 0.2, green: 0.2, blue: 0.2)
            } else {
                // Light mode: match header grey
                return Color(red: 0.82, green: 0.82, blue: 0.84)
            }
        }()

        let textColor: Color = {
            if colorScheme == .light {
                // Light mode: 10% darker text
                return Color.black.opacity(0.9)
            } else {
                return Color.primary
            }
        }()

        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .foregroundColor(textColor)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
#endif

// MARK: - Fast Filter Engine (NEW - SIMPLE & CORRECT)

// FastFilterEngine moved to separate file: FastFilterEngine.swift
