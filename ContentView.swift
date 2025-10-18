import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Disambiguate project types in case of name collisions
typealias AppPluginItem = PluginItem
typealias AppPreferences = Preferences

struct ContentView: View {
    @EnvironmentObject private var scanner: PluginScanner
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var zoomState: ZoomState
    @StateObject private var appState = AppState()
    @State private var searchText: String = ""
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
    @State private var lastBarUpdateCount = 0

    // REACTIVE: Filtered plugins that updates automatically
    @State private var displayedPlugins: [AppPluginItem] = []

    // MARK: Star rating filter state
    @State private var selectedStarRatings: Set<Int> = [] // Filter by 1-5 star ratings

    // MARK: Batch uninstall state
    @State private var showBatchUninstall = false
    @State private var batchUninstallPlugins: [AppPluginItem] = []

    // MARK: Detail panel state
    @State private var showDetailPanel = false
    @State private var detailPanelRefreshTrigger = false  // Toggle to force refresh

    // MARK: DAW Playlist state
    #if os(macOS)
    @State private var showPlaylistSidebar: Bool = false
    @State private var activePlaylistFilters: [DAWPlaylist] = []
    @StateObject private var playlistManager = DAWPlaylistManager.shared
    @State private var showDAWImport = false
    @State private var showDuplicatePlaylistWarning = false
    @State private var pendingImportURL: URL?
    @State private var existingPlaylistToReplace: DAWPlaylist?
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

        var filtered = FastFilterEngine.filter(
            plugins: allPlugins,
            formats: prefs.selectedFormats,
            publishers: prefs.selectedPublishers,
            styles: prefs.selectedStyles,
            searchText: searchText
        )

        // Apply star rating filter if any selected
        if !selectedStarRatings.isEmpty {
            let ratingsManager = RatingsManager.shared
            filtered = filtered.filter { plugin in
                let rating = ratingsManager.getRating(forName: plugin.name)
                return selectedStarRatings.contains(rating)
            }
        }

        // Apply playlist filter if active
        #if os(macOS)
        if !activePlaylistFilters.isEmpty {
            // Create a dictionary mapping (name, format) to track names from ALL selected playlists
            var playlistTrackMap: [String: [String]] = [:]
            for activePlaylist in activePlaylistFilters {
                for entry in activePlaylist.entries {
                    let key = "\(entry.pluginName.lowercased())_\(entry.pluginFormat.rawValue)"
                    if playlistTrackMap[key] == nil {
                        playlistTrackMap[key] = []
                    }
                    if !playlistTrackMap[key]!.contains(entry.trackName) {
                        playlistTrackMap[key]?.append(entry.trackName)
                    }
                }
            }

            // Filter and add track names
            filtered = filtered.compactMap { plugin in
                let key = "\(plugin.name.lowercased())_\(plugin.type)"
                if let trackNames = playlistTrackMap[key] {
                    // Create a new PluginItem with the track names joined
                    var updatedPlugin = plugin
                    updatedPlugin.trackName = trackNames.sorted().joined(separator: ", ")
                    return updatedPlugin
                }
                return nil
            }
        }
        #endif

        displayedPlugins = filtered

