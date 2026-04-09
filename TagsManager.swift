//
//  TagsManager.swift
//  PluginReporter
//
//  Manages user tags for plugins
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TagsManager: ObservableObject {
    static let shared = TagsManager()

    @Published private var pluginTags: [String: Set<String>] = [:]
    @Published private var customTags: Set<String> = []

    private let storageKey = "plugin_tags"
    private let customTagsKey = "custom_tags"

    // Common tag suggestions based on plugin style
    private let styleSuggestions: [String: [String]] = [
        "Reverb": ["reverb", "space", "ambience"], "Delay": ["delay", "echo", "time-based"], "Compressor": ["compressor", "dynamics", "leveling"], "EQ": ["eq", "equalizer", "tone", "filter"], "Limiter": ["limiter", "dynamics", "mastering"], "Gate": ["gate", "dynamics", "noise-reduction"], "Expander": ["expander", "dynamics"], "Saturation": ["saturation", "distortion", "warmth"], "Distortion": ["distortion", "saturation", "drive"], "Chorus": ["chorus", "modulation"], "Flanger": ["flanger", "modulation"], "Phaser": ["phaser", "modulation"], "Tremolo": ["tremolo", "modulation"], "Vibrato": ["vibrato", "modulation"], "Synth": ["synth", "synthesizer", "instrument"], "Sampler": ["sampler", "instrument"], "Drum": ["drums", "percussion", "rhythm"], "Bass": ["bass", "sub", "low-end"], "Guitar": ["guitar", "amp"], "Piano": ["piano", "keys"], "Strings": ["strings", "orchestral"], "Vocal": ["vocal", "voice"], "Pitch": ["pitch", "tuning"], "Analyzer": ["analyzer", "metering", "utility"], "Utility": ["utility", "tool"], "Mastering": ["mastering", "finalizer"]
    ]

    // Common tags that apply across different plugin types
    private let commonTags = [
        "favorite", "go-to", "mixing", "mastering", "creative", "surgical", "analog", "digital", "vintage", "modern", "transparent", "colored", "cpu-heavy", "cpu-light"
    ]

    private init() {
        loadTags()
        loadCustomTags()
    }

    // MARK: - Tag Management

    /// Get tags for a plugin (nonisolated for use in filters)
    nonisolated func getTags(for pluginPath: String) -> Set<String> {
        // Access from main actor context
        return MainActor.assumeIsolated {
            return pluginTags[pluginPath] ?? []
        }
    }

    /// Add a tag to a plugin
    func addTag(_ tag: String, to pluginPath: String) {
        let cleanTag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTag.isEmpty else { return }

        if pluginTags[pluginPath] == nil {
            pluginTags[pluginPath] = []
        }
        pluginTags[pluginPath]?.insert(cleanTag)

        // Add to custom tags if it's not already in common tags or style suggestions
        let isCommonTag = commonTags.contains(cleanTag)
        let isStyleTag = styleSuggestions.values.contains { $0.contains(cleanTag) }
        if !isCommonTag && !isStyleTag {
            customTags.insert(cleanTag)
            saveCustomTags()
        }

        saveTags()
        objectWillChange.send()
    }

    /// Remove a tag from a plugin
    func removeTag(_ tag: String, from pluginPath: String) {
        pluginTags[pluginPath]?.remove(tag.lowercased())
        if pluginTags[pluginPath]?.isEmpty == true {
            pluginTags.removeValue(forKey: pluginPath)
        }
        saveTags()
        objectWillChange.send()
    }

    /// Set all tags for a plugin (replaces existing)
    func setTags(_ tags: Set<String>, for pluginPath: String) {
        let cleanTags = Set(tags.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        if cleanTags.isEmpty {
            pluginTags.removeValue(forKey: pluginPath)
        } else {
            pluginTags[pluginPath] = cleanTags
        }
        saveTags()
        objectWillChange.send()
    }

    /// Clear all tags for a plugin
    func clearTags(for pluginPath: String) {
        pluginTags.removeValue(forKey: pluginPath)
        saveTags()
        objectWillChange.send()
    }

    /// Check if a plugin has a specific tag
    func hasTag(_ tag: String, for pluginPath: String) -> Bool {
        return pluginTags[pluginPath]?.contains(tag.lowercased()) ?? false
    }

    // MARK: - Tag Suggestions

    /// Get suggested tags based on plugin style
    func getSuggestedTags(for plugin: PluginItem) -> [String] {
        var suggestions: [String] = []

        // Add style-based suggestions
        if !plugin.style.isEmpty {
            if let styleTags = styleSuggestions[plugin.style] {
                suggestions.append(contentsOf: styleTags)
            }
        }

        // Add common tags
        suggestions.append(contentsOf: commonTags)

        // Add custom user tags
        suggestions.append(contentsOf: customTags)

        // Remove tags that are already applied
        let existingTags = getTags(for: plugin.path)
        suggestions = suggestions.filter { !existingTags.contains($0) }

        // Remove duplicates and sort
        return Array(Set(suggestions)).sorted()
    }

    // MARK: - Statistics

    /// Get all unique tags across all plugins
    func getAllTags() -> [String] {
        let allTags = pluginTags.values.flatMap { $0 }
        return Array(Set(allTags)).sorted()
    }

    /// Get number of plugins with a specific tag
    func getPluginCount(for tag: String) -> Int {
        return pluginTags.values.filter { $0.contains(tag.lowercased()) }.count
    }

    /// Get total number of tagged plugins
    func getTaggedPluginCount() -> Int {
        return pluginTags.count
    }

    /// Get plugins that have a specific tag
    func getPluginPaths(withTag tag: String) -> [String] {
        return pluginTags.filter { $0.value.contains(tag.lowercased()) }.map { $0.key }
    }

    // MARK: - Persistence

    private func saveTags() {
        // Convert Set<String> to [String] for encoding
        let encodable = pluginTags.mapValues { Array($0) }
        if let encoded = try? JSONEncoder().encode(encodable) {
            CloudSyncStorage.shared.setData(encoded, forKey: storageKey)
        }
    }

    private func loadTags() {
        guard let data = CloudSyncStorage.shared.getData(forKey: storageKey), let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return
        }
        // Convert [String] back to Set<String>
        pluginTags = decoded.mapValues { Set($0) }
    }

    private func saveCustomTags() {
        let encodable = Array(customTags)
        if let encoded = try? JSONEncoder().encode(encodable) {
            CloudSyncStorage.shared.setData(encoded, forKey: customTagsKey)
        }
    }

    private func loadCustomTags() {
        guard let data = CloudSyncStorage.shared.getData(forKey: customTagsKey), let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        customTags = Set(decoded)
    }
}