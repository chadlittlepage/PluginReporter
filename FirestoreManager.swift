// FirestoreManager.swift - Firestore Enrichment Data Access
// Add this file to BOTH macOS and iOS targets
import Foundation
import Combine
import FirebaseCore
import FirebaseFirestore

@MainActor
class FirestoreManager: ObservableObject {
    // MARK: - Singleton
    static let shared = FirestoreManager()

    // MARK: - Published Properties
    @Published var enrichmentCache: [String: EnrichedPlugin] = [:]  // Legacy - kept for compatibility
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?

    // MARK: - Private Properties
    private let db: Firestore
    private var cacheExpiry: Date?
    private let cacheTimeout: TimeInterval = 3600  // 1 hour

    // Phase 3: Optimized LRU cache with memory limits
    private let lruCache = EnrichmentCacheManager<String, EnrichedPlugin>(
        maxSize: 2000,      // Max 2000 plugins in memory
        maxMemoryMB: 100    // Max 100MB memory usage
    )

    // Collection names
    private let pluginMetadataCollection = "plugin_metadata"
    private let screenshotsCollection = "plugin_screenshots"
    private let presetsCollection = "presets"
    private let chainsCollection = "plugin_chains"
    private let famousUsesCollection = "plugin_famous_uses"
    private let freePluginsCollection = "free_plugins"  // NEW: Verified free plugins database

    // MARK: - Initialization
    private init() {
        // Firebase is initialized in PluginReporterApp.swift
        self.db = Firestore.firestore()

        // Configure Firestore settings for better performance (using new API)
        // CRITICAL: Settings MUST be configured before any Firestore operations
        // FirestoreManager.shared MUST be initialized before any other service
        // that accesses Firestore (e.g., PluginEnrichmentService)
        let settings = FirestoreSettings()
        #if os(macOS)
        // macOS sandbox containers may retain LevelDB lock files between launches.
        // Use in-memory cache to avoid persistent storage locking the app at startup.
        settings.cacheSettings = MemoryCacheSettings()
        print("✅ FirestoreManager: Configured Firestore with in-memory cache (macOS)")
        #else
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        print("✅ FirestoreManager: Configured Firestore with unlimited persistent cache")
        #endif
        db.settings = settings
    }

    // MARK: - Cache Management

    /// Get cache statistics for monitoring
    func getCacheStatistics() -> CacheStatistics {
        lruCache.getStatistics()
    }

    /// Clear all caches
    func clearCache() {
        lruCache.clear()
        enrichmentCache.removeAll()
        cacheExpiry = nil
        print("🗑️  FirestoreManager: All caches cleared")
    }

    // MARK: - Main Query Methods

    /// Fetch enrichment data for specific plugins by composite keys
    func fetchEnrichment(forKeys keys: [String]) async throws -> [String: EnrichedPlugin] {
        // Phase 3: Check LRU cache first
        var cachedResults: [String: EnrichedPlugin] = [:]
        var keysToFetch: [String] = []

        for key in keys {
            if let cached = lruCache.get(key) {
                cachedResults[key] = cached
            } else {
                keysToFetch.append(key)
            }
        }

        // All found in cache
        if keysToFetch.isEmpty {
            print("✅ FirestoreManager: Returning \(cachedResults.count) plugins from LRU cache (hit rate: \(String(format: "%.1f", lruCache.hitRate))%)")
            return cachedResults
        }

        // Partial cache hit
        if !cachedResults.isEmpty {
            print("📊 FirestoreManager: \(cachedResults.count)/\(keys.count) from cache, fetching \(keysToFetch.count) from Firestore")
        }

        // Fetch missing keys from Firestore
        print("📡 FirestoreManager: Fetching \(keysToFetch.count) plugins from Firestore")
        isLoading = true
        errorMessage = nil

        do {
            let results = try await fetchFromFirestore(keys: keysToFetch)

            // Update LRU cache with new data (estimated 50KB per plugin)
            for (key, plugin) in results {
                lruCache.set(key, value: plugin, estimatedSize: 50 * 1024)
            }

            // Also update legacy cache for compatibility
            enrichmentCache.merge(results) { (_, new) in new }
            cacheExpiry = Date().addingTimeInterval(cacheTimeout)
            lastSyncDate = Date()

            isLoading = false

            // Merge cached and fetched results
            let allResults = cachedResults.merging(results) { (current, _) in current }
            print("✅ FirestoreManager: Returned \(allResults.count) plugins (cache stats: \(lruCache.getStatistics().description))")
            return allResults
        } catch {
            isLoading = false
            errorMessage = "Failed to load enrichment data: \(error.localizedDescription)"
            print("❌ FirestoreManager: Error - \(error)")
            throw error
        }
    }

