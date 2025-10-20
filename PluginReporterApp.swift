import SwiftUI
import Sentry
import Combine
#if os(macOS)
import AppKit

// MARK: - Print Helper

/// Create a printable NSView with the plugin table
@MainActor
func createPrintablePluginView(plugins: [PluginItem], preferences: Preferences) -> NSView {
    // NSPrintInfo should already be configured by the caller
    let printInfo = NSPrintInfo.shared

    let pageWidth = printInfo.paperSize.width
    let pageHeight = printInfo.paperSize.height

    // Use margins from NSPrintInfo (which were set from preferences)
    let leftMargin = printInfo.leftMargin
    let rightMargin = printInfo.rightMargin
    let topMargin = printInfo.topMargin
    let bottomMargin = printInfo.bottomMargin

    // Calculate content area
    let contentWidth = pageWidth - leftMargin - rightMargin

    // Create text container
    let fontSize = preferences.pdfFontSize
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

    // Build text content with header
    let reportTitle = "Plugin Report - \(plugins.count) plugins"
    let separator = String(repeating: "=", count: min(80, Int(contentWidth / (fontSize * 0.6))))

    let header = """
    \(reportTitle)
    \(separator)

    """

    let tableText = buildPrintTableText(plugins: plugins, width: contentWidth, fontSize: fontSize, preferences: preferences)
    let fullText = header + tableText

    // Create attributed string
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.alignment = .left

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraphStyle
    ]

    let attributedString = NSAttributedString(string: fullText, attributes: attributes)

    // Create text storage and layout manager
    let textStorage = NSTextStorage(attributedString: attributedString)
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)

    // Create text container
    let containerSize = CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
    let textContainer = NSTextContainer(size: containerSize)
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)

    // Force layout
    layoutManager.glyphRange(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)

    // Create custom view
    let view = PrintablePluginTextView(frame: NSRect(origin: .zero, size: CGSize(width: pageWidth, height: max(pageHeight, usedRect.height + topMargin + bottomMargin))))
    view.textStorage = textStorage
    view.layoutManager = layoutManager
    view.leftMargin = leftMargin
    view.topMargin = topMargin
    view.rightMargin = rightMargin
    view.bottomMargin = bottomMargin

    return view
}

