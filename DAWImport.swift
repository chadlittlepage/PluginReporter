//
//  DAWImport.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//
//  Combined DAW Import functionality for macOS
//

#if os(macOS)

import Foundation

// Note: DAWPlaylist, DAWPlaylistEntry, DAWType are defined in DAWPlaylistManager.swift
// Note: AbletonLiveParser is defined in AbletonLiveParser.swift
// Note: PluginFormat is defined in PluginItem.swift

// MARK: - Plugin Matcher

/// Matches parsed plugins from DAW projects with installed plugins
class PluginMatcher {

    static func findMatch(
        pluginName: String,
        manufacturer: String,
        format: PluginFormat,
        in installedPlugins: [PluginItem]
    ) -> PluginItem? {

        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased() &&
            $0.type.lowercased() == format.rawValue.lowercased()
        }) {
            return match
        }

        if let match = installedPlugins.first(where: {
            $0.name.lowercased() == pluginName.lowercased()
        }) {
            return match
        }

        if !manufacturer.isEmpty && manufacturer.lowercased() != "unknown" {
            if let match = installedPlugins.first(where: {
                $0.name.lowercased() == pluginName.lowercased() &&
                $0.publisher.lowercased().contains(manufacturer.lowercased())
            }) {
                return match
            }
        }

        let cleanedName = cleanPluginName(pluginName)
        if let match = installedPlugins.first(where: {
            cleanPluginName($0.name).lowercased() == cleanedName.lowercased()
        }) {
            return match
        }

        if pluginName.count > 4 {
            if let match = installedPlugins.first(where: {
                $0.name.lowercased().contains(pluginName.lowercased()) ||
                pluginName.lowercased().contains($0.name.lowercased())
            }) {
                return match
            }
        }

        return nil
    }

    static func createEntries(
        from parsedPlugins: [ParsedPlugin],
        installedPlugins: [PluginItem]
    ) -> [DAWPlaylistEntry] {

        // BUILD FAST LOOKUP DICTIONARIES - O(n) instead of O(n*m)!
        let nameFormatMap: [String: PluginItem] = Dictionary(
            installedPlugins.map { plugin in
                let key = "\(plugin.name.lowercased())_\(plugin.type.lowercased())"
                return (key, plugin)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let nameOnlyMap: [String: PluginItem] = Dictionary(
            installedPlugins.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Fast matching using dictionaries instead of linear search
        return parsedPlugins.map { parsed in
            var match: PluginItem? = nil

            // Try exact name + format match (FAST O(1) lookup)
            let nameFormatKey = "\(parsed.name.lowercased())_\(parsed.format.rawValue.lowercased())"
            match = nameFormatMap[nameFormatKey]

            // Try name-only match
            if match == nil {
                match = nameOnlyMap[parsed.name.lowercased()]
            }

            // Fall back to slow search only if needed
            if match == nil {
                match = findMatch(
                    pluginName: parsed.name,
                    manufacturer: parsed.manufacturer,
                    format: parsed.format,
                    in: installedPlugins
                )
            }

            return DAWPlaylistEntry(
                pluginName: parsed.name,
                pluginManufacturer: parsed.manufacturer,
                trackName: parsed.trackName,
                trackIndex: parsed.trackIndex,
                deviceIndex: parsed.deviceIndex,
                pluginFormat: parsed.format,
                isInstalled: match != nil,
                matchedPluginPath: match?.path
            )
        }
    }

    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name

        let suffixes = [" VST", " VST3", " AU", " AAX", " x64", " x86",
                       " (VST)", " (VST3)", " (AU)", " (AAX)",
                       " v2", " v3", " v4", " v5",
                       " 2", " 3", " 4", " 5"]

        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
            }
        }

        let prefixes = ["VST:", "VST3:", "AU:", "AAX:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        return cleaned
    }

    struct MatchStats {
        let totalPlugins: Int
        let matchedPlugins: Int
        let missingPlugins: Int
        let matchRate: Double

        var matchPercentage: Int {
            Int(matchRate * 100)
        }
    }

    static func calculateStats(for entries: [DAWPlaylistEntry]) -> MatchStats {
        let total = entries.count
        let matched = entries.filter { $0.isInstalled }.count
        let missing = total - matched
        let rate = total > 0 ? Double(matched) / Double(total) : 0.0

        return MatchStats(
            totalPlugins: total,
            matchedPlugins: matched,
            missingPlugins: missing,
            matchRate: rate
        )
    }
}

#endif
