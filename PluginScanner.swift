import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Data Model expected by UI
public struct ScannerPluginItem: Identifiable, Hashable, Codable {
    public let id: UUID
    public let name: String
    public let publisher: String
    public let version: String
    public let type: String
    public let style: String
    public let architectures: String
    public let date: Date?
    public let sizeBytes: Int64
    public let path: String
    public let runtimeRequirement: String
    public let obsolete: Bool

    // Cached formatters for better performance
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    // UI helpers (keep names used by ContentView) - now optimized
    public var dateString: String {
        guard let d = date else { return "" }
        return Self.dateFormatter.string(from: d)
    }
    
    public var sizeString: String {
        guard sizeBytes > 0 else { return "" }
        return Self.byteFormatter.string(fromByteCount: sizeBytes)
    }
    
    public var obsoleteString: String { obsolete ? "Yes" : "No" }
}

@MainActor
public final class PluginScanner: ObservableObject {

    // MARK: Published state used by UI
    @Published public private(set) var plugins: [ScannerPluginItem] = []
    @Published public var isScanning: Bool = false
    @Published public var progress: Double = 0
    @Published public var status: String = "Idle"
    @Published public private(set) var totalToScan: Int = 0

    // Privacy disclosure tracking (for App Store compliance)
    @Published public var shouldShowPrivacyDisclosure: Bool = false
    private static let privacyDisclosureKey = "hasShownFileAccessDisclosure"

    // Persistent storage for scanned plugins
    private static let pluginsCacheKey = "cachedScannedPlugins"
    private static let lastScanDateKey = "lastPluginScanDate"

    // Optimized background processing
    private let scanQueue = DispatchQueue(label: "plugin.scanner.queue", qos: .userInitiated, attributes: .concurrent)
    private let discoveryQueue = DispatchQueue(label: "plugin.discovery.queue", qos: .utility)
    private let resultQueue = DispatchQueue(label: "plugin.results.queue")
    private var scanTask: Task<Void, Never>?

    public init() {
        // Check if we need to show privacy disclosure on first scan
        checkPrivacyDisclosureStatus()

        // Load previously scanned plugins
        loadCachedPlugins()
    }

    // MARK: - Privacy Disclosure

    private func checkPrivacyDisclosureStatus() {
        let hasShown = UserDefaults.standard.bool(forKey: Self.privacyDisclosureKey)
        shouldShowPrivacyDisclosure = !hasShown
    }

    public func acknowledgePrivacyDisclosure() {
        UserDefaults.standard.set(true, forKey: Self.privacyDisclosureKey)
        shouldShowPrivacyDisclosure = false
    }

    // MARK: - Persistent Storage

