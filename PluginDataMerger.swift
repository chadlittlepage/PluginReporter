// PluginDataMerger.swift - Merges CloudKit + Firestore Data
// Add this file to BOTH macOS and iOS targets
import Foundation
import SwiftUI
import Combine

@MainActor
class PluginDataMerger: ObservableObject {
    // MARK: - Published Properties
    @Published var mergedPlugins: [MergedPlugin] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var loadingProgress: Double = 0.0
    @Published var statistics: MergeStatistics = MergeStatistics()

    // MARK: - Private Properties
    private let cloudKitManager: CloudSyncManager
    private let firestoreManager: FirestoreManager

    // Phase 3: Intelligent batch loading
    private var optimalBatchSize: Int = 100  // Start with 100, adjust based on performance
    private var lastBatchTime: TimeInterval = 0
    private let maxBatchSize: Int = 500
    private let minBatchSize: Int = 50

    // MARK: - Initialization
    init(cloudKit: CloudSyncManager, firestore: FirestoreManager) {
        self.cloudKitManager = cloudKit
        self.firestoreManager = firestore
    }

    // MARK: - Main Merge Methods

    /// Load scanned plugins and merge with enrichment (for use with PluginScanner)
    func loadScannedPlugins(_ scannedPlugins: [PluginItem]) async {
        print("🔄 PluginDataMerger: Loading scanned plugins...")
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.0

        do {
            guard !scannedPlugins.isEmpty else {
                print("ℹ️ No plugins scanned yet")
                isLoading = false
                mergedPlugins = []
                updateStatistics()
                return
            }

            print("✅ Found \(scannedPlugins.count) scanned plugins")
            loadingProgress = 0.2

            // Step 2: Create composite keys (40% progress)
            print("🔑 Step 2: Creating composite keys...")
            let compositeKeys = scannedPlugins.map { plugin in
                "\(plugin.name)_\(plugin.publisher)".lowercased()
            }
            loadingProgress = 0.4

            // Step 3: Fetch enrichment data from Firestore (80% progress)
            print("📡 Step 3: Fetching enrichment data...")
            let enrichmentData = try await firestoreManager.fetchEnrichment(forKeys: compositeKeys)
            loadingProgress = 0.8

            // Step 4: Merge data (100% progress)
            print("🔀 Step 4: Merging data...")
            mergedPlugins = scannedPlugins.map { scannedPlugin in
                let key = "\(scannedPlugin.name)_\(scannedPlugin.publisher)".lowercased()
                let enrichment = enrichmentData[key]

                return MergedPlugin(
                    pluginItem: scannedPlugin,
                    enrichment: enrichment
                )
            }

            loadingProgress = 1.0
            isLoading = false
            updateStatistics()

            print("✅ PluginDataMerger: Loaded \(mergedPlugins.count) merged plugins")
            print("   - Installed: \(mergedPlugins.filter { $0.isInstalled }.count)")
            print("   - Enriched: \(mergedPlugins.filter { $0.isEnriched }.count)")

        } catch {
            isLoading = false
            errorMessage = "Failed to load plugins: \(error.localizedDescription)"
            print("❌ PluginDataMerger: Error - \(error)")
        }
    }

