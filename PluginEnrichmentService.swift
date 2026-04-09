import Foundation
import SwiftUI

/// Orchestrates enrichment fetching from Firestore for plugin metadata.
/// Recovered stub — the original was lost (never committed).
final class PluginEnrichmentService: ObservableObject {

    static let shared = PluginEnrichmentService()
    private init() {}

    /// Batch-fetch enrichment data for an array of plugins, mutating them in place.
    func batchFetchEnrichment(for plugins: inout [PluginItem]) async {
        let firestoreManager = FirestoreManager.shared
        let keys = plugins.map { "\($0.name)|\($0.publisher)" }
        do {
            let enrichmentMap = try await firestoreManager.fetchEnrichment(forKeys: keys)
            var enriched = 0
            for i in plugins.indices {
                let key = "\(plugins[i].name)|\(plugins[i].publisher)"
                if let data = enrichmentMap[key] {
                    plugins[i].screenshotUrl = data.screenshotUrl ?? data.screenshot?.screenshotUrl
                    plugins[i].thumbnailUrl = data.screenshot?.thumbnailUrl
                    enriched += 1
                }
            }
            print("✅ PluginEnrichmentService: Enriched \(enriched)/\(plugins.count) plugins")
        } catch {
            print("⚠️ PluginEnrichmentService: Enrichment failed — \(error.localizedDescription)")
        }
    }

    /// Lazy-load extended enrichment data for a single plugin (detail panel).
    func lazyLoadExtendedData(for plugin: inout PluginItem) async {
        let key = "\(plugin.name)|\(plugin.publisher)"
        do {
            let enrichmentMap = try await FirestoreManager.shared.fetchEnrichment(forKeys: [key])
            if let data = enrichmentMap[key] {
                plugin.screenshotUrl = data.screenshotUrl ?? data.screenshot?.screenshotUrl
                plugin.thumbnailUrl = data.screenshot?.thumbnailUrl
            }
        } catch {
            print("⚠️ PluginEnrichmentService: lazyLoad failed — \(error.localizedDescription)")
        }
    }
}