    private func loadCachedPlugins() {
        guard let data = UserDefaults.standard.data(forKey: Self.pluginsCacheKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let cachedPlugins = try decoder.decode([ScannerPluginItem].self, from: data)
            self.plugins = cachedPlugins
            self.totalToScan = cachedPlugins.count

            if let lastScanDate = UserDefaults.standard.object(forKey: Self.lastScanDateKey) as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                self.status = "Loaded \(cachedPlugins.count) plugins (scanned \(formatter.string(from: lastScanDate)))"
            } else {
                self.status = "Loaded \(cachedPlugins.count) plugins"
            }

            AppLogger.info("Loaded \(cachedPlugins.count) cached plugins from persistent storage")
        } catch {
            AppLogger.error("Failed to load cached plugins: \(error.localizedDescription)")
            dashboardLogError(message: "Failed to load cached plugins: \(error.localizedDescription)", severity: "error", context: "Plugin Scanner - Cache Load")
        }
    }

    private func saveCachedPlugins() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(plugins)
            UserDefaults.standard.set(data, forKey: Self.pluginsCacheKey)
            UserDefaults.standard.set(Date(), forKey: Self.lastScanDateKey)
            AppLogger.info("Saved \(plugins.count) plugins to persistent storage")
        } catch {
            AppLogger.error("Failed to save cached plugins: \(error.localizedDescription)")
            dashboardLogError(message: "Failed to save cached plugins: \(error.localizedDescription)", severity: "error", context: "Plugin Scanner - Cache Save")
        }
    }
    
    // MARK: Async Semaphore Helper
    private actor AsyncSemaphore {
        private var value: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []
        
        init(value: Int) {
            self.value = value
        }
        
        func wait() async {
            if value > 0 {
                value -= 1
                return
            }
            
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        
        func signal() {
            if waiters.isEmpty {
                value += 1
            } else {
                let waiter = waiters.removeFirst()
                waiter.resume()
            }
        }
    }

    // MARK: Public API

    // MARK: Public API

    /// Force-start a scan even if a previous run erroneously left isScanning = true
    public func forceScan(extraPaths roots: [URL]?) {
        // Cancel any existing scan
        scanTask?.cancel()
        self.isScanning = false
        self.scan(extraPaths: roots)
    }

    /// Scans the given roots. If `roots` is nil or empty, uses default plugin locations.
    public func scan(extraPaths roots: [URL]?) {
        if isScanning { return }
        
        // Cancel any existing scan task
        scanTask?.cancel()
        
        // Reset state immediately on main thread
        self.isScanning = true
        self.plugins = []
        self.progress = 0
        self.status = "Preparing…"
        self.totalToScan = 0

        // Launch async scanning task
        scanTask = Task {
            await performScan(extraPaths: roots)
        }
    }
    
    private func performScan(extraPaths roots: [URL]?) async {
        // Phase 1: Fast discovery of plugin URLs
        let urls = await withTaskGroup(of: [URL].self) { group in
            let rootsToUse = (roots?.isEmpty == false) ? dedupe(roots!) : defaultPluginRoots()
            
            for root in rootsToUse {
                group.addTask {
                    await self.discoverPluginURLs(in: root)
                }
            }
            
            var allUrls: [URL] = []
            for await urls in group {
                allUrls.append(contentsOf: urls)
            }
            
            // Deduplicate and sort
            let uniqueUrls = Array(Set(allUrls)).sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            
            await MainActor.run {
                self.totalToScan = uniqueUrls.count
            }
            
            return uniqueUrls
        }
        
        guard !urls.isEmpty else {
            await MainActor.run {
                self.isScanning = false
                self.status = "No plug-ins found"
                self.progress = 1.0
            }
            return
        }
        
        // Phase 2: Process plugins with optimized batching
        await processBatchedPlugins(urls: urls)
    }
    
    private func processBatchedPlugins(urls: [URL]) async {
        let batchSize = 100 // Larger batches for better throughput
        let maxConcurrency = ProcessInfo.processInfo.activeProcessorCount * 2 // More aggressive concurrency

        var processedCount = 0
        var allItems: [ScannerPluginItem] = []

        // INSTANT FIRST UPDATE - show results immediately as they come in
        await MainActor.run {
            self.progress = 0.01
            self.status = "Scanning… 0 / \(urls.count)"
        }

        // Process URLs in batches
        for startIndex in stride(from: 0, to: urls.count, by: batchSize) {
            let endIndex = min(startIndex + batchSize, urls.count)
            let batch = Array(urls[startIndex..<endIndex])

            // Process batch with high concurrency
            let batchItems = await withTaskGroup(of: ScannerPluginItem?.self, returning: [ScannerPluginItem].self) { group in
                let semaphore = AsyncSemaphore(value: maxConcurrency)

                for url in batch {
                    group.addTask {
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        return await Task.detached(priority: .userInitiated) {
                            autoreleasepool {
                                self.buildItem(from: url)
                            }
                        }.value
                    }
                }

                var items: [ScannerPluginItem] = []
                for await item in group {
                    if let item = item {
                        items.append(item)
                    }
                }
                return items
            }

            // Update progress and add items INSTANTLY
            processedCount += batch.count
            allItems.append(contentsOf: batchItems)

            // Infer missing publishers and styles after each batch
            allItems = inferMissingMetadata(allItems)

            let progress = Double(processedCount) / Double(urls.count)

            // INSTANT UI UPDATE - no animation delay
            await MainActor.run {
                self.progress = progress
                self.status = "Scanning… \(processedCount) / \(urls.count)"
                // INSTANT plugin list update with inferred metadata
                self.plugins = allItems
            }
        }

        // Final inference pass (just to be safe)
        allItems = inferMissingMetadata(allItems)

        // Final update
        await MainActor.run {
            self.plugins = allItems
            self.isScanning = false
            self.progress = 1.0
            self.status = "Scan complete."
            self.totalToScan = allItems.count

            // Save to persistent storage
            self.saveCachedPlugins()

            // Auto-save to shared location for iOS app
            self.saveToSharedLocation()

            // Track scan completion for dashboard reporting
            dashboardTrackScan()
        }
    }

    // Infer missing publisher and style information from other formats of the same plugin
    private nonisolated func inferMissingMetadata(_ items: [ScannerPluginItem]) -> [ScannerPluginItem] {
        // Group plugins by name
        var pluginsByName: [String: [ScannerPluginItem]] = [:]
        for item in items {
            pluginsByName[item.name, default: []].append(item)
        }

        var result: [ScannerPluginItem] = []

        for item in items {
            var updated = item

            // If this plugin is missing publisher or style, try to infer from other formats
            let siblings = pluginsByName[item.name] ?? []

            // Infer publisher from siblings (prefer AU, then VST3, then others)
            if updated.publisher.isEmpty {
                if let sibling = siblings.first(where: { !$0.publisher.isEmpty && $0.type == "AU" }) {
                    updated = ScannerPluginItem(
                        id: updated.id, name: updated.name, publisher: sibling.publisher,
                        version: updated.version, type: updated.type, style: updated.style,
                        architectures: updated.architectures, date: updated.date,
                        sizeBytes: updated.sizeBytes, path: updated.path,
                        runtimeRequirement: updated.runtimeRequirement, obsolete: updated.obsolete
                    )
                } else if let sibling = siblings.first(where: { !$0.publisher.isEmpty }) {
                    updated = ScannerPluginItem(
                        id: updated.id, name: updated.name, publisher: sibling.publisher,
                        version: updated.version, type: updated.type, style: updated.style,
                        architectures: updated.architectures, date: updated.date,
                        sizeBytes: updated.sizeBytes, path: updated.path,
                        runtimeRequirement: updated.runtimeRequirement, obsolete: updated.obsolete
                    )
                }
            }

            // Infer style from siblings
            if updated.style.isEmpty {
                if let sibling = siblings.first(where: { !$0.style.isEmpty }) {
                    updated = ScannerPluginItem(
                        id: updated.id, name: updated.name, publisher: updated.publisher,
                        version: updated.version, type: updated.type, style: sibling.style,
                        architectures: updated.architectures, date: updated.date,
                        sizeBytes: updated.sizeBytes, path: updated.path,
                        runtimeRequirement: updated.runtimeRequirement, obsolete: updated.obsolete
                    )
                }
            }

            result.append(updated)
        }

        return result
    }
    // MARK: Defaults & discovery

    private nonisolated func defaultPluginRoots() -> [URL] {
        #if os(macOS)
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Library/Audio/Plug-Ins", isDirectory: true),
            home.appendingPathComponent("Library/Audio/Plug-Ins", isDirectory: true),
            URL(fileURLWithPath: "/Library/Application Support/Avid/Audio/Plug-Ins", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/Avid/Audio/Plug-Ins", isDirectory: true)
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        #else
        return []
        #endif
    }

    private nonisolated func dedupe(_ urls: [URL]) -> [URL] {
        Array(Set(urls.map { $0.standardizedFileURL })).sorted { $0.path < $1.path }
    }

    private func discoverPluginURLs(in root: URL) async -> [URL] {
        return await Task.detached {
            let fm = FileManager.default
            var results: [URL] = []
            let exts: Set<String> = ["component","vst","vst3","aaxplugin","clap","lv2"]

            // Recursive directory traversal
            func traverse(_ dir: URL) {
                guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }

                for url in contents {
                    if exts.contains(url.pathExtension.lowercased()) {
                        results.append(url)
                        // Don't descend into plugin bundles
                    } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                        traverse(url)
                    }
                }
            }

            traverse(root)
            return results
        }.value
    }

    // MARK: Build one item (now nonisolated for async usage)

    private nonisolated func buildItem(from url: URL) -> ScannerPluginItem? {
        let type = pluginType(for: url)
        
        // AAX processing - get info but skip slow architecture detection
        if type == "AAX" {
            let info = readAAXInfoFast(for: url)
            let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            let size = packageSize(at: url)

            return ScannerPluginItem(
                id: UUID(),
                name: info.name ?? url.deletingPathExtension().lastPathComponent,
                publisher: info.publisher ?? "",
                version: info.version ?? "",
                type: type,
                style: info.style ?? "",
                architectures: "Universal", // Skip slow arch detection for AAX
                date: date,
                sizeBytes: size,
                path: url.path,
                runtimeRequirement: "Universal",
                obsolete: false
            )
        }
        
        // Normal processing for non-AAX plugins
        let info = readInfo(for: url, type: type)
        let archs = architectures(at: info.executableURL)
        let size = packageSize(at: url)
        let req = runtimeRequirement(fromArchString: archs)
        let obsolete = archs.lowercased().contains("intel 32")
        let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        return ScannerPluginItem(
            id: UUID(),
            name: info.name ?? url.deletingPathExtension().lastPathComponent,
            publisher: info.publisher ?? derivePublisher(from: info.bundleID),
            version: info.version ?? "",
            type: type,
            style: info.style ?? "",
            architectures: archs,
            date: date,
            sizeBytes: size,
            path: url.path,
            runtimeRequirement: req,
            obsolete: obsolete
        )
    }

    private nonisolated func pluginType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "component": return "AU"
        case "vst":       return "VST"
        case "vst3":      return "VST3"
        case "aaxplugin": return "AAX"
        case "clap":      return "CLAP"
        case "lv2":       return "LV2"
        default:          return url.pathExtension.uppercased()
        }
    }

    // MARK: Info extraction

    private struct PlugInfo: Sendable {
        var bundleID: String?
        var name: String?
        var version: String?
        var publisher: String?
        var executableURL: URL?
        var style: String?
    }

    private nonisolated func readInfo(for url: URL, type: String) -> PlugInfo {
        // Fast path for AAX plugins - use lightweight scanning
        if type == "AAX" {
            return readAAXInfoFast(for: url)
        }

        // Fast path for other plugin types - skip heavy operations when possible
        return readPluginInfoFast(for: url, type: type)
    }
    
    // Optimized AAX plugin reading - get essential info efficiently
    private nonisolated func readAAXInfoFast(for url: URL) -> PlugInfo {
        var out = PlugInfo()

        // Use filename as fallback name
        out.name = url.deletingPathExtension().lastPathComponent

        // Read plist to get proper plugin information
        let plistPath = url.appendingPathComponent("Contents/Info.plist")
        if let plistData = try? Data(contentsOf: plistPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {

            out.bundleID = plist["CFBundleIdentifier"] as? String

            // Extract name - prefer non-empty values, fallback to filename
            if let displayName = plist["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                out.name = displayName
            } else if let bundleName = plist["CFBundleName"] as? String, !bundleName.isEmpty {
                out.name = bundleName
            }
            // else keep the filename we already set

            // Extract version - clean up if it contains extra text
            if let versionString = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String {
                let cleanVersion = versionString.components(separatedBy: CharacterSet(charactersIn: " ,")).first ?? versionString
                out.version = cleanVersion
            }

            // Extract publisher - try CompanyName first, then parse from CFBundleGetInfoString, finally try bundle ID
            if let companyName = plist["CompanyName"] as? String, !companyName.isEmpty {
                out.publisher = companyName
            } else if let infoString = plist["CFBundleGetInfoString"] as? String, !infoString.isEmpty {
                // Parse "Copyright YYYY CompanyName" or similar patterns
                let extracted = Self.extractPublisherFromInfoString(infoString)
                if !extracted.isEmpty {
                    out.publisher = extracted
                }
            }

            // Fallback: try to extract from bundle identifier (e.g., "com.SpectraLayers.aax.ara" -> "SpectraLayers")
            if (out.publisher ?? "").isEmpty, let bundleID = out.bundleID {
                out.publisher = Self.extractPublisherFromBundleID(bundleID)
            }

            // Try to find executable - simplified approach for AAX
            if let execName = plist["CFBundleExecutable"] as? String {
                out.executableURL = url.appendingPathComponent("Contents/MacOS/\(execName)")
            }
        }

        // Detect plugin category from name
        let detectedCategory = Self.detectPluginCategory(name: out.name ?? "")
        if !detectedCategory.isEmpty {
            out.style = detectedCategory
        }

        return out
    }
    
    // Extract publisher from CFBundleGetInfoString (e.g., "5.4.1.17134, Authorization: FilterFreak1, Copyright 1995-2023 Soundtoys Inc.")
    private nonisolated static func extractPublisherFromInfoString(_ infoString: String) -> String {
        // Look for "Copyright" followed by years and company name
        if let copyrightRange = infoString.range(of: "Copyright", options: .caseInsensitive) {
            let afterCopyright = String(infoString[copyrightRange.upperBound...])
            // Remove year patterns like "1995-2023" or "2023"
            let withoutYears = afterCopyright.replacingOccurrences(of: #"\b\d{4}(-\d{4})?\b"#, with: "", options: .regularExpression)
            // Clean up and get the company name
            let cleaned = withoutYears.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",-"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        // Fallback: try to find company name after comma (but skip if it looks like a version number)
        let components = infoString.components(separatedBy: ",")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip if it looks like a version number (starts with digit)
            if !trimmed.isEmpty, let firstChar = trimmed.first, !firstChar.isNumber {
                return trimmed
            }
        }

        return ""
    }

    // Extract publisher from bundle identifier (e.g., "com.SpectraLayers.aax.ara" -> "SpectraLayers")
    private nonisolated static func extractPublisherFromBundleID(_ bundleID: String) -> String {
        // Bundle IDs typically follow pattern: com.CompanyName.product.type
        // Extract the second component after splitting by dots
        let components = bundleID.components(separatedBy: ".")

        // Need at least "com.CompanyName" or similar
        guard components.count >= 2 else { return "" }

        // Skip common prefixes and suffixes
        let skipWords = ["com", "org", "net", "io", "aax", "vst", "vst3", "au", "plugin", "audio", "ara", "bridge"]

        // Find the first component that's not a skip word and looks like a company name
        for component in components {
            let lower = component.lowercased()
            if !skipWords.contains(lower) && component.count > 1 {
                // Capitalize first letter
                return component.prefix(1).uppercased() + component.dropFirst()
            }
        }

        return ""
    }

    // Decode AU type codes to readable categories
    private nonisolated static func auTypeToStyle(_ typeCode: String) -> String {
        switch typeCode {
        case "aufx": return "Effect"
        case "aumu": return "Music Effect"
        case "aumf": return "Music Effect"
        case "augn": return "Generator"
        case "aumi": return "Instrument"
        case "aumx": return "Mixer"
        case "aupn": return "Panner"
        case "auol": return "Offline"
        case "aufc": return "Format Converter"
        default: return "Effect"
        }
    }

    // Detect plugin category from name (for detailed categorization)
    private nonisolated static func detectPluginCategory(name: String) -> String {
        let lower = name.lowercased()

        // Instruments (check first - most specific)
        if lower.contains("piano") || lower.contains("brass") || lower.contains("strings") ||
           lower.contains("woodwind") || lower.contains("voices") || lower.contains("choir") ||
           lower.contains("synth") || lower.contains("drum") || lower.contains("bass") ||
           lower.contains("guitar") || lower.contains("organ") || lower.contains("keys") ||
           lower.contains("percussion") || lower.contains("orchestra") || lower.contains("violin") ||
           lower.contains("cello") || lower.contains("harp") || lower.contains("flute") ||
           lower.contains("trumpet") || lower.contains("sax") || lower.contains("horn") ||
           // Classic synth names (Roland, Moog, Korg, etc.)
           lower.contains("jup-") || lower.contains("jupiter") || lower.contains("jun-") || lower.contains("juno") ||
           lower.contains("prophet") || lower.contains("minimoog") || lower.contains("moog") ||
           lower.contains("ms-20") || lower.contains("ms20") || lower.contains("arp") ||
           lower.contains("ob-") || lower.contains("oberheim") || lower.contains("dx7") ||
           lower.contains("v-synth") || lower.contains("analog") && (lower.contains("lab") || lower.contains("v")) ||
           // Arturia synth line (CMI, CS-80, CZ, etc.)
           lower.contains("cmi ") || lower.contains("cs-") || lower.contains("cz ") ||
           lower.contains("cp-") || lower.contains("cr-") ||
           // Beat/instrument keywords
           lower.contains("beat") && (lower.contains("epic") || lower.contains("captain")) ||
           lower.contains("chord") && (lower.contains("epic") || lower.contains("lite")) ||
           lower.contains("deep epic") || lower.contains("midi") && lower.contains("epic") ||
           // Keyboard instruments
           lower.contains("clav") || lower.contains("wurli") || lower.contains("rhodes") ||
           lower.contains("mellotron") ||
           // Specific synth models and series
           lower.contains("acid v") || lower.contains("b-3 v") || lower.contains("buchla") ||
           lower.contains("db-33") || lower.contains("dmx") || lower.contains("emulator") ||
           lower.contains("farfisa") || lower.contains("fm8") || lower.contains("axxess") ||
           lower.contains("electribe") || lower.contains("ep-1") || lower.contains("augmented") ||
           // Samplers and drum machines
           lower.contains("battery") || lower.contains("bfd") || lower.contains("backbone") ||
           lower.contains("boom") && !lower.contains("library") || lower.contains("falcon") ||
           lower.contains("biotek") || lower.contains("captain play") || lower.contains("captain melody") ||
           // Wavetable and hybrid synths
           lower.contains("ana2") || lower.contains("fury") || lower.contains("generate") ||
           lower.contains("efx") && (lower.contains("fragments") || lower.contains("motions") || lower.contains("refract")) ||
           // Classic and modern synths (more specific models)
           lower.contains("gx-80") || lower.contains("imposcar") || lower.contains("m1 ") || lower.contains("mariana") ||
           lower.contains("massive") || lower.contains("matrix-12") || lower.contains("mercury-") ||
           lower.contains("microkorg") || lower.contains("minikorg") || lower.contains("mini v") ||
           lower.contains("minibrute") || lower.contains("minifreak") || lower.contains("minigrand") ||
           lower.contains("minimonsta") || lower.contains("miniraze") || lower.contains("modular v") ||
           lower.contains("modwave") || lower.contains("monopoly") || lower.contains("op-x") ||
           lower.contains("opsix") || lower.contains("pigments") || lower.contains("polybrute") ||
           lower.contains("polysix") || lower.contains("prophecy") || lower.contains("punchbox") ||
           lower.contains("quadra") || lower.contains("sem ") || lower.contains("sem v") ||
           lower.contains("kaosspad") || lower.contains("ospar") || lower.contains("paralogy") ||
           lower.contains("nepheton") || lower.contains("oddity") || lower.contains("microtonic") ||
           // Groove production and sequencers
           lower.contains("maschine") || lower.contains("mpc ") || lower.contains("playbeat") ||
           lower.contains("reaktor") && !lower.contains("fx") ||
           // Kontakt and cell-based instruments
           lower.contains("cell") && (lower.contains("groove") || lower.contains("legacy") || lower.contains("play")) ||
           lower.contains("komplete kontrol") || lower.contains("originals") {
            return "Instrument"
        }

        // EQ
        if lower.contains("eq") || lower.contains("equalizer") || lower.contains("equalization") ||
           // Pro Tools built-in EQs and specific models
           lower.contains("304c") || lower.contains("304e") || lower.contains("7-band") {
            return "EQ"
        }

        // Dynamics (check before other categories to catch "compressor" before generic matches)
        if lower.contains("compressor") || lower.contains("limiter") || lower.contains("gate") ||
           lower.contains("expander") || lower.contains("dynamics") || lower.contains("compress") ||
           lower.contains("loudness") || lower.contains("comp ") || lower.contains("comp-") ||
           lower.contains("diode-") || lower.contains("fet-") || lower.contains("tube-") ||
           lower.contains("vca-") || lower.contains("sta-") {
            return "Dynamics"
        }

        // Reverb
        if lower.contains("reverb") || lower.contains("verb") || lower.contains("room") ||
           lower.contains("hall") || lower.contains("plate") || lower.contains("spring") ||
           lower.contains("blackhole") || lower.contains("shimmer") || lower.contains("bloom") ||
           lower.contains("aether") || lower.contains("rev ") || lower.contains("rx1200") {
            return "Reverb"
        }

        // Delay
        if lower.contains("delay") || lower.contains("echo") ||
           lower.contains("primaltap") || lower.contains("recirculate") {
            return "Delay"
        }

        // Modulation
        if lower.contains("chorus") || lower.contains("flanger") || lower.contains("phaser") ||
           lower.contains("tremolo") || lower.contains("vibrato") || lower.contains("modulation") ||
           lower.contains("rotary") {
            return "Modulation"
        }

        // Pitch Shift
        if lower.contains("pitch") || lower.contains("autotune") || lower.contains("tune") ||
           lower.contains("harmony") || lower.contains("transpose") ||
           lower.contains("harmonizer") || lower.contains("h3000") || lower.contains("h910") ||
           lower.contains("h949") || lower.contains("octavox") || lower.contains("littlealterboy") ||
           lower.contains("manipulator") || lower.contains("melodyne") {
            return "Pitch Shift"
        }

        // Distortion/Saturation/Harmonic
        if lower.contains("distortion") || lower.contains("overdrive") || lower.contains("saturate") ||
           lower.contains("saturation") || lower.contains("drive") || lower.contains("fuzz") ||
           lower.contains("crunch") || lower.contains("amp") || lower.contains("exciter") ||
           lower.contains("enhancer") || lower.contains("warmth") || lower.contains("tube") && !lower.contains("comp") ||
           lower.contains("valve") || lower.contains("color") || lower.contains("character") ||
           lower.contains("dist ") || lower.contains("coldfire") || lower.contains("atomika") ||
           lower.contains("fb7999") || lower.contains("influx") ||
           lower.contains("pre 1973") || lower.contains("pre trid") || lower.contains("pre v76") ||
           lower.contains("black box") || lower.contains("hg-2") || lower.contains("rewind") {
            return "Harmonic"
        }

        // Noise Reduction
        if lower.contains("noise") || lower.contains("denoise") || lower.contains("dehum") ||
           lower.contains("declick") || lower.contains("declip") || lower.contains("restoration") {
            return "Noise Reduction"
        }

        // Spatial/Stereo/Width
        if lower.contains("stereo") || lower.contains("spatial") || lower.contains("imager") ||
           lower.contains("width") || lower.contains("pan") || lower.contains("surround") ||
           lower.contains("binaural") || lower.contains("3d audio") {
            return "Sound Field"
        }

        // Mastering
        if lower.contains("master") || lower.contains("finalizer") {
            return "Mastering"
        }

        // Metering/Analysis
        if lower.contains("meter") || lower.contains("analyzer") || lower.contains("spectrum") ||
           lower.contains("scope") || lower.contains("peak") || lower.contains("vu") ||
           lower.contains("lufs") || lower.contains("rms") {
            return "Metering"
        }

        // Filter (catch vintage filter, talkbox, etc.)
        if lower.contains("filter") || lower.contains("talkbox") {
            return "Filter"
        }

        // Sampler/Player
        if lower.contains("sampler") || lower.contains("player") || lower.contains("kontakt") ||
           lower.contains("rompler") {
            return "Instrument"
        }

        // Multi-effect/Channel Strip
        if lower.contains("channel") || lower.contains("strip") || lower.contains("suite") ||
           lower.contains("bundle") || lower.contains("collection") || lower.contains("effectrack") ||
           lower.contains("effect rack") || lower.contains("fx rack") || lower.contains("console") ||
           lower.contains("dynab") || lower.contains("grm ") || lower.contains("flux mini") ||
           lower.contains("frontier") || lower.contains("ensemble") || lower.contains("lo-fi") ||
           lower.contains("multipass") || lower.contains("mde-x") || lower.contains("pendulate") ||
           lower.contains("rando") || lower.contains("random ") || lower.contains("mirror") ||
           lower.contains("life") && !lower.contains("wildlife") ||
           // MIDI/Composition Tools (categorized as Effect for utility)
           lower.contains("scaler") || lower.contains("pilot chords") || lower.contains("pilot melody") ||
           lower.contains("melody sauce") || lower.contains("riffer") ||
           lower.contains("human lite") && (lower.contains("audio") || lower.contains("midi")) ||
           // Special routing/authoring
           lower.contains("dolby") && (lower.contains("renderer") || lower.contains("authoring")) ||
           lower.contains("mpeg-h") || lower.contains("groove shaper") ||
           // Audio editors and spectral tools
           lower.contains("spectralayers") || lower.contains("spectral editor") {
            return "Effect"
        }

        // Transient Designer
        if lower.contains("transient") || lower.contains("envelope") && (lower.contains("shaper") || lower.contains("designer")) {
            return "Dynamics"
        }

        // Sidechain/Ducking
        if lower.contains("sidechain") || lower.contains("ducking") {
            return "Dynamics"
        }

        // Vocoder/Voice Processing
        if lower.contains("vocoder") || lower.contains("voice") && lower.contains("process") {
            return "Effect"
        }

        // De-esser
        if lower.contains("de-ess") || lower.contains("deess") || lower.contains("sibilance") {
            return "Dynamics"
        }

        // Glitch/Stutter/Repeat
        if lower.contains("glitch") || lower.contains("stutter") || lower.contains("repeat") ||
           lower.contains("slice") || lower.contains("chop") {
            return "Effect"
        }

        // Ring Modulator
        if lower.contains("ring mod") || lower.contains("ringmod") {
            return "Modulation"
        }

        // Utility (bus, routing, monitoring tools)
        if lower.contains("gain") || lower.contains("trim") || lower.contains("utility") ||
           lower.contains("phase") || lower.contains("bus ") || lower.contains("monitor") ||
           lower.contains("routing") || lower.contains("toolbox") || lower.contains("codec") ||
           lower.contains("click") || lower.contains("comeback") || lower.contains("crystal") ||
           lower.contains("crush") || lower.contains("station") || lower.contains("converter") {
            return "Utility"
        }

        return ""
    }

    // Fast plugin info reading for other types
    private nonisolated func readPluginInfoFast(for url: URL, type: String) -> PlugInfo {
        var out = PlugInfo()
        out.name = url.deletingPathExtension().lastPathComponent

        func fill(from bundle: Bundle) {
            let d = bundle.infoDictionary ?? [:]
            out.bundleID = d["CFBundleIdentifier"] as? String
            out.name = (d["CFBundleDisplayName"] as? String)
                ?? (d["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            // Extract version - clean up if it contains extra text
            if let versionString = d["CFBundleShortVersionString"] as? String ?? d["CFBundleVersion"] as? String {
                // Remove everything after first space or comma (e.g., "5.4.1.17134 Authorization: ..." -> "5.4.1.17134")
                let cleanVersion = versionString.components(separatedBy: CharacterSet(charactersIn: " ,")).first ?? versionString
                out.version = cleanVersion
            }

            // Extract publisher - try CompanyName first, then parse from CFBundleGetInfoString
            if let companyName = d["CompanyName"] as? String {
                out.publisher = companyName
            } else if let infoString = d["CFBundleGetInfoString"] as? String {
                out.publisher = Self.extractPublisherFromInfoString(infoString)
            }

            out.executableURL = bundle.executableURL

            // Detect plugin category from name (works for all plugin types)
            let pluginName = out.name ?? url.deletingPathExtension().lastPathComponent
            let detectedCategory = Self.detectPluginCategory(name: pluginName)

            // ALWAYS prefer name-based detection if found
            if !detectedCategory.isEmpty {
                out.style = detectedCategory
            }
            // For AU plugins, use AU type code ONLY if name detection found nothing
            else if type == "AU", let components = d["AudioComponents"] as? [[String: Any]],
                    let firstComponent = components.first,
                    let auType = firstComponent["type"] as? String {
                // Only use generic AU type if it's not "Music Effect" (which is too vague)
                let auStyle = Self.auTypeToStyle(auType)
                if auStyle != "Music Effect" {
                    out.style = auStyle
                }
            }
        }

        switch type {
        case "AU","VST","VST3":
            if let b = Bundle(url: url) {
                fill(from: b)
                if out.executableURL == nil, url.hasDirectoryPath {
                    let mac = url.appendingPathComponent("Contents/MacOS")
                    if let exe = (try? FileManager.default.contentsOfDirectory(at: mac, includingPropertiesForKeys: nil))?
                        .first(where: { !$0.lastPathComponent.hasPrefix(".") }) {
                        out.executableURL = exe
                    }
                }
            }

        case "CLAP":
            out.name = url.deletingPathExtension().lastPathComponent
            if url.hasDirectoryPath {
                let mac = url.appendingPathComponent("Contents/MacOS")
                if let exe = (try? FileManager.default.contentsOfDirectory(at: mac, includingPropertiesForKeys: nil))?.first {
                    out.executableURL = exe
                }
                let json1 = url.appendingPathComponent("clap.json")
                let json2 = url.appendingPathComponent("Contents/Resources/clap.json")
                if let meta = readCLAPJSON(at: json1) ?? readCLAPJSON(at: json2) {
                    out.name = meta.name ?? out.name
                    out.publisher = meta.vendor ?? out.publisher
                    out.version = meta.version ?? out.version
                }
            } else {
                out.executableURL = url
                let sidecar = url.deletingPathExtension().appendingPathExtension("json")
                if let meta = readCLAPJSON(at: sidecar) {
                    out.name = meta.name ?? out.name
                    out.publisher = meta.vendor ?? out.publisher
                    out.version = meta.version ?? out.version
                }
            }

        case "LV2":
            out.name = url.deletingPathExtension().lastPathComponent
            let ttl1 = url.appendingPathComponent("manifest.ttl")
            let ttl2 = url.appendingPathComponent("\(out.name ?? "plugin").ttl")
            if let meta = readLV2TTL(at: ttl1) ?? readLV2TTL(at: ttl2) {
                out.name = meta.name ?? out.name
                out.publisher = meta.author ?? out.publisher
                out.version = meta.version ?? out.version
                if let rel = meta.binaryRelative {
                    out.executableURL = url.appendingPathComponent(rel).standardizedFileURL
                }
            }
            if out.executableURL == nil {
                // Use synchronous directory enumeration for Swift 6 compatibility
                if let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for f in files where ["dylib","so"].contains(f.pathExtension.lowercased()) {
                        out.executableURL = f
                        break
                    }
                }
            }

        default:
            break
        }

        // final attempt
        if out.executableURL == nil, url.hasDirectoryPath {
            let mac = url.appendingPathComponent("Contents/MacOS")
            if let exe = (try? FileManager.default.contentsOfDirectory(at: mac, includingPropertiesForKeys: nil))?
                .first(where: { !$0.lastPathComponent.hasPrefix(".") }) {
                out.executableURL = exe
            }
        }

        // Detect plugin category from name if not already set (for CLAP, LV2, and any VST/VST3 that didn't go through fill)
        if (out.style == nil || out.style?.isEmpty == true), let pluginName = out.name {
            let detectedCategory = Self.detectPluginCategory(name: pluginName)
            if !detectedCategory.isEmpty {
                out.style = detectedCategory
            }
        }

        return out
    }

    private struct CLAPMeta { var name: String?; var vendor: String?; var version: String? }

    private nonisolated func readCLAPJSON(at url: URL) -> CLAPMeta? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var m = CLAPMeta()
        m.name = (obj["name"] as? String) ?? (obj["plugin_name"] as? String)
        m.vendor = (obj["vendor"] as? String) ?? (obj["author"] as? String)
        m.version = (obj["version"] as? String)
        return m
    }

    private struct LV2Meta { var name: String?; var author: String?; var version: String?; var binaryRelative: String? }

    private nonisolated func readLV2TTL(at url: URL) -> LV2Meta? {
        guard FileManager.default.fileExists(atPath: url.path),
              let s = try? String(contentsOf: url) else { return nil }

        func quoted(_ key: String) -> String? {
            if let r = s.range(of: "\(key)\\s+\"([^\"]+)\"", options: .regularExpression) {
                let frag = String(s[r])
                if let q1 = frag.firstIndex(of: "\""), let q2 = frag.lastIndex(of: "\""), q2 > q1 {
                    return String(frag[frag.index(after: q1)..<q2])
                }
            }
            return nil
        }

        var binRel: String?
        if let r = s.range(of: "lv2:binary\\s+<([^>]+)>", options: .regularExpression) {
            let frag = String(s[r])
            if let lt = frag.firstIndex(of: "<"), let gt = frag.firstIndex(of: ">"), gt > lt {
                binRel = String(frag[frag.index(after: lt)..<gt])
            }
        }

        return LV2Meta(
            name: quoted("doap:name") ?? quoted("lv2:name"),
            author: quoted("doap:developer") ?? quoted("doap:maintainer") ?? quoted("doap:vendor"),
            version: quoted("doap:revision") ?? quoted("lv2:minorVersion"),
            binaryRelative: binRel
        )
    }

    // MARK: Helpers

    private nonisolated func derivePublisher(from bundleID: String?) -> String {
        guard let id = bundleID, !id.isEmpty else { return "" }
        let parts = id.split(separator: ".")
        guard parts.count >= 2 else { return "" }
        let org = parts[1].replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return org.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    private nonisolated func runtimeRequirement(fromArchString archs: String) -> String {
        let s = archs.lowercased()
        let hasARM = s.contains("arm64") || s.contains("apple")
        let hasX64 = s.contains("x86_64") || s.contains("intel 64")
        switch (hasARM, hasX64) {
        case (true, true):  return "Universal"
        case (true, false): return "Apple Silicon"
        case (false, true): return "Intel 64 (Rosetta)"
        default:            return archs.isEmpty ? "" : archs
        }
    }

    // Architecture detection cache to avoid repeated lipo/file calls
    private nonisolated(unsafe) static let archCache = NSCache<NSString, NSString>()

    private nonisolated func architectures(at execURL: URL?) -> String {
        #if os(macOS)
        guard let execURL, FileManager.default.fileExists(atPath: execURL.path) else { return "" }

        // Check cache first
        let cacheKey = execURL.path as NSString
        if let cached = Self.archCache.object(forKey: cacheKey) as String? {
            return cached
        }

        func run(_ tool: String, _ args: [String]) -> String {
            let p = Process()
            p.launchPath = tool
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            do { try p.run(); p.waitUntilExit() } catch { return "" }
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }

        var s = run("/usr/bin/lipo", ["-info", execURL.path]).lowercased()
        if s.isEmpty {
            s = run("/usr/bin/file", ["-b", execURL.path]).lowercased()
        }

        let known = ["arm64","x86_64","i386","ppc64","ppc"]
        let found = known.filter { s.contains($0) }
        if found.isEmpty { return "" }

        let pretty = found.map {
            switch $0 {
            case "arm64":  return "Apple"
            case "x86_64": return "Intel 64"
            case "i386":   return "Intel 32"
            case "ppc64":  return "PPC 64"
            case "ppc":    return "PPC"
            default:       return $0
            }
        }

        let result = pretty.joined(separator: ", ")

        // Cache the result
        Self.archCache.setObject(result as NSString, forKey: cacheKey)

        return result
        #else
        return ""
        #endif
    }

    private nonisolated func packageSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        if url.hasDirectoryPath {
            if let en = fm.enumerator(at: url,
                                      includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                      options: [.skipsHiddenFiles]) {
                for case let f as URL in en {
                    if let v = try? f.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                       v.isRegularFile == true, let n = v.fileSize {
                        total += Int64(n)
                    }
                }
            }
        } else if let n = try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber {
            total = n.int64Value
        }
        return total
    }

    // MARK: - Auto-save for iOS Sync

    private func saveToSharedLocation() {
        #if os(macOS)
        let sharedDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PluginReporter")
        #else
        // On iOS, use the app's document directory
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppLogger.error("Could not access documents directory")
            return
        }
        let sharedDir = documentsDir.appendingPathComponent("PluginReporter")
        #endif

        do {
            // Create directory if needed
            try FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

            let fileURL = sharedDir.appendingPathComponent("plugins.json")

            // Convert ScannerPluginItem to PluginItem format for export
            let exportData: [[String: Any]] = plugins.map { item in
                let dateKey: Double = item.date?.timeIntervalSince1970 ?? 0
                return [
                    "Name": item.name,
                    "Publisher": item.publisher,
                    "Version": item.version,
                    "Type": item.type,
                    "Style": item.style,
                    "Architectures": item.architectures,
                    "Date": dateKey,
                    "SizeBytes": item.sizeBytes,
                    "Path": item.path,
                    "Requirement": item.runtimeRequirement,
                    "Obsolete": item.obsolete
                ]
            }

            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted])
            try jsonData.write(to: fileURL, options: [.atomic])

            AppLogger.info("Auto-saved \(plugins.count) plugins")
        } catch {
            AppLogger.error("Failed to auto-save plugins: \(error.localizedDescription)")
            dashboardLogError(message: "Failed to auto-save plugins: \(error.localizedDescription)", severity: "error", context: "Plugin Scanner - Auto Save")
        }
    }

    #if DEBUG
    /// Preview helper to create a scanner with mock data (for SwiftUI previews only).
    public static func preview(with plugins: [ScannerPluginItem]) -> PluginScanner {
        let s = PluginScanner()
        // Safe to assign here because we're inside the declaring type
        s.plugins = plugins
        s.isScanning = false
        s.progress = 1.0
        s.status = "Preview"
        s.totalToScan = plugins.count
        return s
    }
    #endif
}

