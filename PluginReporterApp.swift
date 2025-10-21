import SwiftUI
import Sentry
import Combine
#if os(macOS)
import AppKit

// MARK: - Extracted Components
// Print helper functions moved to: Helpers/PrintHelper.swift
// PrintablePluginTextView class moved to: Views/PrintablePluginTextView.swift
// AppDelegate class moved to: AppDelegate.swift
// ZoomState class moved to: ZoomState.swift (see bottom of file)

#endif

@main
struct PluginReporterApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var scanner = PluginScanner()
    @StateObject private var prefs = Preferences()
    @State private var sync = makeSyncServices(backend: .none) // CloudKit disabled until Apple ID is added to Xcode
    @StateObject private var zoomState = ZoomState()
    @StateObject private var dashboardScheduler = DashboardScheduler.shared
    @StateObject private var appState = AppState()
    #if os(macOS)
    @StateObject private var playlistManager = DAWPlaylistManager.shared
    #endif

    // Local state for color scheme to prevent publishing during view updates
    @State private var appliedColorScheme: ColorScheme? = nil

    init() {
        // Defer Sentry initialization to avoid blocking startup
        Task.detached(priority: .utility) {
            // Wait a moment for app to fully launch
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Initialize Sentry for crash reporting (only if configured)
            // Read DSN directly from Info.plist to avoid dependency on SentryConfig file
            if let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
               !dsn.isEmpty,
               !dsn.contains("YOUR_") {
                SentrySDK.start { options in
                    options.dsn = dsn
                    options.debug = false
                    options.tracesSampleRate = 1.0
                    options.environment = "production"
                    options.enableAutoSessionTracking = true
                }
                await MainActor.run {
                    AppLogger.info("Sentry crash reporting initialized")
                }
            } else {
                await MainActor.run {
                    AppLogger.info("Sentry not configured - running without crash reporting")
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 1050, minHeight: 700)
                #endif
                .environmentObject(scanner)
                .environmentObject(prefs)
                .preferredColorScheme(appliedColorScheme)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReportBug"))) { _ in
                    openBugReportWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestFeature"))) { _ in
                    openFeatureRequestWindow()
                }
                .onChange(of: prefs.cloudSyncEnabled) { enabled in
                    if enabled { sync.preferences.startSync(prefs: prefs) }
                    else { sync.preferences.stopSync() }
                }
                .onReceive(prefs.$appearance.debounce(for: .milliseconds(100), scheduler: RunLoop.main)) { newAppearance in
                    // Update color scheme asynchronously to prevent publishing error
                    // For System mode, check actual system appearance
                    if newAppearance == .system {
                        let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
                        appliedColorScheme = systemIsDark ? .dark : .light
                    } else {
                        appliedColorScheme = newAppearance.colorScheme
                    }
                }
                .onAppear {
                    // Set initial color scheme
                    if prefs.appearance == .system {
                        let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
                        appliedColorScheme = systemIsDark ? .dark : .light
                    } else {
                        appliedColorScheme = prefs.appearance.colorScheme
                    }

                    #if os(macOS)
                    // Setup appearance observer in AppDelegate (outside SwiftUI)
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.setupAppearanceObserver(preferences: prefs)
                    }
                    #endif

                    if prefs.cloudSyncEnabled { sync.preferences.startSync(prefs: prefs) }

                    // Initialize dashboard reporting
                    Task { @MainActor in
                        let plugins = scanner.plugins.map { PluginItem(
                            name: $0.name,
                            publisher: $0.publisher,
                            version: $0.version,
                            type: $0.type,
                            style: $0.style,
                            architectures: $0.architectures,
                            date: $0.date,
                            sizeBytes: $0.sizeBytes,
                            path: $0.path,
                            runtimeRequirement: $0.runtimeRequirement,
                            obsolete: $0.obsolete
                        )}
                        dashboardScheduler.updatePlugins(plugins)
                    }

                    // Auto-start scheduler if enabled
                    if UserDefaults.standard.bool(forKey: "dashboard_enabled") {
                        dashboardScheduler.start()
                    }
                }
                .onChange(of: scanner.plugins) { newPlugins in
                    // Update dashboard with latest plugin list
                    Task { @MainActor in
                        let plugins = newPlugins.map { PluginItem(
                            name: $0.name,
                            publisher: $0.publisher,
                            version: $0.version,
                            type: $0.type,
                            style: $0.style,
                            architectures: $0.architectures,
                            date: $0.date,
                            sizeBytes: $0.sizeBytes,
                            path: $0.path,
                            runtimeRequirement: $0.runtimeRequirement,
                            obsolete: $0.obsolete
                        )}
                        dashboardScheduler.updatePlugins(plugins)
                    }
                }
        }

        .defaultPosition(.center)
        .commands {
            #if os(macOS)
            // Application menu (Plugin Reporter menu)
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: .command)

                Divider()
            }

            // File menu - replace .newItem to remove New/Open/Close
            CommandGroup(replacing: .newItem) {
                Button("Import DAW Project...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ImportDAWProject"), object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Import JSON...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ImportJSON"), object: nil)
                }
                .keyboardShortcut("j", modifiers: .command)

                Divider()

                Button("Export CSV...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportCSV"), object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export JSON...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportJSON"), object: nil)
                }

                Button("Export HTML...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportHTML"), object: nil)
                }

                Button("Export PDF...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ExportPDF"), object: nil)
                }
                // No keyboard shortcut - conflicts with Page Setup (Cmd+Shift+P)
            }

            // Enable standard Print menu items (Page Setup and Print)
            // These will show the custom Page Setup dialog with preview
            CommandGroup(replacing: .printItem) {
                Button("Page Setup...") {
                    // CRITICAL: Use displayedPlugins from ContentView to match what will actually be exported
                    // This ensures Page Setup preview shows the same data as Quick Export and Print
                    // Note: We can't access ContentView's displayedPlugins from here, so we post a notification
                    NotificationCenter.default.post(name: NSNotification.Name("ShowPageSetup"), object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Print...") {
                    // CRITICAL: Use displayedPlugins from ContentView to match current table view
                    NotificationCenter.default.post(name: NSNotification.Name("PrintPlugins"), object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            // Edit menu
            CommandGroup(replacing: .undoRedo) {
                Button(playlistManager.undoManager.undoActionName.isEmpty ? "Undo" : "Undo \(playlistManager.undoManager.undoActionName)") {
                    playlistManager.performUndo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!playlistManager.canUndo)

                Button(playlistManager.undoManager.redoActionName.isEmpty ? "Redo" : "Redo \(playlistManager.undoManager.redoActionName)") {
                    playlistManager.performRedo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!playlistManager.canRedo)
            }

            // View menu
            CommandGroup(after: .sidebar) {
                Button("Show/Hide Filters") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleFilters"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Button("Show/Hide DAW Playlists") {
                    NotificationCenter.default.post(name: NSNotification.Name("TogglePlaylists"), object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Show/Hide Metadata Panel") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleMetadata"), object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Divider()

                // Appearance submenu
                Menu("Appearance") {
                    Button("System") {
                        Task { @MainActor in
                            prefs.appearance = .system
                        }
                    }
                    .keyboardShortcut("1", modifiers: [.command, .option])

                    Button("Light") {
                        Task { @MainActor in
                            prefs.appearance = .light
                        }
                    }
                    .keyboardShortcut("2", modifiers: [.command, .option])

                    Button("Dark") {
                        Task { @MainActor in
                            prefs.appearance = .dark
                        }
                    }
                    .keyboardShortcut("3", modifiers: [.command, .option])

                    Button("Space") {
                        Task { @MainActor in
                            prefs.appearance = .space
                        }
                    }
                    .keyboardShortcut("4", modifiers: [.command, .option])
                }

                // Font Size submenu
                Menu("Font Size") {
                    Button("Decrease") {
                        prefs.uiFontSizeOffset = max(prefs.uiFontSizeOffset - 1, -5)
                    }
                    .keyboardShortcut("-", modifiers: .command)

                    Button("Increase") {
                        prefs.uiFontSizeOffset = min(prefs.uiFontSizeOffset + 1, 5)
                    }
                    .keyboardShortcut("=", modifiers: .command)

                    Button("Reset") {
                        prefs.uiFontSizeOffset = 0
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }
            }

            // Plugins menu (new)
            CommandMenu("Plugins") {
                Button("Scan for Plugins") {
                    NotificationCenter.default.post(name: NSNotification.Name("ScanPlugins"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Show in Finder") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowInFinder"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Check for Update") {
                    NotificationCenter.default.post(name: NSNotification.Name("CheckUpdate"), object: nil)
                }

                Divider()

                Button("Edit Metadata...") {
                    NotificationCenter.default.post(name: NSNotification.Name("EditMetadata"), object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("License...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowLicense"), object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button("Uninstall Selected...") {
                    NotificationCenter.default.post(name: NSNotification.Name("UninstallSelected"), object: nil)
                }
                .keyboardShortcut(KeyEquivalent.delete, modifiers: .command)

                Divider()

                // Filters submenu (plugin filters)
                Menu("Filters") {
                    // Type filters
                    Menu("Type") {
                        Button(prefs.selectedFormats.contains(.AU) ? "AU          ✓" : "AU") {
                            if prefs.selectedFormats.contains(.AU) {
                                prefs.selectedFormats.remove(.AU)
                            } else {
                                prefs.selectedFormats.insert(.AU)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.VST) ? "VST          ✓" : "VST") {
                            if prefs.selectedFormats.contains(.VST) {
                                prefs.selectedFormats.remove(.VST)
                            } else {
                                prefs.selectedFormats.insert(.VST)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.VST3) ? "VST3          ✓" : "VST3") {
                            if prefs.selectedFormats.contains(.VST3) {
                                prefs.selectedFormats.remove(.VST3)
                            } else {
                                prefs.selectedFormats.insert(.VST3)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.AAX) ? "AAX          ✓" : "AAX") {
                            if prefs.selectedFormats.contains(.AAX) {
                                prefs.selectedFormats.remove(.AAX)
                            } else {
                                prefs.selectedFormats.insert(.AAX)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.CLAP) ? "CLAP          ✓" : "CLAP") {
                            if prefs.selectedFormats.contains(.CLAP) {
                                prefs.selectedFormats.remove(.CLAP)
                            } else {
                                prefs.selectedFormats.insert(.CLAP)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.LV2) ? "LV2          ✓" : "LV2") {
                            if prefs.selectedFormats.contains(.LV2) {
                                prefs.selectedFormats.remove(.LV2)
                            } else {
                                prefs.selectedFormats.insert(.LV2)
                            }
                        }

                        Button(prefs.selectedFormats.contains(.OBSLT) ? "OBSOLETE          ✓" : "OBSOLETE") {
                            if prefs.selectedFormats.contains(.OBSLT) {
                                prefs.selectedFormats.remove(.OBSLT)
                            } else {
                                prefs.selectedFormats.insert(.OBSLT)
                            }
                        }
                    }

                    // Rating filters - submenu for star ratings
                    Menu("Rating") {
                        Button(prefs.selectedStarRatings.contains(5) ? "★★★★★          ✓" : "★★★★★") {
                            if prefs.selectedStarRatings.contains(5) {
                                prefs.selectedStarRatings.remove(5)
                            } else {
                                prefs.selectedStarRatings.insert(5)
                            }
                        }

                        Button(prefs.selectedStarRatings.contains(4) ? "★★★★          ✓" : "★★★★") {
                            if prefs.selectedStarRatings.contains(4) {
                                prefs.selectedStarRatings.remove(4)
                            } else {
                                prefs.selectedStarRatings.insert(4)
                            }
                        }

                        Button(prefs.selectedStarRatings.contains(3) ? "★★★          ✓" : "★★★") {
                            if prefs.selectedStarRatings.contains(3) {
                                prefs.selectedStarRatings.remove(3)
                            } else {
                                prefs.selectedStarRatings.insert(3)
                            }
                        }

                        Button(prefs.selectedStarRatings.contains(2) ? "★★          ✓" : "★★") {
                            if prefs.selectedStarRatings.contains(2) {
                                prefs.selectedStarRatings.remove(2)
                            } else {
                                prefs.selectedStarRatings.insert(2)
                            }
                        }

                        Button(prefs.selectedStarRatings.contains(1) ? "★          ✓" : "★") {
                            if prefs.selectedStarRatings.contains(1) {
                                prefs.selectedStarRatings.remove(1)
                            } else {
                                prefs.selectedStarRatings.insert(1)
                            }
                        }
                    }

                    // Styles - submenu
                    Menu("Styles") {
                        let allStyles = Array(Set(scanner.plugins.map(\.style).filter { !$0.isEmpty })).sorted()
                        if allStyles.isEmpty {
                            Text("No styles available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(allStyles, id: \.self) { style in
                                Button(prefs.selectedStyles.contains(style) ? "\(style)          ✓" : style) {
                                    if prefs.selectedStyles.contains(style) {
                                        prefs.selectedStyles.remove(style)
                                    } else {
                                        prefs.selectedStyles.insert(style)
                                    }
                                }
                            }
                        }
                    }

                    // Publishers - submenu
                    Menu("Publishers") {
                        let allPublishers = Array(Set(scanner.plugins.map(\.publisher).filter { !$0.isEmpty })).sorted()
                        if allPublishers.isEmpty {
                            Text("No publishers available")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(allPublishers, id: \.self) { publisher in
                                Button(prefs.selectedPublishers.contains(publisher) ? "\(publisher)          ✓" : publisher) {
                                    if prefs.selectedPublishers.contains(publisher) {
                                        prefs.selectedPublishers.remove(publisher)
                                    } else {
                                        prefs.selectedPublishers.insert(publisher)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button(action: {
                            prefs.selectedFormats.removeAll()
                            prefs.selectedStarRatings.removeAll()
                            prefs.selectedStyles.removeAll()
                            prefs.selectedPublishers.removeAll()
                        }) {
                            Text("Clear All")
                        }
                        .keyboardShortcut(KeyEquivalent("x"), modifiers: [])
                        .foregroundStyle(.white)
                    }
                }
            }

            // Playlists menu
            CommandMenu("Playlists") {
                Button("New Playlist...") {
                    NotificationCenter.default.post(name: NSNotification.Name("NewPlaylist"), object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                // Filters submenu
                Menu("Filters") {
                    Section(header: Text("Sort By")) {
                        if playlistManager.playlistSortOption == .dateImported {
                            Button("Date Imported") {
                                playlistManager.playlistSortOption = .dateImported
                            }
                            .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                        } else {
                            Button("Date Imported") {
                                playlistManager.playlistSortOption = .dateImported
                            }
                        }

                        if playlistManager.playlistSortOption == .name {
                            Button("Name") {
                                playlistManager.playlistSortOption = .name
                            }
                            .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                        } else {
                            Button("Name") {
                                playlistManager.playlistSortOption = .name
                            }
                        }
                    }

                    Section(header: Text("Filter By")) {
                        if playlistManager.showOnlyMissingPlaylists {
                            Button("Missing") {
                                playlistManager.showOnlyMissingPlaylists.toggle()
                            }
                            .keyboardShortcut(KeyEquivalent("✓"), modifiers: [])
                        } else {
                            Button("Missing") {
                                playlistManager.showOnlyMissingPlaylists.toggle()
                            }
                        }

                        Menu("DAW Type") {
                            ForEach(DAWType.allCases, id: \.self) { dawType in
                                Button(playlistManager.selectedDAWTypes.contains(dawType) ? "\(dawType.rawValue)          ✓" : dawType.rawValue) {
                                    if playlistManager.selectedDAWTypes.contains(dawType) {
                                        playlistManager.selectedDAWTypes.remove(dawType)
                                    } else {
                                        playlistManager.selectedDAWTypes.insert(dawType)
                                    }
                                }
                            }
                        }

                        Menu("Rating") {
                            ForEach(1...5, id: \.self) { rating in
                                Button(playlistManager.selectedPlaylistStarRatings.contains(rating) ? "\(String(repeating: "★", count: rating))          ✓" : String(repeating: "★", count: rating)) {
                                    if playlistManager.selectedPlaylistStarRatings.contains(rating) {
                                        playlistManager.selectedPlaylistStarRatings.remove(rating)
                                    } else {
                                        playlistManager.selectedPlaylistStarRatings.insert(rating)
                                    }
                                }
                            }
                        }
                    }

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
                }
            }

            // Help menu
            CommandGroup(after: .help) {
                Button("Report a Bug...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ReportBug"), object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Request a Feature...") {
                    NotificationCenter.default.post(name: NSNotification.Name("RequestFeature"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }

            // Remove Close Window menu item by replacing .windowArrangement
            CommandGroup(replacing: .windowArrangement) {
                // Empty - removes Close, Minimize, Zoom menu items
            }
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView(prefs: prefs)
                .environmentObject(scanner)
                .preferredColorScheme(.dark)
        }
        #endif
    }

    // MARK: - Helper Functions

    private func openBugReportWindow() {
        #if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 950),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Report a Bug"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        let hostingView = NSHostingView(rootView: BugReportView())
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        #endif
    }

    private func openFeatureRequestWindow() {
        #if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Request a Feature"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        let hostingView = NSHostingView(rootView: FeatureRequestView())
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        #endif
    }

    private func checkForUpdates() {
        #if os(macOS)
        // Open the GitHub releases page
        if let url = URL(string: "https://github.com/yourusername/PluginReporter/releases") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - Zoom State
// ZoomState class moved to: ZoomState.swift