    /// Fetch ALL plugins from Firestore (for Browse view)
    func fetchAllPlugins() async throws -> [EnrichedPlugin] {
        print("📡 FirestoreManager: Fetching all plugins from Firestore")
        isLoading = true
        errorMessage = nil

        do {
            let snapshot = try await db.collection(pluginMetadataCollection).getDocuments()

            var plugins = snapshot.documents.compactMap { doc -> EnrichedPlugin? in
                try? doc.data(as: EnrichedPlugin.self)
            }

            // Fetch ALL presets in bulk (more efficient than individual queries)
            print("📦 Fetching presets for all plugins...")
            let presetsSnapshot = try await db.collection(presetsCollection).getDocuments()
            let allPresets = presetsSnapshot.documents.compactMap { doc -> FirestorePreset? in
                try? doc.data(as: FirestorePreset.self)
            }

            // Create a lookup dictionary for quick preset matching
            var presetsByPlugin: [String: [FirestorePreset]] = [:]
            for preset in allPresets {
                let key = "\(preset.pluginName)_\(preset.publisher)".lowercased()
                presetsByPlugin[key, default: []].append(preset)
            }

            // Assign presets to plugins
            for i in 0..<plugins.count {
                let key = "\(plugins[i].name)_\(plugins[i].publisher)".lowercased()
                if let presets = presetsByPlugin[key] {
                    plugins[i].presets = presets
                }
            }

            print("✅ Loaded \(allPresets.count) total presets across \(presetsByPlugin.count) plugins")

            // Cache all plugins
            for plugin in plugins {
                enrichmentCache[plugin.compositeKey] = plugin
            }
            cacheExpiry = Date().addingTimeInterval(cacheTimeout)
            lastSyncDate = Date()

            isLoading = false
            print("✅ FirestoreManager: Fetched \(plugins.count) total plugins")
            return plugins
        } catch {
            isLoading = false
            errorMessage = "Failed to load all plugins: \(error.localizedDescription)"
            print("❌ FirestoreManager: Error - \(error)")
            throw error
        }
    }

    /// Fetch detailed data for a single plugin (lazy loading)
    func fetchPluginDetails(forKey key: String) async throws -> EnrichedPlugin {
        print("📡 FirestoreManager: Fetching details for \(key)")

        // Check cache first
        if let cached = enrichmentCache[key], isCacheValid() {
            print("✅ FirestoreManager: Returning cached details for \(key)")
            return cached
        }

        // Extract name and publisher from composite key
        let components = key.components(separatedBy: "_")
        guard components.count >= 2 else {
            throw FirestoreError.invalidKey
        }

        let name = components.dropLast().joined(separator: "_")
        let publisher = components.last!

        // Query plugin_metadata
        let metadataQuery = db.collection(pluginMetadataCollection)
            .whereField("name", isEqualTo: name)
            .whereField("publisher", isEqualTo: publisher)
            .limit(to: 1)

        let metadataSnapshot = try await metadataQuery.getDocuments()

        guard let metadataDoc = metadataSnapshot.documents.first else {
            throw FirestoreError.pluginNotFound
        }

        var plugin = try metadataDoc.data(as: EnrichedPlugin.self)

        // Load related data in parallel
        async let screenshots = fetchScreenshots(name: name, publisher: publisher)
        async let presets = fetchPresets(name: name, publisher: publisher)
        async let chains = fetchChains(name: name, publisher: publisher)
        async let famousUses = fetchFamousUses(name: name, publisher: publisher)

        let (screenshot, presetsList, chainsList, usesList) = try await (screenshots, presets, chains, famousUses)

        plugin.screenshot = screenshot
        plugin.presets = presetsList
        plugin.chains = chainsList
        plugin.famousUses = usesList

        // Cache the complete plugin
        enrichmentCache[key] = plugin
        cacheExpiry = Date().addingTimeInterval(cacheTimeout)

        print("✅ FirestoreManager: Loaded complete details for \(key)")
        return plugin
    }

    // MARK: - Private Helper Methods

