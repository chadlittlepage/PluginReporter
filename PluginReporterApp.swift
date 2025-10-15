import SwiftUI
import Sentry
#if os(macOS)
import AppKit
#endif

@main
struct PluginReporterApp: App {
    @StateObject private var scanner = PluginScanner()
    @StateObject private var prefs = Preferences()
    @State private var sync = makeSyncServices(backend: .none) // CloudKit disabled until Apple ID is added to Xcode
    @StateObject private var zoomState = ZoomState()
    @StateObject private var dashboardScheduler = DashboardScheduler.shared

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

    private func applyAppAppearance(_ appearance: Preferences.Appearance) {
        #if os(macOS)
        let targetAppearance: NSAppearance?
        switch appearance {
        case .system:
            targetAppearance = nil
        case .light:
            targetAppearance = NSAppearance(named: .aqua)
        case .dark:
            targetAppearance = NSAppearance(named: .darkAqua)
        case .space:
            targetAppearance = NSAppearance(named: .darkAqua)  // Space mode uses dark appearance
        }

        // Apply to main app
        NSApp.appearance = targetAppearance

        // Force update all windows to ensure they adopt the new appearance
        // Exception: Keep Settings window always in dark mode and floating on top
        for window in NSApp.windows {
            // Keep Settings window in dark mode regardless of chosen appearance
            if window.title.contains("Settings") {
                window.appearance = NSAppearance(named: .darkAqua)
                window.level = .floating  // Always float on top
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            } else {
                window.appearance = targetAppearance
            }
            // Force the window to redraw with new appearance
            window.invalidateShadow()
            window.contentView?.needsDisplay = true
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
                .environmentObject(prefs)
                .environmentObject(zoomState)
                .preferredColorScheme(prefs.appearance.colorScheme)
                .onAppear { applyAppAppearance(prefs.appearance) }
                .onChange(of: prefs.appearance) { newValue in applyAppAppearance(newValue) }
                .onChange(of: prefs.cloudSyncEnabled) { enabled in
                    if enabled { sync.preferences.startSync(prefs: prefs) }
                    else { sync.preferences.stopSync() }
                }
                .onAppear {
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
            CommandGroup(after: .sidebar) {
                Button("Zoom In") { zoomState.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { zoomState.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { zoomState.reset() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView(prefs: prefs)
                .preferredColorScheme(.dark)
                .onAppear {
                    applyAppAppearance(prefs.appearance)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
                            settingsWindow.appearance = NSAppearance(named: .darkAqua)
                            settingsWindow.level = .floating
                            settingsWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                            settingsWindow.styleMask = [.titled, .closable, .resizable]
                        }
                    }
                }
                .onChange(of: prefs.appearance) { newValue in
                    applyAppAppearance(newValue)
                    if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        settingsWindow.appearance = NSAppearance(named: .darkAqua)
                        settingsWindow.level = .floating
                        settingsWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                        settingsWindow.styleMask = [.titled, .closable, .resizable]
                    }
                }
        }
        #endif
    }
}

// MARK: - Zoom State
class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0

    func zoomIn() {
        scale = min(scale + 0.1, 2.0)
        AppLogger.debug("Zoom in: scale = \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    func zoomOut() {
        scale = max(scale - 0.1, 0.5)
        AppLogger.debug("Zoom out: scale = \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    func reset() {
        scale = 1.0
        AppLogger.debug("Zoom reset: scale = \(scale)")
        #if os(macOS)
        applyWindowScale()
        #endif
    }

    #if os(macOS)
    private func applyWindowScale() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let hostingView = window.contentView?.subviews.first(where: { String(describing: type(of: $0)).contains("HostingView") }) else {
                AppLogger.warning("Could not find hosting view for zoom")
                return
            }

            // Apply scaling using bounds transformation (vector-based)
            let currentBounds = hostingView.bounds
            let scaledBounds = CGRect(
                x: 0,
                y: 0,
                width: currentBounds.width / self.scale,
                height: currentBounds.height / self.scale
            )

            hostingView.bounds = scaledBounds
            hostingView.setBoundsSize(scaledBounds.size)
            AppLogger.debug("Applied zoom scale: \(self.scale)")
        }
    }
    #endif
}