    /// Load user's installed plugins and merge with enrichment
    func loadUserPlugins() async {
        print("🔄 PluginDataMerger: Loading user's plugins...")
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.0

        do {
            // Step 1: Load user's plugins from CloudKit (20% progress)
            print("📱 Step 1: Loading from CloudKit...")
            await cloudKitManager.syncFromCloud()
            let userPlugins = cloudKitManager.plugins
            loadingProgress = 0.2

            guard !userPlugins.isEmpty else {
                print("ℹ️ No plugins installed yet")
                isLoading = false
                mergedPlugins = []
                updateStatistics()
                return
            }

            print("✅ Found \(userPlugins.count) installed plugins")

            // Step 2: Create composite keys (40% progress)
            print("🔑 Step 2: Creating composite keys...")
            let compositeKeys = userPlugins.map { plugin in
                "\(plugin.name)_\(plugin.publisher)".lowercased()
            }
            loadingProgress = 0.4

            // Step 3: Fetch enrichment data from Firestore (80% progress)
            print("📡 Step 3: Fetching enrichment data...")
            let enrichmentData = try await firestoreManager.fetchEnrichment(forKeys: compositeKeys)
            loadingProgress = 0.8

            // Step 4: Merge data (100% progress)
            print("🔀 Step 4: Merging data...")
            mergedPlugins = userPlugins.map { userPlugin in
                let key = "\(userPlugin.name)_\(userPlugin.publisher)".lowercased()
                let enrichment = enrichmentData[key]

                return MergedPlugin(
                    pluginItem: userPlugin,
                    enrichment: enrichment
                )
            }

            // Sort by name
            mergedPlugins.sort { $0.displayName < $1.displayName }

            loadingProgress = 1.0
            isLoading = false

            // Update statistics
            updateStatistics()

            print("✅ PluginDataMerger: Loaded \(mergedPlugins.count) merged plugins")
            print("   - Installed: \(mergedPlugins.filter { $0.isInstalled }.count)")
            print("   - Enriched: \(mergedPlugins.filter { $0.isEnriched }.count)")

            // Log performance metrics for Phase 3 monitoring
            logPerformanceMetrics()

            // Auto-discovery: Run silently in background (non-blocking)
            Task.detached { [weak firestoreManager, userPlugins] in
                guard let firestoreManager = firestoreManager else { return }
                _ = await firestoreManager.submitNewPlugins(userPlugins)
            }

            // Background pre-loading: Pre-load enrichment data for better cache hit rates
            await backgroundPreloadEnrichment()

        } catch {
            isLoading = false
            errorMessage = "Failed to load plugins: \(error.localizedDescription)"
            print("❌ PluginDataMerger: Error - \(error)")
        }
    }

    /// Load ALL plugins from Firestore and mark which ones user has installed
    func loadAllPlugins() async {
        print("🔄 PluginDataMerger: Loading all plugins...")
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.0

        do {
            // Step 1: Load ALL plugins from Firestore (60% progress)
            print("📡 Step 1: Loading all plugins from Firestore...")
            let allEnrichment = try await firestoreManager.fetchAllPlugins()
            loadingProgress = 0.6

            // Step 2: Load user's installed plugins from CloudKit (80% progress)
            print("📱 Step 2: Loading user's installed plugins...")
            await cloudKitManager.syncFromCloud()
            let userPlugins = cloudKitManager.plugins
            loadingProgress = 0.8

            // Step 3: Create lookup map (90% progress)
            print("🔑 Step 3: Creating lookup map...")
            let installedPluginsMap: [String: PluginItem] = Dictionary(
                uniqueKeysWithValues: userPlugins.map { plugin in
                    let key = "\(plugin.name)_\(plugin.publisher)".lowercased()
                    return (key, plugin)
                }
            )
            loadingProgress = 0.9

            // Step 4: Merge (100% progress)
            print("🔀 Step 4: Merging all plugins with installation status...")
            mergedPlugins = allEnrichment.map { enrichedPlugin in
                let key = enrichedPlugin.compositeKey

                if let userPlugin = installedPluginsMap[key] {
                    // User has this plugin installed
                    return MergedPlugin(
                        pluginItem: userPlugin,
                        enrichment: enrichedPlugin
                    )
                } else {
                    // User doesn't have this plugin
                    return MergedPlugin(from: enrichedPlugin)
                }
            }

            // Sort by name
            mergedPlugins.sort { $0.displayName < $1.displayName }

            loadingProgress = 1.0
            isLoading = false

            // Update statistics
            updateStatistics()

            print("✅ PluginDataMerger: Loaded \(mergedPlugins.count) total plugins")
            print("   - Installed: \(mergedPlugins.filter { $0.isInstalled }.count)")
            print("   - Not Installed: \(mergedPlugins.filter { !$0.isInstalled }.count)")
            print("   - Enriched: \(mergedPlugins.filter { $0.isEnriched }.count)")

        } catch {
            isLoading = false
            errorMessage = "Failed to load all plugins: \(error.localizedDescription)"
            print("❌ PluginDataMerger: Error - \(error)")
        }
    }

    /// Reload/refresh data
    func refresh() async {
        // Check which mode we're in based on current data
        if mergedPlugins.allSatisfy({ $0.isInstalled }) {
            // All plugins are installed - we're in "My Plugins" mode
            await loadUserPlugins()
        } else {
            // We're in "Browse All" mode
            await loadAllPlugins()
        }
    }