    private func fetchFromFirestore(keys: [String]) async throws -> [String: EnrichedPlugin] {
        var results: [String: EnrichedPlugin] = [:]

        // Firestore has a limit of 10 items per "in" query, so batch them
        let batches = keys.chunked(into: 10)

        for batch in batches {
            // Create queries for each name/publisher pair
            for key in batch {
                let components = key.components(separatedBy: "_")
                guard components.count >= 2 else { continue }

                let name = components.dropLast().joined(separator: "_")
                let publisher = components.last!

                let query = db.collection(pluginMetadataCollection)
                    .whereField("name", isEqualTo: name)
                    .whereField("publisher", isEqualTo: publisher)
                    .limit(to: 1)

                let snapshot = try await query.getDocuments()

                if let doc = snapshot.documents.first,
                   var plugin = try? doc.data(as: EnrichedPlugin.self) {

                    // IMPORTANT: Also fetch presets for this plugin
                    // Presets are stored in a separate collection for performance
                    do {
                        let presets = try await fetchPresets(name: name, publisher: publisher)
                        plugin.presets = presets

                        if !presets.isEmpty {
                            print("📦 Loaded \(presets.count) presets for \(name)")
                        }
                    } catch {
                        print("⚠️ Failed to load presets for \(name): \(error.localizedDescription)")
                    }

                    results[key] = plugin
                }
            }
        }

        return results
    }