/// Build formatted table text for printing (matches ExportManager implementation)
@MainActor
func buildPrintTableText(plugins: [PluginItem], width: CGFloat, fontSize: CGFloat, preferences: Preferences) -> String {
    // Calculate character capacity using ACTUAL font metrics (same as PageSetupView)
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    let charWidth = font.maximumAdvancement.width
    let capacity = Int(width / charWidth)

    print("📄 Export: width=\(width), fontSize=\(fontSize), ACTUAL charWidth=\(charWidth), capacity=\(capacity)")

    // Get managers for rating and notes
    let ratingsManager = RatingsManager.shared
    let notesManager = NotesManager.shared

    // Define column information structure
    struct ColumnInfo {
        let header: String
        let maxDesired: Int
        let minimum: Int
        let extractor: (PluginItem, RatingsManager, NotesManager) -> String
    }

    // Build columns array based on preferences
    var columns: [ColumnInfo] = []

    if preferences.pdfShowRating {
        columns.append(ColumnInfo(header: "Rating", maxDesired: 6, minimum: 4) { item, ratings, _ in
            let rating = ratings.getRating(for: item.path)
            return rating > 0 ? String(repeating: "★", count: rating) : ""
        })
    }
    if preferences.pdfShowName {
        columns.append(ColumnInfo(header: "Name", maxDesired: 35, minimum: 8) { item, _, _ in item.name })
    }
    if preferences.pdfShowPublisher {
        columns.append(ColumnInfo(header: "Publisher", maxDesired: 20, minimum: 6) { item, _, _ in item.publisher })
    }
    if preferences.pdfShowType {
        columns.append(ColumnInfo(header: "Type", maxDesired: 5, minimum: 3) { item, _, _ in item.type })
    }
    if preferences.pdfShowStyle {
        columns.append(ColumnInfo(header: "Style", maxDesired: 15, minimum: 6) { item, _, _ in item.style })
    }
    if preferences.pdfShowVersion {
        columns.append(ColumnInfo(header: "Version", maxDesired: 12, minimum: 5) { item, _, _ in item.version })
    }
    if preferences.pdfShowArch {
        columns.append(ColumnInfo(header: "Arch", maxDesired: 16, minimum: 8) { item, _, _ in item.architectures })
    }
    if preferences.pdfShowDate {
        columns.append(ColumnInfo(header: "Date", maxDesired: 12, minimum: 8) { item, _, _ in item.dateString })
    }
    if preferences.pdfShowSize {
        columns.append(ColumnInfo(header: "Size", maxDesired: 10, minimum: 4) { item, _, _ in item.sizeString })
    }
    if preferences.pdfShowRequirement {
        columns.append(ColumnInfo(header: "Requirement", maxDesired: 16, minimum: 8) { item, _, _ in item.runtimeRequirement })
    }
    if preferences.pdfShowObsolete {
        columns.append(ColumnInfo(header: "Obsolete", maxDesired: 3, minimum: 1) { item, _, _ in item.obsolete ? "Y" : "N" })
    }
    if preferences.pdfShowMissing {
        columns.append(ColumnInfo(header: "Missing", maxDesired: 3, minimum: 1) { item, _, _ in item.missing ? "Y" : "N" })
    }
    if preferences.pdfShowTrack {
        columns.append(ColumnInfo(header: "Track", maxDesired: 18, minimum: 5) { item, _, _ in item.trackName ?? "" })
    }
    if preferences.pdfShowNotes {
        columns.append(ColumnInfo(header: "Notes", maxDesired: 20, minimum: 5) { item, _, notes in notes.getNote(for: item.path) })
    }
    if preferences.pdfShowPath {
        columns.append(ColumnInfo(header: "Path", maxDesired: 60, minimum: 10) { item, _, _ in item.path })
    }

    let columnCount = columns.count
    guard columnCount > 0 else {
        return "No columns selected for export"
    }

    let sep = "  " // two spaces between columns
    let sepWidth = (columnCount - 1) * sep.count

    // Extract headers and configuration
    let headers = columns.map { $0.header }
    let maxDesired = columns.map { $0.maxDesired }
    let minimums = columns.map { $0.minimum }

    // Gather content strings per column
    func cols(for item: PluginItem) -> [String] {
        return columns.map { $0.extractor(item, ratingsManager, notesManager) }
    }

    // First, measure actual content
    var maxLens = Array(repeating: 0, count: columnCount)
    for r in plugins.prefix(1000) { // sample up to 1000 rows for performance
        let c = cols(for: r)
        for i in 0..<columnCount { maxLens[i] = max(maxLens[i], c[i].count) }
    }

    // Start with content-based widths, capped at max desired
    var widths: [Int] = maxLens.enumerated().map { idx, len in
        max(min(len, maxDesired[idx]), headers[idx].count, minimums[idx])
    }

    func totalWidth(_ w: [Int]) -> Int { w.reduce(0, +) + sepWidth }

    print("🔍 COLUMN WIDTH DEBUG:")
    print("   Capacity: \(capacity) characters")
    print("   Separator width: \(sepWidth) characters (\(columnCount - 1) separators)")
    print("   Initial widths: \(widths)")
    print("   Initial total: \(totalWidth(widths))")
    print("   Max content lengths: \(maxLens)")
    print("   Column headers: \(headers)")

    if capacity > 0 {
        // First, shrink to fit if needed
        if totalWidth(widths) > capacity {
            // Shrink all columns proportionally from largest to smallest
            var guardCount = 10_000
            while totalWidth(widths) > capacity && guardCount > 0 {
                var didReduce = false
                // Find the column with most room to shrink
                for idx in 0..<columnCount {
                    if widths[idx] > minimums[idx] {
                        widths[idx] -= 1
                        didReduce = true
                        if totalWidth(widths) <= capacity { break }
                    }
                }
                if !didReduce { break }
                guardCount -= 1
            }
        }

        // Then, expand to use available space
        // Phase 1: Expand columns up to their maxDesired width
        var guardCount = 10_000
        while totalWidth(widths) < capacity && guardCount > 0 {
            var didExpand = false
            for idx in 0..<columnCount {
                if widths[idx] < maxDesired[idx] && widths[idx] < maxLens[idx] {
                    let available = capacity - totalWidth(widths)
                    if available > 0 {
                        widths[idx] += 1
                        didExpand = true
                        if totalWidth(widths) >= capacity { break }
                    }
                }
            }
            if !didExpand { break }
            guardCount -= 1
        }

        // Phase 2: If there's still space, expand columns beyond maxDesired (prioritize wider columns)
        guardCount = 10_000
        while totalWidth(widths) < capacity && guardCount > 0 {
            var didExpand = false
            for idx in 0..<columnCount {
                // Allow expansion beyond maxDesired if content needs it
                if widths[idx] < maxLens[idx] {
                    let available = capacity - totalWidth(widths)
                    if available > 0 {
                        widths[idx] += 1
                        didExpand = true
                        if totalWidth(widths) >= capacity { break }
                    }
                }
            }
            if !didExpand { break }
            guardCount -= 1
        }

        // Phase 3: Distribute ALL remaining space to columns that still have truncated content
        // Keep iterating until we can't expand any more OR we've used all space
        print("   📊 Phase 3: Distributing remaining space")
        print("      Before Phase 3: widths=\(widths), total=\(totalWidth(widths))")
        var guardCount3 = 10_000
        while totalWidth(widths) < capacity && guardCount3 > 0 {
            var didExpand = false

            // Find columns that still have content to show
            var needyColumns: [(index: Int, need: Int)] = []
            for idx in 0..<columnCount {
                let need = maxLens[idx] - widths[idx]
                if need > 0 {
                    needyColumns.append((idx, need))
                }
            }

            // If no columns need more space, we're done
            if needyColumns.isEmpty {
                print("      ✅ No columns need more space. Stopping Phase 3.")
                break
            }

            // Distribute remaining space among needy columns
            let remainingSpace = capacity - totalWidth(widths)
            if remainingSpace <= 0 {
                print("      ✅ No remaining space. Stopping Phase 3.")
                break
            }

            // Give each needy column 1 character worth of space in rotation
            for (idx, _) in needyColumns {
                if totalWidth(widths) >= capacity { break }
                widths[idx] += 1
                didExpand = true
            }

            if !didExpand { break }
            guardCount3 -= 1
        }
        print("      After Phase 3: widths=\(widths), total=\(totalWidth(widths))")
    }

    print("   ✅ FINAL widths: \(widths)")
    print("   ✅ FINAL total: \(totalWidth(widths)) / \(capacity)")
    print("   ✅ Space utilization: \(String(format: "%.1f", Double(totalWidth(widths)) / Double(capacity) * 100))%")

    // Padding/clip helper
    func pad(_ s: String, _ n: Int) -> String {
        if s.count == n { return s }
        if s.count < n { return s + String(repeating: " ", count: n - s.count) }
        return String(s.prefix(max(0, n - 1))) + "…"
    }

    // Build lines
    let headerLine = zip(headers, widths).map { pad($0, $1) }.joined(separator: sep)
    let rule = String(repeating: "—", count: min(headerLine.count, max(capacity, headerLine.count)))
    var body = ""
    for r in plugins {
        let c = cols(for: r)
        let line = zip(c, widths).map { pad($0, $1) }.joined(separator: sep)
        body += line + "\n"
    }
    return "\(headerLine)\n\(rule)\n\(body)"
}

