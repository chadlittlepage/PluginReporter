import Foundation

/// Simple LRU cache with memory-aware eviction.
/// Recovered stub — the original was lost (never committed).
final class EnrichmentCacheManager<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    private let maxMemoryBytes: Int
    private var hits = 0
    private var misses = 0

    init(maxSize: Int, maxMemoryMB: Int) {
        self.maxSize = maxSize
        self.maxMemoryBytes = maxMemoryMB * 1024 * 1024
    }

    var hitRate: Double {
        let total = hits + misses
        return total == 0 ? 0.0 : (Double(hits) / Double(total)) * 100.0
    }

    func get(_ key: Key) -> Value? {
        if let value = cache[key] {
            hits += 1
            if let idx = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: idx)
                accessOrder.append(key)
            }
            return value
        }
        misses += 1
        return nil
    }

    func set(_ key: Key, value: Value, estimatedSize: Int = 0) {
        if cache.count >= maxSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        cache[key] = value
        if let idx = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: idx)
        }
        accessOrder.append(key)
    }

    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        hits = 0
        misses = 0
    }

    func getStatistics() -> CacheStatistics {
        CacheStatistics(count: cache.count, maxSize: maxSize, hits: hits, misses: misses, hitRate: hitRate)
    }
}

struct CacheStatistics: CustomStringConvertible {
    let count: Int
    let maxSize: Int
    let hits: Int
    let misses: Int
    let hitRate: Double
    var memoryUsageMB: Double = 0.0
    var evictions: Int = 0

    var description: String {
        "\(count)/\(maxSize) entries, \(hits) hits, \(misses) misses, \(String(format: "%.1f", hitRate))% hit rate, \(String(format: "%.1f", memoryUsageMB))MB, \(evictions) evictions"
    }
}
