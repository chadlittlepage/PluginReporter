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
        pluginName: String, manufacturer: String, format: PluginFormat, in installedPlugins: [PluginItem]
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
        from parsedPlugins: [ParsedPlugin], installedPlugins: [PluginItem]
    ) -> [DAWPlaylistEntry] {

        print("🎯 [MATCHER] Creating DAWPlaylistEntries from \(parsedPlugins.count) parsed plugins")
        print("   • Installed plugins available: \(installedPlugins.count)")

        // BUILD FAST LOOKUP DICTIONARIES - O(n) instead of O(n*m)!
        let nameFormatMap: [String: PluginItem] = Dictionary(
            installedPlugins.map { plugin in
                let key = "\(plugin.name.lowercased())_\(plugin.type.lowercased())"
                return (key, plugin)
            }, uniquingKeysWith: { first, _ in first }
        )

        let nameOnlyMap: [String: PluginItem] = Dictionary(
            installedPlugins.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first }
        )

        // Fast matching using dictionaries instead of linear search
        return parsedPlugins.enumerated().map { (index, parsed) in
            print("\n🔄 [MATCHER] Processing plugin #\(index + 1):")
            print("   📥 INPUT from Parser:")
            print("      • name: '\(parsed.name)'")
            print("      • publisher: '\(parsed.publisher)'")
            print("      • type: '\(parsed.type)'")
            print("      • track: '\(parsed.trackName)'")

            var match: PluginItem?

            // Try exact name + type match (FAST O(1) lookup)
            let nameTypeKey = "\(parsed.name.lowercased())_\(parsed.type.lowercased())"
            match = nameFormatMap[nameTypeKey]

            if match != nil {
                print("   ✅ EXACT match found (name + type)")
            }

            // Try name-only match
            if match == nil {
                match = nameOnlyMap[parsed.name.lowercased()]
                if match != nil {
                    print("   ⚠️ NAME-ONLY match found (type differs)")
                }
            }

            // Fall back to slow search only if needed
            if match == nil {
                // Convert type string back to enum for legacy findMatch function
                let format = PluginFormat(rawValue: parsed.type) ?? .VST3
                match = findMatch(
                    pluginName: parsed.name, manufacturer: parsed.publisher, format: format, in: installedPlugins
                )
                if match != nil {
                    print("   🔍 FUZZY match found (fallback search)")
                }
            }

            if match == nil {
                print("   ❌ NO match found - plugin not installed")
            }

            // If plugin is installed, pull metadata from the matched PluginItem
            let version = match?.version ?? ""
            let style = match?.style ?? ""
            let architectures = match?.architectures ?? ""

            if match != nil {
                print("   📦 Pulling metadata from installed plugin:")
                print("      • version: '\(version)'")
                print("      • style: '\(style)'")
                print("      • architectures: '\(architectures)'")
            }

            let entry = DAWPlaylistEntry(
                name: parsed.name, publisher: parsed.publisher, trackName: parsed.trackName, trackIndex: parsed.trackIndex, deviceIndex: parsed.deviceIndex, type: parsed.type, isInstalled: match != nil, matchedPluginPath: match?.path, version: version, style: style, architectures: architectures, preset: parsed.preset
            )

            print("   📤 OUTPUT DAWPlaylistEntry:")
            print("      • name: '\(entry.name)'")
            print("      • publisher: '\(entry.publisher)'")
            print("      • type: '\(entry.type)'")
            print("      • preset: '\(entry.preset)'")
            print("      • isInstalled: \(entry.isInstalled)")
            print("      • track: '\(entry.trackName)'")

            return entry
        }
    }

    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name

        let suffixes = [" VST", " VST3", " AU", " AAX", " x64", " x86", " (VST)", " (VST3)", " (AU)", " (AAX)", " v2", " v3", " v4", " v5", " 2", " 3", " 4", " 5"]

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
            totalPlugins: total, matchedPlugins: matched, missingPlugins: missing, matchRate: rate
        )
    }
}

#endif