/// Custom NSView for printing with proper text rendering
class PrintablePluginTextView: NSView {
    var textStorage: NSTextStorage?
    var layoutManager: NSLayoutManager?
    var leftMargin: CGFloat = 18
    var rightMargin: CGFloat = 18
    var topMargin: CGFloat = 18
    var bottomMargin: CGFloat = 18

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw white background
        NSColor.white.setFill()
        dirtyRect.fill()

        // Draw text
        guard let layoutManager = layoutManager,
              let textContainer = layoutManager.textContainers.first else { return }

        let origin = CGPoint(x: leftMargin, y: topMargin)
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        guard let layoutManager = layoutManager,
              let textContainer = layoutManager.textContainers.first else { return false }

        let usedRect = layoutManager.usedRect(for: textContainer)
        let printInfo = NSPrintInfo.shared
        let pageHeight = printInfo.paperSize.height

        let totalHeight = usedRect.height + topMargin + bottomMargin
        let pageCount = Int(ceil(totalHeight / pageHeight))

        range.pointee = NSRange(location: 1, length: pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        let printInfo = NSPrintInfo.shared
        let pageHeight = printInfo.paperSize.height
        let pageWidth = printInfo.paperSize.width

        // Account for bottom margin by reducing the effective page height
        // This ensures content doesn't draw into the bottom margin area
        let effectivePageHeight = pageHeight - bottomMargin

        let yOffset = CGFloat(page - 1) * pageHeight
        return NSRect(x: 0, y: yOffset, width: pageWidth, height: effectivePageHeight)
    }
}