    // MARK: - Filtering Methods

    /// Filter plugins by various criteria
    func filterPlugins(
        showInstalled: Bool? = nil,
        showEnriched: Bool? = nil,
        category: String? = nil,
        publisher: String? = nil,
        searchText: String? = nil
    ) -> [MergedPlugin] {
        var filtered = mergedPlugins

        // Filter by installation status
        if let showInstalled = showInstalled {
            filtered = filtered.filter { $0.isInstalled == showInstalled }
        }

        // Filter by enrichment status
        if let showEnriched = showEnriched {
            filtered = filtered.filter { $0.isEnriched == showEnriched }
        }

        // Filter by category
        if let category = category, !category.isEmpty {
            filtered = filtered.filter { $0.category == category }
        }

        // Filter by publisher
        if let publisher = publisher, !publisher.isEmpty {
            filtered = filtered.filter { $0.publisher == publisher }
        }

        // Search
        if let searchText = searchText, !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            filtered = filtered.filter { plugin in
                plugin.displayName.lowercased().contains(lowercased) ||
                plugin.publisher.lowercased().contains(lowercased) ||
                (plugin.description?.lowercased().contains(lowercased) ?? false)
            }
        }

        return filtered
    }

    /// Get unique categories from all plugins
    func getCategories() -> [String] {
        let categories = Set(mergedPlugins.compactMap { $0.category })
        return Array(categories).sorted()
    }

    /// Get unique publishers from all plugins
    func getPublishers() -> [String] {
        let publishers = Set(mergedPlugins.map { $0.publisher })
        return Array(publishers).sorted()
    }

    // MARK: - Phase 3: Adaptive Batch Loading

    /// Fetch enrichment data with intelligent batching based on network performance
    private func fetchWithAdaptiveBatching(keys: [String]) async throws -> [String: EnrichedPlugin] {
        guard !keys.isEmpty else { return [:] }

        // If total keys < batch size, fetch all at once
        if keys.count <= optimalBatchSize {
            return try await firestoreManager.fetchEnrichment(forKeys: keys)
        }

        print("📦 Using adaptive batching: \(keys.count) keys in batches of ~\(optimalBatchSize)")

        var allResults: [String: EnrichedPlugin] = [:]
        let batches = keys.chunked(into: optimalBatchSize)

        for (index, batch) in batches.enumerated() {
            let batchStart = Date()

            let batchResults = try await firestoreManager.fetchEnrichment(forKeys: batch)
            allResults.merge(batchResults) { (_, new) in new }

            let batchDuration = Date().timeIntervalSince(batchStart)
            print("✅ Batch \(index + 1)/\(batches.count): \(batch.count) keys in \(String(format: "%.2f", batchDuration))s")

            // Small delay between batches to avoid overwhelming Firestore
            if index < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        return allResults
    }

    /// Adjust batch size based on performance
    private func adjustBatchSize(duration: TimeInterval, itemCount: Int) {
        guard itemCount > 0 else { return }

        let timePerItem = duration / Double(itemCount)

        // If fetching is fast (< 0.01s per item), increase batch size
        if timePerItem < 0.01 && optimalBatchSize < maxBatchSize {
            optimalBatchSize = min(optimalBatchSize + 50, maxBatchSize)
            print("📈 Increased batch size to \(optimalBatchSize) (fast network)")
        }
        // If fetching is slow (> 0.05s per item), decrease batch size
        else if timePerItem > 0.05 && optimalBatchSize > minBatchSize {
            optimalBatchSize = max(optimalBatchSize - 25, minBatchSize)
            print("📉 Decreased batch size to \(optimalBatchSize) (slow network)")
        }

        lastBatchTime = duration
    }

    // MARK: - Background Pre-loading

    /// Pre-load enrichment data in background for better cache hit rates
    /// This runs silently and doesn't block the UI
    private func backgroundPreloadEnrichment() async {
        // Only pre-load if we have merged plugins
        guard !mergedPlugins.isEmpty else { return }

        Task.detached { [weak self, weak firestoreManager] in
            guard let self = self, let firestoreManager = firestoreManager else { return }

            // Get plugins that aren't enriched yet (likely not in cache)
            let unenrichedPlugins = await self.mergedPlugins.filter { !$0.isEnriched }

            // Limit pre-loading to top 50 plugins to avoid overwhelming the system
            let pluginsToPreload = Array(unenrichedPlugins.prefix(50))

            guard !pluginsToPreload.isEmpty else { return }

            print("🔮 Background pre-loading: Starting pre-load of \(pluginsToPreload.count) plugins")

            // Create composite keys
            let keys = pluginsToPreload.map { plugin in
                "\(plugin.displayName)_\(plugin.publisher)".lowercased()
            }

            // Pre-load in background (errors are silently ignored)
            do {
                let _ = try await firestoreManager.fetchEnrichment(forKeys: keys)
                print("✅ Background pre-loading: Completed \(keys.count) plugins")
            } catch {
                // Silently fail - this is background work
                print("⚠️ Background pre-loading: Failed (non-critical) - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Performance Monitoring

    /// Log performance metrics for monitoring cache and batch performance
    func logPerformanceMetrics() {
        let cacheStats = firestoreManager.getCacheStatistics()

        print("""

        📊 Performance Metrics (Phase 3):
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Cache Performance:
          • Hit Rate: \(String(format: "%.1f", cacheStats.hitRate))%
          • Cache Entries: \(cacheStats.count)
          • Memory Usage: \(String(format: "%.2f", cacheStats.memoryUsageMB)) MB
          • Hits: \(cacheStats.hits)
          • Misses: \(cacheStats.misses)
          • Evictions: \(cacheStats.evictions)

        Batch Loading:
          • Current Batch Size: \(optimalBatchSize)
          • Last Batch Time: \(String(format: "%.2f", lastBatchTime))s

        Plugin Stats:
          • Total Plugins: \(statistics.totalPlugins)
          • Enriched: \(statistics.enrichedPlugins) (\(String(format: "%.1f", statistics.enrichmentPercentage))%)
          • Installed: \(statistics.installedPlugins) (\(String(format: "%.1f", statistics.installationPercentage))%)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """)
    }

    /// Get current performance metrics as a dictionary (for analytics/debugging)
    func getPerformanceMetrics() -> [String: Any] {
        let cacheStats = firestoreManager.getCacheStatistics()

        return [
            "cache_hit_rate": cacheStats.hitRate,
            "cache_entries": cacheStats.count,
            "cache_memory_mb": cacheStats.memoryUsageMB,
            "cache_hits": cacheStats.hits,
            "cache_misses": cacheStats.misses,
            "cache_evictions": cacheStats.evictions,
            "batch_size": optimalBatchSize,
            "last_batch_time": lastBatchTime,
            "total_plugins": statistics.totalPlugins,
            "enriched_plugins": statistics.enrichedPlugins,
            "enrichment_percentage": statistics.enrichmentPercentage
        ]
    }

    // MARK: - Statistics

    private func updateStatistics() {
        statistics = MergeStatistics(
            totalPlugins: mergedPlugins.count,
            installedPlugins: mergedPlugins.filter { $0.isInstalled }.count,
            enrichedPlugins: mergedPlugins.filter { $0.isEnriched }.count,
            withScreenshots: mergedPlugins.filter { $0.hasScreenshot }.count,
            withFamousUses: mergedPlugins.filter { $0.famousUsesCount > 0 }.count,
            withPresets: mergedPlugins.filter { $0.presetsCount > 0 }.count,
            withChains: mergedPlugins.filter { $0.chainsCount > 0 }.count,
            categories: getCategories().count,
            publishers: getPublishers().count
        )
    }
}

// MARK: - Statistics Model

struct MergeStatistics {
    var totalPlugins: Int = 0
    var installedPlugins: Int = 0
    var enrichedPlugins: Int = 0
    var withScreenshots: Int = 0
    var withFamousUses: Int = 0
    var withPresets: Int = 0
    var withChains: Int = 0
    var categories: Int = 0
    var publishers: Int = 0

    var enrichmentPercentage: Double {
        guard totalPlugins > 0 else { return 0 }
        return Double(enrichedPlugins) / Double(totalPlugins) * 100
    }

    var installationPercentage: Double {
        guard totalPlugins > 0 else { return 0 }
        return Double(installedPlugins) / Double(totalPlugins) * 100
    }
}
