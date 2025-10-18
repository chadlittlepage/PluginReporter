import SwiftUI
import Sentry
import Combine
#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceCancellable: AnyCancellable?

    func setupAppearanceObserver(preferences: Preferences) {
        // Observe appearance changes with debounce to avoid triggering during view updates
        appearanceCancellable = preferences.$appearance
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] newAppearance in
                self?.applyAppearance(newAppearance)
            }

        // Apply initial appearance
        applyAppearance(preferences.appearance)
    }

    private func applyAppearance(_ appearance: Preferences.Appearance) {
        let targetAppearance: NSAppearance?
        switch appearance {
        case .system:
            // For System mode: explicitly check what the system appearance is
            let systemIsDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            targetAppearance = systemIsDark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            AppLogger.debug("System mode: detected system is \(systemIsDark ? "Dark" : "Light")")
        case .light:
            targetAppearance = NSAppearance(named: .aqua)
            AppLogger.debug("Light mode: applying .aqua")
        case .dark:
            targetAppearance = NSAppearance(named: .darkAqua)
            AppLogger.debug("Dark mode: applying .darkAqua")
        case .space:
            // Use Dark mode's .darkAqua appearance to get pure black titlebar
            targetAppearance = NSAppearance(named: .darkAqua)
            AppLogger.debug("Space mode: applying .darkAqua (Pure black titlebar)")
        }

        NSApp.appearance = targetAppearance

        // Apply to all windows
        for window in NSApp.windows {
            if window.title.contains("Settings") {
                // Settings window always stays dark (dark gray titlebar)
                window.appearance = NSAppearance(named: .darkAqua)
            } else {
                // Main window follows the selected appearance
                window.appearance = targetAppearance
            }
        }

        // Configure Space mode titlebar - match Settings window appearance exactly
        if appearance == .space {
            for window in NSApp.windows where !window.title.contains("Settings") {
                // Use exact same settings as Settings window
                window.titlebarSeparatorStyle = .none
            }
        } else {
            // Reset titlebar for non-Space modes
            for window in NSApp.windows where !window.title.contains("Settings") {
                window.titlebarSeparatorStyle = .automatic
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window tabbing entirely
        NSWindow.allowsAutomaticWindowTabbing = false

        // Also set tabbingMode for all windows
        Task { @MainActor in
            for window in NSApp.windows {
                window.tabbingMode = .disallowed
            }
        }

        // Try to remove menu items after a delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            self.removeTabMenuItems()
        }

        // Configure main window for black titlebar
        Task { @MainActor in
            self.configureMainWindowTitlebar()
        }
    }

    private func configureMainWindowTitlebar() {
        // Get the user's preference
        let prefs = Preferences()

        // Find main window (not Settings)
        guard let mainWindow = NSApp.windows.first(where: { !$0.title.contains("Settings") && $0.isVisible }) else { return }

        // Apply PURE BLACK titlebar for Space mode
        if prefs.appearance == .space {
            mainWindow.appearance = NSAppearance(named: .darkAqua)
            mainWindow.titlebarSeparatorStyle = .none
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure windows don't allow tabbing
        for window in NSApp.windows {
            window.tabbingMode = .disallowed
        }
        removeTabMenuItems()
    }

    private func removeTabMenuItems() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Find View menu and remove ALL tab-related items
        for menuItem in mainMenu.items {
            if menuItem.title == "View", let submenu = menuItem.submenu {
                // Look through ALL items (including dynamically added ones)
                let allItems = submenu.items
                for item in allItems {
                    if item.title.contains("Tab") || item.action == #selector(NSWindow.toggleTabBar(_:)) || item.action == #selector(NSWindow.toggleTabOverview(_:)) {
                        item.isHidden = true
                        item.isEnabled = false
                    }
                }
                break
            }
        }
    }
}
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
            AppLogger.info("Sentry crash reporting initialized")
        } else {
            AppLogger.info("Sentry not configured - running without crash reporting")
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

            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Import DAW Project...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ImportDAWProject"), object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

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
                .keyboardShortcut("p", modifiers: [.command, .shift])
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

                Divider()

                Button("Uninstall Selected...") {
                    NotificationCenter.default.post(name: NSNotification.Name("UninstallSelected"), object: nil)
                }
                .keyboardShortcut(KeyEquivalent.delete, modifiers: .command)
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
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView(prefs: prefs)
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
@MainActor
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0

    func zoomIn() {
        scale = min(scale + 0.1, 2.0)
        AppLogger.debug("Zoom in: scale = \(scale)")
    }

    func zoomOut() {
        scale = max(scale - 0.1, 0.5)
        AppLogger.debug("Zoom out: scale = \(scale)")
    }

    func reset() {
        scale = 1.0
        AppLogger.debug("Zoom reset: scale = \(scale)")
    }
}