    private func fetchScreenshots(name: String, publisher: String) async throws -> PluginScreenshot? {
        let query = db.collection(screenshotsCollection)
            .whereField("pluginName", isEqualTo: name)
            .whereField("publisher", isEqualTo: publisher)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: PluginScreenshot.self) }
    }

    private func fetchPresets(name: String, publisher: String) async throws -> [FirestorePreset] {
        let query = db.collection(presetsCollection)
            .whereField("pluginName", isEqualTo: name)
            .whereField("publisher", isEqualTo: publisher)

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestorePreset.self) }
    }

    private func fetchChains(name: String, publisher: String) async throws -> [FirestorePluginChain] {
        // Query chains where this plugin appears
        let query = db.collection(chainsCollection)
            .whereField("plugins", arrayContains: ["pluginName": name, "publisher": publisher])

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestorePluginChain.self) }
    }

    private func fetchFamousUses(name: String, publisher: String) async throws -> [FirestoreFamousUse] {
        let query = db.collection(famousUsesCollection)
            .whereField("pluginName", isEqualTo: name)
            .whereField("publisher", isEqualTo: publisher)

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreFamousUse.self) }
    }

    // MARK: - Auto-Discovery (Write Methods)

    /// Submit a new plugin to Firestore (crowd-sourced discovery)
    /// Only submits if plugin doesn't already exist (no duplicates)
    /// Runs silently in background - no user-facing output
    func submitNewPluginIfNeeded(plugin: PluginItem) async throws -> Bool {
        let key = "\(plugin.name)_\(plugin.publisher)".lowercased()

        // Check cache first (fast path)
        if let _ = enrichmentCache[key] {
            return false
        }

        // Double-check in Firestore (cache might be stale)
        let query = db.collection(pluginMetadataCollection)
            .whereField("name", isEqualTo: plugin.name)
            .whereField("publisher", isEqualTo: plugin.publisher)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()

        if !snapshot.documents.isEmpty {
            return false
        }

        // Plugin doesn't exist - submit it silently
        let pluginData: [String: Any] = [
            "name": plugin.name,
            "publisher": plugin.publisher,
            "displayName": plugin.name,
            "version": plugin.version,
            "type": plugin.type,
            "enrichmentStatus": "pending",
            "discoveredAt": Timestamp(date: Date()),
            "discoveredBy": "auto-discovery",
            "discoverySource": "user-scan",
            "path": plugin.path
        ]

        // Add to plugin_metadata
        let docRef = try await db.collection(pluginMetadataCollection).addDocument(data: pluginData)

        // Add to enrichment queue
        let queueData: [String: Any] = [
            "pluginId": docRef.documentID,
            "pluginName": plugin.name,
            "publisher": plugin.publisher,
            "status": "pending",
            "priority": 50,
            "queuedAt": Timestamp(date: Date()),
            "submittedBy": "auto-discovery"
        ]

        _ = try await db.collection("enrichment_queue").addDocument(data: queueData)

        return true
    }

    /// Batch submit multiple new plugins (called after scan)
    /// Runs silently in background - no user-facing output
    func submitNewPlugins(_ plugins: [PluginItem]) async -> (submitted: Int, skipped: Int) {
        var submitted = 0
        var skipped = 0

        for plugin in plugins {
            do {
                let wasSubmitted = try await submitNewPluginIfNeeded(plugin: plugin)
                if wasSubmitted {
                    submitted += 1
                } else {
                    skipped += 1
                }
            } catch {
                // Silently skip errors - don't interrupt user experience
                skipped += 1
            }
        }

        return (submitted, skipped)
    }

    // MARK: - Cache Management

    private func isCacheValid() -> Bool {
        guard let expiry = cacheExpiry else { return false }
        return Date() < expiry
    }

    func refreshCache() async throws {
        clearCache()
        _ = try await fetchAllPlugins()
    }

    // MARK: - Free Plugins Database

    /// Fetch verified free plugins for a specific category from Firebase
    /// This provides INSTANT results instead of slow AI verification
    func fetchFreePlugins(category: String) async throws -> [FreePlugin] {
        print("📡 FirestoreManager: Fetching verified free plugins for '\(category)' from Firebase")

        let query = db.collection(freePluginsCollection)
            .whereField("category", isEqualTo: category.lowercased())
            .whereField("verified", isEqualTo: true)

        let snapshot = try await query.getDocuments()

        let plugins = snapshot.documents.compactMap { doc -> FreePlugin? in
            try? doc.data(as: FreePlugin.self)
        }

        print("✅ FirestoreManager: Found \(plugins.count) verified free plugins for '\(category)'")
        return plugins
    }

    /// Save a verified free plugin to Firebase
    /// This builds up our database over time
    func saveFreePlugin(name: String, category: String, reason: String, developer: String) async throws {
        // Check if plugin already exists to avoid duplicates
        let query = db.collection(freePluginsCollection)
            .whereField("name", isEqualTo: name)
            .whereField("category", isEqualTo: category.lowercased())
            .limit(to: 1)

        let existing = try await query.getDocuments()

        if !existing.documents.isEmpty {
            print("⚠️ FirestoreManager: Plugin '\(name)' already exists in '\(category)' - skipping")
            return
        }

        let plugin = FreePlugin(
            name: name,
            category: category.lowercased(),
            reason: reason,
            developer: developer,
            verified: true,
            verifiedDate: Timestamp(date: Date())
        )

        try await db.collection(freePluginsCollection).addDocument(from: plugin)
        print("✅ FirestoreManager: Saved verified free plugin: '\(name)' to '\(category)'")
    }

    /// Batch save multiple free plugins (more efficient)
    func saveFreePlugins(_ plugins: [(name: String, category: String, reason: String, developer: String)]) async throws {
        print("📦 FirestoreManager: Batch saving \(plugins.count) verified free plugins")

        var saved = 0
        var skipped = 0

        for plugin in plugins {
            do {
                try await saveFreePlugin(
                    name: plugin.name,
                    category: plugin.category,
                    reason: plugin.reason,
                    developer: plugin.developer
                )
                saved += 1
            } catch {
                skipped += 1
            }
        }

        print("✅ FirestoreManager: Batch complete - saved: \(saved), skipped: \(skipped)")
    }

    /// Get count of verified free plugins for a category
    func getFreePluginCount(category: String) async throws -> Int {
        let query = db.collection(freePluginsCollection)
            .whereField("category", isEqualTo: category.lowercased())
            .whereField("verified", isEqualTo: true)

        let snapshot = try await query.getDocuments()
        return snapshot.documents.count
    }

    /// Get all categories that have free plugins
    func getFreePluginCategories() async throws -> [String: Int] {
        let snapshot = try await db.collection(freePluginsCollection)
            .whereField("verified", isEqualTo: true)
            .getDocuments()

        var categoryCounts: [String: Int] = [:]
        for doc in snapshot.documents {
            if let category = try? doc.data(as: FreePlugin.self).category {
                categoryCounts[category, default: 0] += 1
            }
        }

        return categoryCounts
    }
}

// MARK: - Free Plugin Model

struct FreePlugin: Codable {
    let name: String
    let category: String  // "reverb", "eq", "compressor", etc.
    let reason: String    // Why it's good/free
    let developer: String // Plugin developer/company
    let verified: Bool    // Always true for saved plugins
    let verifiedDate: Timestamp
}

// MARK: - Error Types

enum FirestoreError: LocalizedError {
    case invalidKey
    case pluginNotFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid plugin key format"
        case .pluginNotFound:
            return "Plugin not found in database"
        case .networkError:
            return "Network connection error"
        }
    }
}
