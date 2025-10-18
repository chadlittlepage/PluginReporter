//
//  MetadataManager.swift
//  PluginReporter
//
//  Manages metadata overrides and publisher normalizations
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MetadataManager: ObservableObject {
    static let shared = MetadataManager()

    @Published private var overrides: [String: PluginMetadataOverride] = [:]
    @Published private var publisherNormalizations: [String: String] = [:]

    private let overridesKey = "plugin_metadata_overrides"
    private let normalizationsKey = "publisher_normalizations"

    // Built-in publisher normalizations for common variations
    private let builtInNormalizations: [String: String] = [
        // Plugin Alliance
        "Plugin-alliance": "Plugin Alliance",
        "PluginAlliance": "Plugin Alliance",
        "plugin alliance": "Plugin Alliance",
        "PLUGIN ALLIANCE": "Plugin Alliance",

        // Native Instruments
        "Native Instruments Gmbh": "Native Instruments",
        "Native Instruments GmbH": "Native Instruments",
        "native instruments": "Native Instruments",
        "NATIVE INSTRUMENTS": "Native Instruments",
        "NI": "Native Instruments",

        // FabFilter
        "fabfilter": "FabFilter",
        "FABFILTER": "FabFilter",
        "Fab Filter": "FabFilter",

        // Waves
        "waves": "Waves",
        "WAVES": "Waves",
        "Waves Audio": "Waves",
        "Waves Audio Ltd": "Waves",

        // iZotope
        "izotope": "iZotope",
        "IZOTOPE": "iZotope",
        "iZotope, Inc.": "iZotope",

        // Universal Audio
        "Universal Audio, Inc.": "Universal Audio",
        "universal audio": "Universal Audio",
        "UNIVERSAL AUDIO": "Universal Audio",
        "UA": "Universal Audio",

        // Softube
        "softube": "Softube",
        "SOFTUBE": "Softube",
        "Softube AB": "Softube",

        // Soundtoys
        "soundtoys": "Soundtoys",
        "SOUNDTOYS": "Soundtoys",
        "SoundToys": "Soundtoys",

        // Slate Digital
        "Slate Digital LLC": "Slate Digital",
        "slate digital": "Slate Digital",
        "SLATE DIGITAL": "Slate Digital",

        // SSL
        "Solid State Logic": "SSL",
        "solid state logic": "SSL",

        // McDSP
        "mcdsp": "McDSP",
        "MCDSP": "McDSP",
        "McDSP, Inc.": "McDSP",

        // Valhalla DSP
        "Valhalla": "Valhalla DSP",
        "valhalla": "Valhalla DSP",
        "VALHALLA": "Valhalla DSP",
        "ValhallaVintageVerb": "Valhalla DSP",

        // Arturia
        "arturia": "Arturia",
        "ARTURIA": "Arturia",
        "Arturia SA": "Arturia",

        // Spectrasonics
        "spectrasonics": "Spectrasonics",
        "SPECTRASONICS": "Spectrasonics",

        // u-he
        "u-he": "u-he",
        "U-HE": "u-he",
        "Urs Heckmann": "u-he",

        // Eventide
        "eventide": "Eventide",
        "EVENTIDE": "Eventide",
        "Eventide Inc.": "Eventide",

        // Lexicon
        "lexicon": "Lexicon",
        "LEXICON": "Lexicon",

        // Celemony
        "celemony": "Celemony",
        "CELEMONY": "Celemony",
        "Celemony Software GmbH": "Celemony",

        // Xfer Records
        "Xfer": "Xfer Records",
        "xfer": "Xfer Records",
        "XFER": "Xfer Records",

        // Sugar Bytes
        "sugar bytes": "Sugar Bytes",
        "SUGAR BYTES": "Sugar Bytes",
        "SugarBytes": "Sugar Bytes"
    ]

    private init() {
        loadOverrides()
        loadNormalizations()
    }

    // MARK: - Publisher Normalization

    /// Get normalized publisher name
    func normalizedPublisher(_ original: String) -> String {
        // First check user-defined normalizations
        if let normalized = publisherNormalizations[original] {
            return normalized
        }

        // Then check built-in normalizations
        if let normalized = builtInNormalizations[original] {
            return normalized
        }

        // Return original if no normalization found
        return original
    }

    /// Add or update a publisher normalization
    func setNormalization(from original: String, to normalized: String) {
        publisherNormalizations[original] = normalized
        saveNormalizations()
        objectWillChange.send()
    }

    /// Remove a publisher normalization
    func removeNormalization(for original: String) {
        publisherNormalizations.removeValue(forKey: original)
        saveNormalizations()
        objectWillChange.send()
    }

    /// Get all normalizations (user-defined + built-in)
    func getAllNormalizations() -> [String: String] {
        var all = builtInNormalizations
        // User normalizations override built-in
        for (key, value) in publisherNormalizations {
            all[key] = value
        }
        return all
    }

    /// Get only user-defined normalizations
    func getUserNormalizations() -> [String: String] {
        return publisherNormalizations
    }

    // MARK: - Metadata Overrides

    /// Get override for a plugin path
    func getOverride(for pluginPath: String) -> PluginMetadataOverride? {
        return overrides[pluginPath]
    }

    /// Set override for a plugin
    func setOverride(for pluginPath: String, override: PluginMetadataOverride) {
        overrides[pluginPath] = override
        saveOverrides()
        objectWillChange.send()
    }

    /// Remove override for a plugin
    func removeOverride(for pluginPath: String) {
        overrides.removeValue(forKey: pluginPath)
        saveOverrides()
        objectWillChange.send()
    }

    /// Get the display publisher (normalized or overridden)
    func getDisplayPublisher(for plugin: PluginItem) -> String {
        // First check for override
        if let override = getOverride(for: plugin.path),
           let publisher = override.publisher {
            return publisher
        }

        // Then apply normalization
        return normalizedPublisher(plugin.publisher)
    }

    /// Get the display version (overridden or original)
    func getDisplayVersion(for plugin: PluginItem) -> String {
        if let override = getOverride(for: plugin.path),
           let version = override.version {
            return version
        }
        return plugin.version
    }

    /// Get the display style (overridden or original)
    func getDisplayStyle(for plugin: PluginItem) -> String {
        if let override = getOverride(for: plugin.path),
           let style = override.style {
            return style
        }
        return plugin.style
    }

    // MARK: - Smart Merge Suggestions

    /// Find similar publisher names and suggest merges
    func findMergeSuggestions(from publishers: [String]) -> [PublisherMergeSuggestion] {
        // Get unique publishers (excluding empty strings)
        let uniquePublishers = Set(publishers.filter { !$0.isEmpty })
        var suggestions: [PublisherMergeSuggestion] = []
        var processed: Set<String> = []

        for publisher in uniquePublishers {
            // Skip if already processed
            if processed.contains(publisher) {
                continue
            }

            // Find similar variants
            var variants: [String] = [publisher]
            for other in uniquePublishers {
                if other == publisher || processed.contains(other) {
                    continue
                }

                // Check if similar (case-insensitive, whitespace/dash variations)
                if areSimilar(publisher, other) {
                    variants.append(other)
                    processed.insert(other)
                }
            }

            // If we found variants, create a suggestion
            if variants.count > 1 {
                // Sort variants to pick the best canonical name
                let canonical = pickCanonicalName(from: variants)
                suggestions.append(PublisherMergeSuggestion(
                    canonical: canonical,
                    variants: variants.filter { $0 != canonical }.sorted()
                ))
            }

            processed.insert(publisher)
        }

        return suggestions.sorted { $0.canonical < $1.canonical }
    }

    /// Check if two publisher names are similar and should be merged
    private func areSimilar(_ a: String, _ b: String) -> Bool {
        let cleanA = a.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        let cleanB = b.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")

        // Exact match after cleaning
        if cleanA == cleanB {
            return true
        }

        // Check if one contains the other (for cases like "Native Instruments" vs "Native Instruments GmbH")
        if cleanA.contains(cleanB) || cleanB.contains(cleanA) {
            return true
        }

        // Check Levenshtein distance for typos
        let distance = levenshteinDistance(cleanA, cleanB)
        let maxLength = max(cleanA.count, cleanB.count)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        // Consider similar if 85% or more similar
        return similarity >= 0.85
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)

        for i in 0...s1.count {
            matrix[i][0] = i
        }
        for j in 0...s2.count {
            matrix[0][j] = j
        }

        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i - 1] == s2[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }

        return matrix[s1.count][s2.count]
    }

    /// Pick the best canonical name from a list of variants
    private func pickCanonicalName(from variants: [String]) -> String {
        // Prefer names that:
        // 1. Don't have weird characters
        // 2. Have proper capitalization
        // 3. Are shorter (but not too short)
        // 4. Don't have "Inc", "LLC", "GmbH" etc.

        let scored = variants.map { name -> (name: String, score: Int) in
            var score = 0

            // Prefer proper capitalization (first letter uppercase)
            if let first = name.first, first.isUppercase {
                score += 10
            }

            // Penalize all uppercase
            if name == name.uppercased() {
                score -= 5
            }

            // Penalize all lowercase
            if name == name.lowercased() {
                score -= 3
            }

            // Penalize corporate suffixes
            let lowerName = name.lowercased()
            if lowerName.contains("inc") || lowerName.contains("llc") ||
               lowerName.contains("gmbh") || lowerName.contains("ltd") {
                score -= 8
            }

            // Prefer medium length (not too short, not too long)
            if name.count >= 5 && name.count <= 30 {
                score += 5
            }

            // Penalize special characters (except space and dash)
            let specialChars = name.filter { !$0.isLetter && !$0.isWhitespace && $0 != "-" }
            score -= specialChars.count * 2

            return (name, score)
        }

        // Return the highest scoring name, or first variant if available
        return scored.max(by: { $0.score < $1.score })?.name ?? variants.first ?? ""
    }

    /// Apply a merge suggestion (create normalizations for all variants)
    func applyMergeSuggestion(_ suggestion: PublisherMergeSuggestion) {
        for variant in suggestion.variants {
            setNormalization(from: variant, to: suggestion.canonical)
        }
    }

    // MARK: - Statistics

    func getOverrideCount() -> Int {
        return overrides.count
    }

    func getNormalizationCount() -> Int {
        return publisherNormalizations.count
    }

    // MARK: - Persistence

    private func saveOverrides() {
        if let encoded = try? JSONEncoder().encode(overrides) {
            CloudSyncStorage.shared.setData(encoded, forKey: overridesKey)
        }
    }

    private func loadOverrides() {
        guard let data = CloudSyncStorage.shared.getData(forKey: overridesKey),
              let decoded = try? JSONDecoder().decode([String: PluginMetadataOverride].self, from: data) else {
            return
        }
        overrides = decoded
    }

    private func saveNormalizations() {
        if let encoded = try? JSONEncoder().encode(publisherNormalizations) {
            CloudSyncStorage.shared.setData(encoded, forKey: normalizationsKey)
        }
    }

    private func loadNormalizations() {
        guard let data = CloudSyncStorage.shared.getData(forKey: normalizationsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        publisherNormalizations = decoded
    }
}

// MARK: - Data Models

struct PluginMetadataOverride: Codable {
    var publisher: String?
    var version: String?
    var style: String?

    var hasAnyOverride: Bool {
        return publisher != nil || version != nil || style != nil
    }
}

struct PublisherMergeSuggestion: Identifiable {
    let id = UUID()
    let canonical: String
    let variants: [String]

    var description: String {
        if variants.count == 1 {
            return "Merge '\(variants[0])' into '\(canonical)'"
        } else {
            return "Merge \(variants.count) variations into '\(canonical)'"
        }
    }

    var variantsText: String {
        return variants.joined(separator: ", ")
    }
}
