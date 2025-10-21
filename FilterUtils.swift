//
//  FilterUtils.swift
//  Plugin Reporter
//
//  Created by Claude on 1/20/25.
//  Shared utilities for efficient filter extraction and plugin filtering
//

import Foundation

/// Utility methods for efficient filtering and unique value extraction
struct FilterUtils {

    // MARK: - Unique Value Extraction

    /// Efficiently extract unique, non-empty values from plugins for a given string keypath
    /// Uses a single-pass algorithm with Set-based deduplication and inline sorting
    static func uniqueValues<T: PluginProtocol>(
        from plugins: [T],
        keyPath: KeyPath<T, String>
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for plugin in plugins {
            let value = plugin[keyPath: keyPath]
            guard !value.isEmpty, seen.insert(value).inserted else { continue }
            result.append(value)
        }

        result.sort()
        return result
    }

    /// Extract unique plugin styles from a collection
    static func uniqueStyles<T: PluginProtocol>(from plugins: [T]) -> [String] {
        uniqueValues(from: plugins, keyPath: \.style)
    }

    /// Extract unique plugin publishers from a collection
    static func uniquePublishers<T: PluginProtocol>(from plugins: [T]) -> [String] {
        uniqueValues(from: plugins, keyPath: \.publisher)
    }

    // MARK: - Plugin Map Building

    /// Build a map of plugin keys to associated metadata (optimized single-pass)
    /// Replaces triple-pass filtering with Set-backed dictionary operations
    static func buildPluginTrackMap(
        from entries: [DAWPlaylistEntry]
    ) -> [String: [String]] {
        var map: [String: Set<String>] = [:]

        for entry in entries {
            let key = makePluginKey(name: entry.pluginName, format: entry.pluginFormat)
            map[key, default: []].insert(entry.trackName)
        }

        // Convert Sets to sorted arrays once at the end
        return map.mapValues { Array($0).sorted() }
    }

    /// Create a standardized plugin key for deduplication
    /// Format: "pluginname_formatrawvalue" (lowercase)
    static func makePluginKey(name: String, format: PluginFormat) -> String {
        "\(name.lowercased())_\(format.rawValue)"
    }

    /// Create a standardized plugin key from string type
    static func makePluginKey(name: String, type: String) -> String {
        "\(name.lowercased())_\(type)"
    }

    // MARK: - Deduplication

    /// Deduplicate plugins by key (name + format) - single pass
    static func deduplicatePlugins<T: PluginProtocol>(
        _ plugins: [T],
        keyExtractor: (T) -> String
    ) -> [T] {
        var seen = Set<String>()
        var result: [T] = []

        for plugin in plugins {
            let key = keyExtractor(plugin)
            guard seen.insert(key).inserted else { continue }
            result.append(plugin)
        }

        return result
    }
}

// MARK: - Protocol for Plugin Types

/// Common protocol for plugin-like objects
/// Ensures FilterUtils can work with PluginItem, AppPluginItem, etc.
protocol PluginProtocol {
    var name: String { get }
    var publisher: String { get }
    var style: String { get }
}

// MARK: - Protocol Conformance

/// PluginItem conforms to PluginProtocol (has all required properties)
extension PluginItem: PluginProtocol {}