        // Restore selection from IDs after filtering
        appState.restoreSelection(from: displayedPlugins)
    }

    private func handleSearchTextChange(_ newValue: String) {
        // Search is completely independent from filters
        updateDisplayedPlugins()
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

    // INSTANT bar graph with INSTANT fake results - shows immediately
    private var instantBarGraphWithResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            BarRow(label: "AU",    value: 25, fraction: 0.4, color: .blue)
            BarRow(label: "VST",   value: 18, fraction: 0.3, color: .green)  
            BarRow(label: "VST3",  value: 12, fraction: 0.2, color: .teal)
            BarRow(label: "AAX",   value: 8,  fraction: 0.15, color: .purple)
            BarRow(label: "CLAP",  value: 3,  fraction: 0.05, color: .orange)
            BarRow(label: "LV2",   value: 1,  fraction: 0.02, color: .gray)
            BarRow(label: "OBSLT", value: 5,  fraction: 0.08, color: .red)
        }
    }
    
    // SPEED: Real bar graph using cached counts - CLICKABLE to filter!
    private var realBarGraph: some View {
        let counts = cachedBarCounts  // Use cached value instead of recalculating!
        let isEmpty = scanner.plugins.isEmpty
        let total = Swift.max(1, counts.au + counts.vst + counts.vst3 + counts.aax + counts.clap + counts.lv2 + counts.obsolete)

        return VStack(alignment: .leading, spacing: 6) {
            if counts.au > 0 {
                BarRow(
                    label: "AU", value: counts.au,
                    fraction: isEmpty ? 0.0 : Double(counts.au) / Double(total),
                    color: .blue,
                    onTap: { toggleFormat(.AU) },
                    isSelected: prefs.selectedFormats.contains(.AU),
                    onUninstall: { batchUninstallFormat("AU") }
                )
            }
            if counts.vst > 0 {
                BarRow(
                    label: "VST", value: counts.vst,
                    fraction: isEmpty ? 0.0 : Double(counts.vst) / Double(total),
                    color: .green,
                    onTap: { toggleFormat(.VST) },
                    isSelected: prefs.selectedFormats.contains(.VST),
                    onUninstall: { batchUninstallFormat("VST") }
                )
            }
            if counts.vst3 > 0 {
                BarRow(
                    label: "VST3", value: counts.vst3,
                    fraction: isEmpty ? 0.0 : Double(counts.vst3) / Double(total),
                    color: .teal,
                    onTap: { toggleFormat(.VST3) },
                    isSelected: prefs.selectedFormats.contains(.VST3),
                    onUninstall: { batchUninstallFormat("VST3") }
                )
            }
            if counts.aax > 0 {
                BarRow(
                    label: "AAX", value: counts.aax,
                    fraction: isEmpty ? 0.0 : Double(counts.aax) / Double(total),
                    color: .purple,
                    onTap: { toggleFormat(.AAX) },
                    isSelected: prefs.selectedFormats.contains(.AAX),
                    onUninstall: { batchUninstallFormat("AAX") }
                )
            }
            if counts.clap > 0 {
                BarRow(
                    label: "CLAP", value: counts.clap,
                    fraction: isEmpty ? 0.0 : Double(counts.clap) / Double(total),
                    color: .orange,
                    onTap: { toggleFormat(.CLAP) },
                    isSelected: prefs.selectedFormats.contains(.CLAP),
                    onUninstall: { batchUninstallFormat("CLAP") }
                )
            }
            if counts.lv2 > 0 {
                BarRow(
                    label: "LV2", value: counts.lv2,
                    fraction: isEmpty ? 0.0 : Double(counts.lv2) / Double(total),
                    color: .gray,
                    onTap: { toggleFormat(.LV2) },
                    isSelected: prefs.selectedFormats.contains(.LV2),
                    onUninstall: { batchUninstallFormat("LV2") }
                )
            }
            if counts.obsolete > 0 {
                BarRow(
                    label: "OBSLT", value: counts.obsolete,
                    fraction: isEmpty ? 0.0 : Double(counts.obsolete) / Double(total),
                    color: .red,
                    onTap: { toggleFormat(.OBSLT) },
                    isSelected: prefs.selectedFormats.contains(.OBSLT),
                    onUninstall: { batchUninstallFormat("OBSLT") }
                )
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(colorScheme == .light ? Color.white.opacity(0.1) : Color.black.opacity(0.18)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(searchFocused ? Color.accentColor : (colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.25)), lineWidth: 1)
                    )
                    .focused($searchFocused)

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
                        let opts = PDFExportOptions(page: prefs.pdfPage, landscape: prefs.pdfLandscape, margin: prefs.pdfMargin, fontSize: prefs.pdfFontSize)
                        ExportManager.exportPDF(rows: displayedPlugins, options: opts)
                    }
                    #endif
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(SpaceModeButtonStyle())
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
            .buttonStyle(SpaceModeButtonStyle())

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(colorScheme == .light ? Color.white.opacity(0.1) : Color.black.opacity(0.18)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(searchFocused ? Color.accentColor : (colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.25)), lineWidth: 1)
                )
                .focused($searchFocused)
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
                    let opts = PDFExportOptions(page: prefs.pdfPage, landscape: prefs.pdfLandscape, margin: prefs.pdfMargin, fontSize: prefs.pdfFontSize)
                    ExportManager.exportPDF(rows: displayedPlugins, options: opts)
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
                Image(systemName: showDetailPanel ? "sidebar.right" : "sidebar.right")
                    .foregroundColor(showDetailPanel ? .accentColor : .primary)
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
            #endif
            .onAppear {
                updateDisplayedPlugins()
                setupNotificationListeners()
            }
            .onChange(of: appState.selected) { _ in handleSelectionChange() }
            .onChange(of: prefs.selectedFormats) { _ in updateDisplayedPlugins() }
            .onChange(of: prefs.selectedPublishers) { _ in updateDisplayedPlugins() }
            .onChange(of: prefs.selectedStyles) { _ in updateDisplayedPlugins() }
            .onChange(of: selectedStarRatings) { _ in updateDisplayedPlugins() }
            .onChange(of: searchText) { newValue in handleSearchTextChange(newValue) }
            .onChange(of: scanner.plugins.count) { _ in updateDisplayedPlugins() }
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
        let panel = NSOpenPanel()
        panel.title = "Select DAW Project"
        panel.message = "Choose a DAW project file (.als for Ableton, .txt for Pro Tools, .bwproject for Bitwig)"
        panel.allowedContentTypes = [
            .init(filenameExtension: "als"),
            .init(filenameExtension: "txt"),
            .init(filenameExtension: "bwproject")
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Check for duplicate playlist name on main thread
            Task { @MainActor in
                let projectName = url.deletingPathExtension().lastPathComponent
                AppLogger.debug("Checking for duplicate playlist: '\(projectName)'")
                AppLogger.debug("Existing playlists: \(self.playlistManager.playlists.map { $0.name }.joined(separator: ", "))")

                if let existingPlaylist = self.playlistManager.playlists.first(where: { $0.name == projectName }) {
                    // Found duplicate - show warning dialog
                    AppLogger.info("Found duplicate playlist '\(projectName)', showing warning")
                    self.pendingImportURL = url
                    self.existingPlaylistToReplace = existingPlaylist
                    self.showDuplicatePlaylistWarning = true
                } else {
                    // No duplicate - proceed with import
                    AppLogger.debug("No duplicate found, proceeding with import")
                    self.performImport(url: url, replacingPlaylist: nil)
                }
            }
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
                }
            }
        }
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
                            StarsSelector(selectedStarRatings: $selectedStarRatings)
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
                        if !prefs.selectedFormats.isEmpty || !selectedStarRatings.isEmpty || !prefs.selectedStyles.isEmpty || !prefs.selectedPublishers.isEmpty {
                            Button {
                                prefs.selectedFormats.removeAll()
                                selectedStarRatings.removeAll()
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
                            // Update displayed plugins for the new playlist
                            updateDisplayedPlugins()
                        }
                    } else if modifiers.contains(.shift) {
                        // Shift: set range selection (already computed by view)
                        activePlaylistFilters = playlists
                        // Clear plugin selection, toggle refresh, and show detail panel
                        appState.selected = []
                        detailPanelRefreshTrigger.toggle()
                        showDetailPanel = true
                        updateDisplayedPlugins()
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
                        updateDisplayedPlugins()
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
            }
        }

        // Always use cached counts for INSTANT display
        let counts = cachedBarCounts
        // Use MAX value instead of total, so largest bar fills 100%
        let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)
        let hasData = currentCount > 0

        return VStack(alignment: .leading, spacing: 6) {
            // Only show bars for plugin types that exist (at least 1 plugin)
            if counts.au > 0 {
                BarRow(
                    label: "AU", value: counts.au,
                    fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0,
                    color: Color.blue,
                    onTap: { toggleFormat(.AU) },
                    isSelected: prefs.selectedFormats.contains(.AU),
                    onUninstall: { batchUninstallFormat("AU") }
                )
            }
            if counts.vst > 0 {
                BarRow(
                    label: "VST", value: counts.vst,
                    fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0,
                    color: Color.green,
                    onTap: { toggleFormat(.VST) },
                    isSelected: prefs.selectedFormats.contains(.VST),
                    onUninstall: { batchUninstallFormat("VST") }
                )
            }
            if counts.vst3 > 0 {
                BarRow(
                    label: "VST3", value: counts.vst3,
                    fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0,
                    color: Color.teal,
                    onTap: { toggleFormat(.VST3) },
                    isSelected: prefs.selectedFormats.contains(.VST3),
                    onUninstall: { batchUninstallFormat("VST3") }
                )
            }
            if counts.aax > 0 {
                BarRow(
                    label: "AAX", value: counts.aax,
                    fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0,
                    color: Color.purple,
                    onTap: { toggleFormat(.AAX) },
                    isSelected: prefs.selectedFormats.contains(.AAX),
                    onUninstall: { batchUninstallFormat("AAX") }
                )
            }
            if counts.clap > 0 {
                BarRow(
                    label: "CLAP", value: counts.clap,
                    fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0,
                    color: Color.orange,
                    onTap: { toggleFormat(.CLAP) },
                    isSelected: prefs.selectedFormats.contains(.CLAP),
                    onUninstall: { batchUninstallFormat("CLAP") }
                )
            }
            if counts.lv2 > 0 {
                BarRow(
                    label: "LV2", value: counts.lv2,
                    fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0,
                    color: Color.gray,
                    onTap: { toggleFormat(.LV2) },
                    isSelected: prefs.selectedFormats.contains(.LV2),
                    onUninstall: { batchUninstallFormat("LV2") }
                )
            }
            if counts.obsolete > 0 {
                BarRow(
                    label: "OBSLT", value: counts.obsolete,
                    fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0,
                    color: Color.red,
                    onTap: { toggleFormat(.OBSLT) },
                    isSelected: prefs.selectedFormats.contains(.OBSLT),
                    onUninstall: { batchUninstallFormat("OBSLT") }
                )
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
                        isVisible: $showDetailPanel
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
                        isVisible: $showDetailPanel
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
        let hasFilters = !prefs.selectedFormats.isEmpty || !selectedStarRatings.isEmpty

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
                        selectedStarRatings.removeAll()
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
        if !prefs.selectedFormats.isEmpty || !selectedStarRatings.isEmpty {
            Button {
                prefs.selectedFormats.removeAll()
                selectedStarRatings.removeAll()
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

    // Ultra-fast counting helper
    private func quickCount(rows: [AppPluginItem]) -> FormatCounts {
        var c = FormatCounts()
        for row in rows {
            switch row.type {
            case "AU":   c.au += 1
            case "VST":  c.vst += 1
            case "VST3": c.vst3 += 1
            case "AAX":  c.aax += 1
            case "CLAP": c.clap += 1
            case "LV2":  c.lv2 += 1
            default:
                switch row.type.uppercased() {
                case "AU":   c.au += 1
                case "VST":  c.vst += 1
                case "VST3": c.vst3 += 1
                case "AAX":  c.aax += 1
                case "CLAP": c.clap += 1
                case "LV2":  c.lv2 += 1
                default: break
                }
            }
            if row.obsolete { c.obsolete += 1 }
        }
        return c
    }

    // MARK: - Menu Bar Notification Handlers

    private func setupNotificationListeners() {
        #if os(macOS)
        // File menu
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ImportDAWProject"), object: nil, queue: .main) { [self] _ in
            self.importDAWProject()
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
            let opts = PDFExportOptions(page: self.prefs.pdfPage, landscape: self.prefs.pdfLandscape, margin: self.prefs.pdfMargin, fontSize: self.prefs.pdfFontSize)
            ExportManager.exportPDF(rows: self.displayedPlugins, options: opts)
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
            self.showDetailPanel = true
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("UninstallSelected"), object: nil, queue: .main) { [self] _ in
            guard !self.appState.selected.isEmpty else { return }
            self.batchUninstallPlugins = self.appState.selected
            self.showBatchUninstall = true
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

private struct FormatCounts: Equatable, Hashable {
    var au: Int = 0
    var vst: Int = 0
    var vst3: Int = 0
    var aax: Int = 0
    var clap: Int = 0
    var lv2: Int = 0
    var obsolete: Int = 0
}

private func formatCountsFromList(for rows: [AppPluginItem]) -> FormatCounts {
    // Same counting logic but for PluginItem instead of ScannerPluginItem
    var c = FormatCounts()

    // Early exit for empty arrays to avoid unnecessary work
    guard !rows.isEmpty else { return c }

    // Pre-allocate expected capacity hint for compiler optimization
    var typeMap: [String: Int] = [:]
    typeMap.reserveCapacity(6)

    // Process in a single pass for better performance
    for row in rows {
        // Use direct string comparison without lowercasing for common cases
        let type = row.type
        switch type {
        case "AU":   c.au += 1
        case "VST":  c.vst += 1
        case "VST3": c.vst3 += 1
        case "AAX":  c.aax += 1
        case "CLAP": c.clap += 1
        case "LV2":  c.lv2 += 1
        default:
            // Fallback to case-insensitive for edge cases
            switch type.lowercased() {
            case "au":   c.au += 1
            case "vst":  c.vst += 1
            case "vst3": c.vst3 += 1
            case "aax":  c.aax += 1
            case "clap": c.clap += 1
            case "lv2":  c.lv2 += 1
            default: break
            }
        }

        // Check obsolete flag efficiently
        if row.obsolete { c.obsolete += 1 }
    }

    return c
}

private func formatCounts(for rows: [ScannerPluginItem]) -> FormatCounts {
    // Use a more efficient counting approach
    var c = FormatCounts()

    // Early exit for empty arrays to avoid unnecessary work
    guard !rows.isEmpty else { return c }

    // Process in a single pass for better performance
    for row in rows {
        // Use direct string comparison without lowercasing for common cases
        let type = row.type
        switch type {
        case "AU":   c.au += 1
        case "VST":  c.vst += 1
        case "VST3": c.vst3 += 1
        case "AAX":  c.aax += 1
        case "CLAP": c.clap += 1
        case "LV2":  c.lv2 += 1
        default:
            // Fallback to case-insensitive for edge cases
            switch type.lowercased() {
            case "au":   c.au += 1
            case "vst":  c.vst += 1
            case "vst3": c.vst3 += 1
            case "aax":  c.aax += 1
            case "clap": c.clap += 1
            case "lv2":  c.lv2 += 1
            default: break
            }
        }

        // Check obsolete flag efficiently
        if row.obsolete { c.obsolete += 1 }
    }

    return c
}

private struct BarRow: View {
    let label: String
    let value: Int
    let fraction: Double
    let color: Color
    var onTap: (() -> Void)? = nil  // Optional click handler
    var isSelected: Bool = false     // Show if this format is filtered
    var onUninstall: (() -> Void)? = nil  // Optional uninstall handler

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

            Text("\(value)")
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .semibold)
                .foregroundStyle(textColor)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
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
    @ObservedObject var playlistManager: DAWPlaylistManager
    @EnvironmentObject private var prefs: AppPreferences
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedIndex: Int = 0
    @State private var lastClickedIndex: Int = 0
    @FocusState private var isFocused: Bool
    @State private var playlistsToDelete: [DAWPlaylist] = []
    @State private var showDeleteConfirmation = false

    private var backgroundColor: Color {
        prefs.appearance == .space ? Color.black : Color(nsColor: .windowBackgroundColor)
    }

    private var secondaryTextColor: Color {
        colorScheme == .light ? Color.black.opacity(0.55) : .secondary
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
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("DAW Playlists")
                .font(.headline)

            Spacer()

            if playlists.count > 0 {
                Text("(\(playlists.count))")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding(16)
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
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
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
            .onAppear {
                // Select the first active playlist if any
                if let firstActive = activePlaylists.first,
                   let index = playlists.firstIndex(where: { $0.id == firstActive.id }) {
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
                    let rangeSelection = Array(playlists[start...end])
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
                onDelete: {
                    // If this playlist is part of a multi-selection, delete all selected
                    // Otherwise, just delete this one
                    if activePlaylists.contains(where: { $0.id == playlist.id }) && activePlaylists.count > 1 {
                        playlistsToDelete = activePlaylists
                    } else {
                        playlistsToDelete = [playlist]
                    }
                    showDeleteConfirmation = true
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
                onSelect([playlists[newIndex]], [])
                lastClickedIndex = newIndex
            }

            // Scroll to keep selection visible (no animation to reduce flicker)
            proxy.scrollTo(newIndex, anchor: .center)
        }
    }
}
#endif

// MARK: - Playlist Row View

#if os(macOS)
private struct PlaylistRowView: View {
    let playlist: DAWPlaylist
    let isActive: Bool
    @State private var isHovered = false
    var onDelete: (() -> Void)? = nil
    @EnvironmentObject private var prefs: AppPreferences

    private var rowBackground: Color {
        if prefs.appearance == .space {
            // Space mode: dark grey background
            if isActive {
                return Color.green.opacity(0.2)
            } else if isHovered {
                return Color.white.opacity(0.15)
            } else {
                return Color.white.opacity(0.1)
            }
        } else {
            // Other modes: existing behavior
            if isActive {
                return Color.green.opacity(0.2)
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
                    Image(systemName: isActive ? "checkmark.circle.fill" : "music.note.list")
                        .foregroundColor(isActive ? .green : .accentColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(playlist.dawType.rawValue)
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
                    .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
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
