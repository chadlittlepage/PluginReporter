//
//  LogicProParser.swift
//  Plugin Reporter
//
//  Parser for Logic Pro project files (.logic, .logicx)
//  Logic projects are package directories containing ProjectData plist
//

import Foundation

/// Parser for Logic Pro project files (Package-based)
class LogicProParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .logicPro
    static let supportedExtensions: [String] = ["logic", "logicx"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Logic Pro projects are package directories
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParserError.invalidFileType
        }

        // Look for ProjectData file inside the package
        let projectDataURL = url.appendingPathComponent("Alternatives")
            .appendingPathComponent("000")
            .appendingPathComponent("ProjectData")

        // Fallback to root-level ProjectData if not in Alternatives
        let fallbackURL = url.appendingPathComponent("ProjectData")

        var dataURL: URL
        if FileManager.default.fileExists(atPath: projectDataURL.path) {
            dataURL = projectDataURL
        } else if FileManager.default.fileExists(atPath: fallbackURL.path) {
            dataURL = fallbackURL
        } else {
            throw ParserError.invalidProjectData("ProjectData file not found in Logic project package")
        }

        // Read and parse the plist
        let data = try Data(contentsOf: dataURL)

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ParserError.xmlParsingFailed
        }

        // Parse the project data
        let projectName = url.deletingPathExtension().lastPathComponent
        let tracks = parseTracks(from: plist)

        // Extract metadata
        let tempo = extractTempo(from: plist)
        let sampleRate = extractSampleRate(from: plist)
        let version = extractVersion(from: plist)

        return ParsedProject(
            name: projectName,
            sourceFile: url,
            dawType: .logicPro,
            tracks: tracks,
            tempo: tempo,
            sampleRate: sampleRate,
            version: version,
            key: nil
        )
    }

    // MARK: - Parsing Logic

    private static func parseTracks(from plist: [String: Any]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        // Logic Pro stores tracks in various locations depending on version
        // Common paths: "Tracks", "TrackList", or within "Folder" objects

        // Try to find tracks array
        var tracksArray: [[String: Any]] = []

        if let trackList = plist["Tracks"] as? [[String: Any]] {
            tracksArray = trackList
        } else if let trackList = plist["TrackList"] as? [[String: Any]] {
            tracksArray = trackList
        }

        // Parse each track
        for (index, trackDict) in tracksArray.enumerated() {
            if let track = parseTrack(trackDict, index: index) {
                tracks.append(track)
            }
        }

        // If no tracks found using standard paths, try deeper search
        if tracks.isEmpty {
            tracks = deepSearchTracks(in: plist)
        }

        return tracks
    }

    private static func parseTrack(_ trackDict: [String: Any], index: Int) -> ParsedTrack? {
        // Extract track name
        let trackName = trackDict["Name"] as? String
            ?? trackDict["TrackName"] as? String
            ?? "Track \(index + 1)"

        // Look for plugins in various possible locations
        var plugins: [ParsedPlugin] = []

        // Check for PluginData array
        if let pluginDataArray = trackDict["PluginData"] as? [[String: Any]] {
            plugins = parsePlugins(from: pluginDataArray, trackName: trackName, trackIndex: index)
        }

        // Check for Inserts (channel strip plugins)
        if let inserts = trackDict["Inserts"] as? [[String: Any]] {
            plugins.append(contentsOf: parsePlugins(from: inserts, trackName: trackName, trackIndex: index))
        }

        // Check for ChannelStrip
        if let channelStrip = trackDict["ChannelStrip"] as? [String: Any] {
            if let channelPlugins = channelStrip["Inserts"] as? [[String: Any]] {
                plugins.append(contentsOf: parsePlugins(from: channelPlugins, trackName: trackName, trackIndex: index))
            }
        }

        // Only return tracks that have plugins
        guard !plugins.isEmpty else {
            return nil
        }

        return ParsedTrack(
            name: trackName,
            index: index,
            plugins: plugins
        )
    }

    private static func parsePlugins(from pluginArray: [[String: Any]], trackName: String, trackIndex: Int) -> [ParsedPlugin] {
        var plugins: [ParsedPlugin] = []

        for (deviceIndex, pluginDict) in pluginArray.enumerated() {
            // Skip empty slots
            if pluginDict["Bypass"] as? Bool == true && pluginDict["Name"] == nil {
                continue
            }

            // Extract plugin info
            var pluginName = pluginDict["Name"] as? String
                ?? pluginDict["PluginName"] as? String
                ?? pluginDict["identifier"] as? String
                ?? "Unknown Plugin"

            // Extract manufacturer
            var manufacturer = pluginDict["Manufacturer"] as? String
                ?? pluginDict["Vendor"] as? String
                ?? "Unknown"

            // Determine plugin format
            var format: PluginFormat = .AU  // Logic Pro primarily uses AU

            // Check for format indicators
            if let pluginType = pluginDict["Type"] as? String {
                format = parsePluginFormat(pluginType)
            } else if let identifier = pluginDict["identifier"] as? String {
                format = parsePluginFormat(identifier)
            }

            // Logic Pro native plugins
            if manufacturer == "Apple" || manufacturer.isEmpty {
                manufacturer = "Apple"

                // Try to get better name from bundle identifier
                if let bundleID = pluginDict["BundleID"] as? String {
                    pluginName = extractPluginNameFromBundle(bundleID, fallback: pluginName)
                }
            }

            // Clean up plugin name
            pluginName = cleanPluginName(pluginName)

            let plugin = ParsedPlugin(
                name: pluginName,
                manufacturer: manufacturer,
                trackName: trackName,
                trackIndex: trackIndex,
                deviceIndex: deviceIndex,
                format: format
            )

            plugins.append(plugin)
        }

        return plugins
    }

    // MARK: - Deep Search (fallback)

    private static func deepSearchTracks(in plist: [String: Any]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []
        var trackIndex = 0

        // Recursively search for plugin data in the plist
        func searchForPlugins(in dict: Any, path: String = "") -> [[String: Any]] {
            var found: [[String: Any]] = []

            if let dict = dict as? [String: Any] {
                // Check if this looks like a plugin
                if dict["Name"] != nil || dict["PluginName"] != nil || dict["BundleID"] != nil {
                    found.append(dict)
                }

                // Recurse into child dictionaries
                for (_, value) in dict {
                    found.append(contentsOf: searchForPlugins(in: value, path: path))
                }
            } else if let array = dict as? [Any] {
                for item in array {
                    found.append(contentsOf: searchForPlugins(in: item, path: path))
                }
            }

            return found
        }

        let foundPlugins = searchForPlugins(in: plist)

        if !foundPlugins.isEmpty {
            let plugins = parsePlugins(from: foundPlugins, trackName: "Logic Project", trackIndex: 0)

            if !plugins.isEmpty {
                tracks.append(ParsedTrack(
                    name: "Logic Project",
                    index: 0,
                    plugins: plugins
                ))
            }
        }

        return tracks
    }

    // MARK: - Metadata Extraction

    private static func extractTempo(from plist: [String: Any]) -> Double? {
        if let tempo = plist["Tempo"] as? Double {
            return tempo
        }
        if let tempo = plist["DefaultTempo"] as? Double {
            return tempo
        }
        if let tempo = plist["InitialTempo"] as? Double {
            return tempo
        }
        return nil
    }

    private static func extractSampleRate(from plist: [String: Any]) -> Int? {
        if let rate = plist["SampleRate"] as? Int {
            return rate
        }
        if let rate = plist["ProjectSampleRate"] as? Int {
            return rate
        }
        if let rate = plist["AudioSampleRate"] as? Int {
            return rate
        }
        return nil
    }

    private static func extractVersion(from plist: [String: Any]) -> String? {
        if let version = plist["Version"] as? String {
            return version
        }
        if let version = plist["ApplicationVersion"] as? String {
            return version
        }
        if let version = plist["LogicVersion"] as? String {
            return version
        }
        return nil
    }

    // MARK: - Helper Methods

    private static func parsePluginFormat(_ formatString: String) -> PluginFormat {
        let lower = formatString.lowercased()

        if lower.contains("vst3") {
            return .VST3
        } else if lower.contains("vst") {
            return .VST
        } else if lower.contains("au") || lower.contains("audiounit") {
            return .AU
        } else if lower.contains("aax") {
            return .AAX
        } else if lower.contains("clap") {
            return .CLAP
        } else {
            return .AU  // Default for Logic Pro
        }
    }

    private static func extractPluginNameFromBundle(_ bundleID: String, fallback: String) -> String {
        // Bundle IDs look like: com.apple.logic.EQ
        // Extract the last component
        let components = bundleID.components(separatedBy: ".")
        if let last = components.last, !last.isEmpty {
            return last
        }
        return fallback
    }

    private static func cleanPluginName(_ name: String) -> String {
        // Remove common suffixes and clean up
        var cleaned = name
            .replacingOccurrences(of: " (mono)", with: "")
            .replacingOccurrences(of: " (stereo)", with: "")
            .replacingOccurrences(of: " AU", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove version numbers at the end (e.g., "EQ 3.2" -> "EQ")
        if let match = cleaned.range(of: #"\s+\d+(\.\d+)*$"#, options: .regularExpression) {
            cleaned.removeSubrange(match)
        }

        return cleaned
    }
}
