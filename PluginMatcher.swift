//
//  PluginMatcher.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import Foundation

/// Matches parsed plugins from DAW projects with installed plugins
class PluginMatcher {

    // MARK: - Matching

    /// Match a parsed plugin name against installed plugins
    /// Returns the matching PluginItem if found, nil otherwise
    static func findMatch(
        pluginName: String, manufacturer: String, format: PluginFormat, in installedPlugins: [PluginItem]
    ) -> PluginItem? {

        // 1. Try exact name match with same format
        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased() &&
            $0.type.lowercased() == format.rawValue.lowercased()
        }) {
            return match
        }

        // 2. Try exact name match (any format)
        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased()
        }) {
            return match
        }

        // 3. Try name match with manufacturer
        if !manufacturer.isEmpty && manufacturer.lowercased() != "unknown" {
            if let match = installedPlugins.first(where: {
                $0.name.lowercased() == pluginName.lowercased() &&
                $0.publisher.lowercased().contains(manufacturer.lowercased())
            }) {
                return match
            }
        }

        // 4. Try manufacturer prefix match (e.g., "Pro-Q 4" from FabFilter → "FabFilter Pro-Q 4")
        if !manufacturer.isEmpty && manufacturer.lowercased() != "unknown" {
            let combinedName = "\(manufacturer) \(pluginName)"
            if let match = installedPlugins.first(where: {
                $0.name.lowercased() == combinedName.lowercased()
            }) {
                return match
            }
        }

        // 5. Try fuzzy match (remove common suffixes/prefixes)
        let cleanedName = cleanPluginName(pluginName)
        if let match = installedPlugins.first(where: {
            cleanPluginName($0.name).lowercased() == cleanedName.lowercased()
        }) {
            return match
        }

        // 5a. Try fuzzy match with manufacturer prefix
        if !manufacturer.isEmpty && manufacturer.lowercased() != "unknown" {
            let combinedCleanedName = cleanPluginName("\(manufacturer) \(pluginName)")
            if let match = installedPlugins.first(where: {
                cleanPluginName($0.name).lowercased() == combinedCleanedName.lowercased()
            }) {
                return match
            }
        }

        // 6. Try partial match (contains)
        if pluginName.count > 4 { // Avoid matching very short names
            if let match = installedPlugins.first(where: {
                $0.name.lowercased().contains(pluginName.lowercased()) ||
                pluginName.lowercased().contains($0.name.lowercased())
            }) {
                return match
            }
        }

        return nil
    }

    /// Create entries from parsed plugins, matching with installed plugins
    static func createEntries(
        from parsedPlugins: [ParsedPlugin], installedPlugins: [PluginItem]
    ) -> [DAWPlaylistEntry] {

        return parsedPlugins.map { parsed in
            let match = findMatch(
                pluginName: parsed.name, manufacturer: parsed.manufacturer, format: parsed.format, in: installedPlugins
            )

            // Copy metadata from matched plugin if found
            let version = match?.version ?? ""
            let style = match?.style ?? ""
            let architectures = match?.architectures ?? ""

            return DAWPlaylistEntry(
                name: parsed.name, publisher: parsed.manufacturer, trackName: parsed.trackName, trackIndex: parsed.trackIndex, deviceIndex: parsed.deviceIndex, type: parsed.format.rawValue, isInstalled: match != nil, matchedPluginPath: match?.path, version: version, style: style, architectures: architectures
            )
        }
    }

    // MARK: - Name Cleaning

    /// Remove common prefixes/suffixes from plugin names for better matching
    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name

        // Remove common suffixes
        let suffixes = [" VST", " VST3", " AU", " AAX", " x64", " x86", " (VST)", " (VST3)", " (AU)", " (AAX)", " v2", " v3", " v4", " v5", " 2", " 3", " 4", " 5"]

        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }

        // Remove common prefixes
        let prefixes = ["VST:", "VST3:", "AU:", "AAX:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        return cleaned
    }

    // MARK: - Statistics

    struct MatchStats {
        let totalPlugins: Int
        let matchedPlugins: Int
        let missingPlugins: Int
        let matchRate: Double

        var matchPercentage: Int {
            Int(matchRate * 100)
        }
    }

    /// Calculate matching statistics
    static func calculateStats(for entries: [DAWPlaylistEntry]) -> MatchStats {
        let total = entries.count
        let matched = entries.filter { $0.isInstalled }.count
        let missing = total - matched
        let rate = total > 0 ? Double(matched) / Double(total) : 0.0

        return MatchStats(
            totalPlugins: total, matchedPlugins: matched, missingPlugins: missing, matchRate: rate
        )
    }

    // MARK: - Grouping

    /// Group entries by track for display
    static func groupByTrack(_ entries: [DAWPlaylistEntry]) -> [String: [DAWPlaylistEntry]] {
        var grouped: [String: [DAWPlaylistEntry]] = [:]

        for entry in entries {
            if grouped[entry.trackName] == nil {
                grouped[entry.trackName] = []
            }
            grouped[entry.trackName]?.append(entry)
        }

        // Sort plugins within each track by device index
        for trackName in grouped.keys {
            grouped[trackName]?.sort { $0.deviceIndex < $1.deviceIndex }
        }

        return grouped
    }

    /// Get sorted track names (by track index)
    static func sortedTrackNames(_ entries: [DAWPlaylistEntry]) -> [String] {
        let uniqueTracks = Dictionary(grouping: entries, by: { $0.trackName })
            .mapValues { $0.first?.trackIndex ?? 0 }

        return uniqueTracks.sorted { $0.value < $1.value }.map { $0.key }
    }
}