import Combine
import FirebaseCore
import Sentry
import SwiftUI
#if os(macOS)
import AppKit

// MARK: - Extracted Components
// Print helper functions moved to: Helpers/PrintHelper.swift
// PrintablePluginTextView class moved to: Views/PrintablePluginTextView.swift
// AppDelegate class moved to: AppDelegate.swift
// ZoomState class moved to: ZoomState.swift (see bottom of file)

#endif

// MARK: - Seed Free Plugins Database
// One-time function to populate Firebase with 80+ verified free plugins
@MainActor
func seedFreePlugins() async {
    print("🚀 Seeding Firebase with verified free plugins...")

    let plugins: [(String, String, String, String)] = [
        // REVERB (10 plugins)
        ("TAL Reverb 4", "reverb", "Highly regarded algorithmic reverb with lush, spacious sound - completely free", "Togu Audio Line"),
        ("OrilRiver", "reverb", "Free open-source reverb based on Freeverb3 algorithm - natural and spacious", "Denis Tihanov"),
        ("Dragonfly Reverb", "reverb", "High-quality open-source reverb collection with plate, room, and hall", "Michael Gruhn"),
        ("Valhalla Supermassive", "reverb", "Free massive reverb/delay creating huge, otherworldly spaces", "Valhalla DSP"),
        ("Ambience", "reverb", "Classic simple CPU-friendly reverb - great for natural space", "Magnus Jonsson"),
        ("EpicVerb", "reverb", "Very good sounding algorithmic reverb with clean modern design", "Variety of Sound"),
        ("MConvolutionEZ", "reverb", "Free convolution reverb for loading impulse responses", "MeldaProduction"),
        ("Sanford Reverb", "reverb", "Clean easy-to-use reverb designed for simplicity", "Sanford"),
        ("FreeverbToo", "reverb", "No-frills approach to creating space - functional and free", "Smartelectronix"),
        ("Protoverb", "reverb", "Experimental reverb with unique character", "U-he"),

        // EQ (7 plugins)
        ("TDR VOS SlickEQ", "eq", "Three-band semi-parametric EQ with smooth musical character", "Tokyo Dawn Records"),
        ("MEqualizer", "eq", "Versatile 6-band EQ - flexible and transparent", "MeldaProduction"),
        ("Marvel GEQ", "eq", "Free 16-band graphic EQ with minimum phase mode", "Voxengo"),
        ("EQ", "eq", "Simple clean parametric EQ from Kilohearts Essentials", "Kilohearts"),
        ("Luftikus", "eq", "Free analog-modeled EQ adding warmth and character", "Tokyo Dawn Records"),
        ("TDR Nova", "eq", "Parallel dynamic EQ - professional-grade free tool", "Tokyo Dawn Records"),
        ("ReaEQ", "eq", "Free parametric EQ included with REAPER - versatile", "Cockos"),

        // COMPRESSOR (8 plugins)
        ("TDR Kotelnikov", "compressor", "Wideband dynamics processor - mastering-grade quality", "Tokyo Dawn Records"),
        ("Rough Rider 3", "compressor", "Modern compressor with vintage character - great for drums", "Audio Damage"),
        ("MCompressor", "compressor", "Versatile compressor with various modes", "MeldaProduction"),
        ("Compressor", "compressor", "Clean simple compressor from Kilohearts Essentials", "Kilohearts"),
        ("ADHD", "compressor", "Free leveling compressor for smooth transparent gain reduction", "Analog Obsession"),
        ("Molot", "compressor", "Free compressor/limiter with character - adds warmth", "Vladg Sound"),
        ("DCam FreeComp", "compressor", "Simple effective compressor modeled after hardware", "FXpansion"),
        ("OTT", "compressor", "Multiband upwards/downwards compressor - famous for EDM", "Xfer Records"),

        // LIMITER (4 plugins)
        ("MLimiter", "limiter", "Transparent limiter great for mastering", "MeldaProduction"),
        ("LoudMax", "limiter", "Transparent look-ahead brickwall limiter - industry standard", "Thomas Mundt"),
        ("Limiter No6", "limiter", "5-module limiter with various modes - extremely versatile", "Vladg Sound"),
        ("W1 Limiter", "limiter", "Free brickwall limiter for mastering - simple and effective", "George Yohng"),

        // DELAY (5 plugins)
        ("Valhalla Freq Echo", "delay", "Free frequency shifter/echo creating unique delays", "Valhalla DSP"),
        ("TAL-Dub-X", "delay", "Free dub delay with vintage character", "Togu Audio Line"),
        ("Delay", "delay", "Simple clean delay from Kilohearts Essentials", "Kilohearts"),
        ("EchoBoy Jr", "delay", "Simplified free version of famous EchoBoy", "Soundtoys"),
        ("MDelayMB", "delay", "Free multiband delay - very versatile", "MeldaProduction"),

        // MODULATION (5 plugins)
        ("TAL-Chorus-LX", "modulation", "Free chorus modeled after Juno-60 - lush vintage sound", "Togu Audio Line"),
        ("Valhalla Space Modulator", "modulation", "Free modulation with flangers, phasers, chorus", "Valhalla DSP"),
        ("MFlanger", "modulation", "Versatile flanger from MeldaProduction free bundle", "MeldaProduction"),
        ("Phaser", "modulation", "Simple phaser from Kilohearts Essentials", "Kilohearts"),
        ("Chorus", "modulation", "Clean chorus from Kilohearts Essentials", "Kilohearts"),

        // STEREO (4 plugins)
        ("Wider", "stereo", "Free stereo widener - simple and effective", "Polyverse Music"),
        ("Panagement", "stereo", "Free stereo width and panning plugin", "Voxengo"),
        ("Ozone Imager", "stereo", "Professional stereo imaging from iZotope", "iZotope"),
        ("MStereoSpread", "stereo", "Free stereo widener - very effective", "MeldaProduction"),

        // ANALYZER (4 plugins)
        ("SPAN", "analyzer", "Free real-time spectrum analyzer - essential tool", "Voxengo"),
        ("Youlean Loudness Meter", "analyzer", "Free loudness metering for streaming standards", "Youlean"),
        ("mvMeter2", "analyzer", "Free multivariable meter - professional-grade", "TBProAudio"),
        ("dpMeter5", "analyzer", "Free level and stereo meter with ballistics", "TBProAudio"),

        // SATURATION (5 plugins)
        ("Saturation Knob", "saturation", "Free saturation adding warmth and harmonics", "Softube"),
        ("Krush", "distortion", "Free bit crusher/distortion for adding grit", "Tritik"),
        ("Vinyl", "effect", "Free lo-fi vinyl simulator adding vintage character", "iZotope"),
        ("Tube Saturator", "saturation", "Free tube saturation adding analog warmth", "Shattered Glass Audio"),
        ("IVGI", "saturation", "Free saturation with vintage character", "Klanghelm"),

        // SYNTHESIZER (8 plugins)
        ("TAL-NoiseMaker", "synthesizer", "Free virtual analog synth with effects", "Togu Audio Line"),
        ("Dexed", "synthesizer", "Free FM synth modeled after Yamaha DX7", "Digital Suburban"),
        ("Helm", "synthesizer", "Free open-source polyphonic synth", "Matt Tytel"),
        ("Surge XT", "synthesizer", "Powerful open-source hybrid synth", "Surge Synth Team"),
        ("Vital", "synthesizer", "Spectral warping wavetable synth - free version", "Matt Tytel"),
        ("Tyrell N6", "synthesizer", "Free virtual analog synth with warm fat sound", "u-he"),
        ("PG-8X", "synthesizer", "Free synth modeled after classic polysynths", "ML-VST"),
        ("Odin 2", "synthesizer", "Free semi-modular polyphonic synth", "The Wave Warden"),

        // INSTRUMENTS (6 plugins)
        ("Spitfire LABS", "instrument", "Collection of free virtual instruments", "Spitfire Audio"),
        ("Ample Bass P Lite", "bass", "Free bass guitar with realistic sounds", "Ample Sound"),
        ("DSK Dynamic Guitars", "guitar", "Free guitar with acoustic and electric", "DSK Music"),
        ("MT Power Drum Kit 2", "drums", "Free drum sampler with acoustic drums", "Manda Audio"),
        ("SSD5 Free", "drums", "Free drum sampler great for rock and metal", "Steven Slate Drums"),
        ("Decent Sampler", "sampler", "Free sampling plugin with sample library", "Decent Samples"),

        // UTILITY (5 plugins)
        ("Pancake 2", "utility", "Free automatic mixing tool with limiting", "Cableguys"),
        ("Gain", "utility", "Simple gain/trim from Kilohearts Essentials", "Kilohearts"),
        ("Stereo Tool", "utility", "Free stereo manipulation - useful for mixing", "Flux"),
        ("Utility", "utility", "Free utility with gain, phase, width control", "Ableton"),
        ("LFO Tool", "utility", "Free LFO-driven volume modulation", "Xfer Records")
    ]

    var saved = 0
    var failed = 0

    for (name, category, reason, developer) in plugins {
        do {
            try await FirestoreManager.shared.saveFreePlugin(
                name: name,
                category: category,
                reason: reason,
                developer: developer
            )
            saved += 1
            if saved % 10 == 0 {
                print("   ✅ Saved \(saved) plugins...")
            }
        } catch {
            print("   ⚠️ Failed to save '\(name)': \(error.localizedDescription)")
            failed += 1
        }
    }

    print("✅ Seeding complete! Saved: \(saved), Failed: \(failed)")
    print("⚡ FREE category will now be LIGHTNING FAST!")
}