/// Show custom Page Setup dialog with live preview
func showCustomPageSetup(preferences: Preferences, plugins: [PluginItem]) {
    print("📋 Page Setup opened")
    print("📋 Received \(plugins.count) plugins")
    print("📋 First 5 plugins: \(plugins.prefix(5).map { $0.name })")

    let pageSetupView = PageSetupView(preferences: preferences, plugins: plugins)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Page Setup"
    window.contentView = NSHostingView(rootView: pageSetupView)
    window.minSize = NSSize(width: 880, height: 640)
    window.maxSize = NSSize(width: 2000, height: 1400)
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.isReleasedWhenClosed = false
}

/// Quick export to PDF using current Page Setup settings
func quickExportPDF(plugins: [PluginItem], preferences: Preferences) {
    print("📄 Quick Export PDF clicked")
    print("📄 Received \(plugins.count) plugins")
    print("📄 First 5 plugins: \(plugins.prefix(5).map { $0.name })")
    print("📐 Using Page Setup settings: T=\(preferences.pdfTopMargin), B=\(preferences.pdfBottomMargin), L=\(preferences.pdfLeftMargin), R=\(preferences.pdfRightMargin)")
    print("📄 Page: \(preferences.pdfPage.rawValue), Landscape: \(preferences.pdfLandscape), Font: \(preferences.pdfFontSize)pt")

    // Configure printInfo from preferences
    let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo

    var pageSize = preferences.pdfPage.sizePoints
    if preferences.pdfLandscape {
        pageSize = CGSize(width: pageSize.height, height: pageSize.width)
    }
    printInfo.paperSize = pageSize
    printInfo.orientation = preferences.pdfLandscape ? .landscape : .portrait
    printInfo.leftMargin = preferences.pdfLeftMargin
    printInfo.rightMargin = preferences.pdfRightMargin
    printInfo.topMargin = preferences.pdfTopMargin
    printInfo.bottomMargin = preferences.pdfBottomMargin

    // CRITICAL: Also update the shared instance so createPrintablePluginView uses correct settings
    NSPrintInfo.shared.paperSize = pageSize
    NSPrintInfo.shared.orientation = preferences.pdfLandscape ? .landscape : .portrait
    NSPrintInfo.shared.leftMargin = preferences.pdfLeftMargin
    NSPrintInfo.shared.rightMargin = preferences.pdfRightMargin
    NSPrintInfo.shared.topMargin = preferences.pdfTopMargin
    NSPrintInfo.shared.bottomMargin = preferences.pdfBottomMargin

    print("✅ NSPrintInfo configured: T=\(NSPrintInfo.shared.topMargin), B=\(NSPrintInfo.shared.bottomMargin), L=\(NSPrintInfo.shared.leftMargin), R=\(NSPrintInfo.shared.rightMargin)")

    // Generate filename with timestamp
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = formatter.string(from: Date())
    let defaultName = "Plugins_\(timestamp).pdf"

    // Show save panel
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = defaultName
    savePanel.allowedContentTypes = [.pdf]
    savePanel.canCreateDirectories = true

    savePanel.begin { response in
        guard response == .OK, let url = savePanel.url else { return }

        print("💾 Saving PDF to: \(url.path)")
        print("🔍 Before creating view - NSPrintInfo.shared margins: T=\(NSPrintInfo.shared.topMargin), B=\(NSPrintInfo.shared.bottomMargin), L=\(NSPrintInfo.shared.leftMargin), R=\(NSPrintInfo.shared.rightMargin)")

        // Create printable view (uses NSPrintInfo.shared)
        let printView = createPrintablePluginView(plugins: plugins, preferences: preferences)

        print("🔍 After creating view - printInfo margins: T=\(printInfo.topMargin), B=\(printInfo.bottomMargin), L=\(printInfo.leftMargin), R=\(printInfo.rightMargin)")

        // Configure print info for PDF output
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        print("🔍 Final printInfo before operation: T=\(printInfo.topMargin), B=\(printInfo.bottomMargin), L=\(printInfo.leftMargin), R=\(printInfo.rightMargin)")

        // Create print operation for PDF export
        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Run the print operation to generate PDF
        printOperation.run()

        print("✅ PDF export completed")

        dashboardTrackExport()
    }
}

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
        // Set default print orientation to landscape
        NSPrintInfo.shared.orientation = .landscape

        // Set default margins to 0.25" (18 points) on all sides
        NSPrintInfo.shared.topMargin = 18
        NSPrintInfo.shared.bottomMargin = 18
        NSPrintInfo.shared.leftMargin = 18
        NSPrintInfo.shared.rightMargin = 18

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