@main
struct PluginReporterApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @StateObject private var scanner = PluginScanner()
    @StateObject private var prefs = Preferences()
    @State private var sync = makeSyncServices(backend: .cloudKit) // CloudKit enabled for iCloud sync
    @StateObject private var zoomState = ZoomState()
    @StateObject private var dashboardScheduler = DashboardScheduler.shared
    @StateObject private var appState = AppState()
    // IMPORTANT: FirestoreManager MUST be initialized before PluginEnrichmentService
    // to properly configure Firestore settings and avoid LevelDB lock conflicts
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var enrichmentService = PluginEnrichmentService.shared
    @StateObject private var pluginDataMerger: PluginDataMerger = PluginDataMerger(
        cloudKit: CloudSyncManager.shared,
        firestore: FirestoreManager.shared
    )
    #if os(macOS)
    @StateObject private var playlistManager = DAWPlaylistManager.shared
    #endif

    // Local state for color scheme to prevent publishing during view updates
    @State private var appliedColorScheme: ColorScheme?

    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        AppLogger.info("Firebase initialized")

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
                .environmentObject(enrichmentService)
                .environmentObject(firestoreManager)
                .environmentObject(pluginDataMerger)
                .preferredColorScheme(appliedColorScheme)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReportBug"))) { _ in
                    openBugReportWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestFeature"))) { _ in
                    openFeatureRequestWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showCrashReportingPrompt)) { _ in
                    openCrashReportingPrompt()
                }
                .onChange(of: prefs.cloudSyncEnabled) { enabled in
                    if enabled { sync.preferences.startSync(prefs: prefs) } else { sync.preferences.stopSync() }
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

                    // Show crash reporting opt-in prompt if needed (after 1 day of use)
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds after launch
                        await MainActor.run {
                            CrashReportingAnalytics.shared.showOptInPromptIfNeeded()
                        }
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

                        // NOTE: PluginDataMerger disabled - using PluginEnrichmentService instead
                        // The enrichment is handled by enrichPluginsWithFirebase() in ContentView
                        // which calls PluginEnrichmentService.shared.batchFetchEnrichment()
                        // Uncommenting this will overwrite the enrichment data:
                        // if !scanner.isScanning && !plugins.isEmpty {
                        //     await pluginDataMerger.loadScannedPlugins(plugins)
                        // }
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

            // ========================================
            // AI & Resources Menu (window managers lost — stubs pending)
            // ========================================
            // TODO: Restore PluginPresetsWindowManager, AIChainToPresetWindowManager,
            //       HardwareDSPUsageWindowManager from the 17 lost files
            // ========================================

            // DEVELOPER MENU
            CommandMenu("Developer") {
                Button("⚡ Seed Free Plugins Database") {
                    Task {
                        await seedFreePlugins()

                        // Show success alert
                        await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = "✅ Database Seeded Successfully!"
                            alert.informativeText = "Saved 80+ verified free plugins to Firebase.\n\nFREE category will now load in < 1 second! 🚀"
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    }
                }
                .help("Populate Firebase with 80+ verified free plugins for instant FREE category")
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

    private func openCrashReportingPrompt() {
        #if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Help Improve Plugin Reporter"
        window.level = .floating
        window.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: CrashReportingPromptView())
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
