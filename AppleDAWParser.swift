//
//  AppleDAWParser.swift
//  Plugin Reporter
//
//  Shared base parser for Apple DAW applications (Logic Pro, GarageBand, MainStage)
//  These apps use the same plist-based project format
//

import Foundation

/// Shared parsing logic for Apple DAW applications
/// Logic Pro, GarageBand, and MainStage all use the same ProjectData plist format
class AppleDAWParser {

    // MARK: - Shared Parsing Methods

    /// Parse tracks from Apple DAW plist format
    static func parseTracks(from plist: [String: Any]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        // Apple DAWs store tracks in various locations depending on version
        // Common paths: "Tracks", "TrackList", or within "Folder" objects
        var tracksArray: [[String: Any]] = []

        if let trackList = plist["Tracks"] as? [[String: Any]] {
            tracksArray = trackList
        } else if let trackList = plist["TrackList"] as? [[String: Any]] {
            tracksArray = trackList
        } else {
            // Try deep search for tracks in nested structures
            tracksArray = deepSearchTracks(in: plist)
        }

        // Parse each track
        for (index, trackDict) in tracksArray.enumerated() {
            if let track = parseTrack(trackDict, index: index) {
                tracks.append(track)
            }
        }

        return tracks
    }

    /// Parse a single track from dictionary
    static func parseTrack(_ dict: [String: Any], index: Int) -> ParsedTrack? {
        // Get track name (various possible keys)
        let trackName = dict["Name"] as? String
            ?? dict["TrackName"] as? String
            ?? dict["name"] as? String
            ?? "Track \(index + 1)"

        // Parse plugins from this track
        let plugins = parsePlugins(from: dict, trackName: trackName, trackIndex: index)

        guard !plugins.isEmpty else { return nil }

        return ParsedTrack(name: trackName, index: index, plugins: plugins)
    }

    /// Parse plugins from a track dictionary
    static func parsePlugins(from dict: [String: Any], trackName: String, trackIndex: Int) -> [ParsedPlugin] {
        var plugins: [ParsedPlugin] = []

        // Look for plugin arrays in common locations
        let possiblePluginKeys = ["PluginData", "Plugins", "InsertEffects", "Inserts", "AudioUnitPreset"]

        for key in possiblePluginKeys {
            if let pluginArray = dict[key] as? [[String: Any]] {
                for (deviceIndex, pluginDict) in pluginArray.enumerated() {
                    if let plugin = parsePluginDict(pluginDict, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex) {
                        plugins.append(plugin)
                    }
                }
            } else if let singlePlugin = dict[key] as? [String: Any] {
                if let plugin = parsePluginDict(singlePlugin, trackName: trackName, trackIndex: trackIndex, deviceIndex: 0) {
                    plugins.append(plugin)
                }
            }
        }

        return plugins
    }

    /// Parse a single plugin dictionary
    static func parsePluginDict(_ dict: [String: Any], trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Try to find plugin name
        let name = dict["Name"] as? String
            ?? dict["PluginName"] as? String
            ?? dict["name"] as? String

        // Try to find manufacturer
        let manufacturer = dict["Manufacturer"] as? String
            ?? dict["Vendor"] as? String
            ?? dict["manufacturer"] as? String
            ?? "Unknown"

        guard let pluginName = name else { return nil }

        // Determine format (Apple DAWs primarily use AU)
        let format = PluginFormat.AU

        return ParsedPlugin(
            name: pluginName,
            manufacturer: manufacturer,
            trackName: trackName,
            trackIndex: trackIndex,
            deviceIndex: deviceIndex,
            format: format
        )
    }

    /// Deep search for tracks in nested plist structures
    static func deepSearchTracks(in plist: [String: Any]) -> [[String: Any]] {
        var found: [[String: Any]] = []

        // Recursive search through the plist structure
        func searchDict(_ dict: [String: Any]) {
            for (key, value) in dict {
                if key == "Tracks" || key == "TrackList" {
                    if let tracks = value as? [[String: Any]] {
                        found.append(contentsOf: tracks)
                    }
                } else if let subDict = value as? [String: Any] {
                    searchDict(subDict)
                } else if let arrayOfDicts = value as? [[String: Any]] {
                    for item in arrayOfDicts {
                        searchDict(item)
                    }
                }
            }
        }

        searchDict(plist)
        return found
    }

    // MARK: - Metadata Extraction

    /// Extract tempo from plist
    static func extractTempo(from plist: [String: Any]) -> Double? {
        // Try various keys where tempo might be stored
        if let tempo = plist["Tempo"] as? Double {
            return tempo
        }
        if let tempoStr = plist["Tempo"] as? String, let tempo = Double(tempoStr) {
            return tempo
        }
        if let tempo = plist["BPM"] as? Double {
            return tempo
        }
        if let tempo = plist["tempo"] as? Double {
            return tempo
        }
        return nil
    }

    /// Extract sample rate from plist
    static func extractSampleRate(from plist: [String: Any]) -> Int? {
        // Try various keys where sample rate might be stored
        if let rate = plist["SampleRate"] as? Int {
            return rate
        }
        if let rateStr = plist["SampleRate"] as? String, let rate = Int(rateStr) {
            return rate
        }
        if let rate = plist["SamplingRate"] as? Int {
            return rate
        }
        if let rate = plist["sampleRate"] as? Int {
            return rate
        }
        return nil
    }

    /// Extract version from plist
    static func extractVersion(from plist: [String: Any]) -> String? {
        // Try various keys where version might be stored
        if let version = plist["Version"] as? String {
            return version
        }
        if let version = plist["version"] as? String {
            return version
        }
        if let version = plist["AppVersion"] as? String {
            return version
        }
        if let versionInt = plist["Version"] as? Int {
            return String(versionInt)
        }
        return nil
    }

    /// Find ProjectData file in Apple DAW package
    static func findProjectData(in packageURL: URL, dawName: String) throws -> URL {
        // Try standard locations
        let alternativesURL = packageURL
            .appendingPathComponent("Alternatives")
            .appendingPathComponent("000")
            .appendingPathComponent("ProjectData")

        let fallbackURL = packageURL.appendingPathComponent("ProjectData")

        if FileManager.default.fileExists(atPath: alternativesURL.path) {
            return alternativesURL
        } else if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        } else {
            throw ParserError.invalidProjectData("ProjectData file not found in \(dawName) project package")
        }
    }

    /// Parse Apple DAW project with common logic
    static func parseAppleProject(
        url: URL,
        dawType: DAWType,
        supportedExtensions: [String],
        dawName: String
    ) throws -> ParsedProject {
        // Validate extension
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Validate package exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParserError.invalidFileType
        }

        // Find ProjectData file
        let dataURL = try findProjectData(in: url, dawName: dawName)

        // Read and parse plist
        let data = try Data(contentsOf: dataURL)

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ParserError.xmlParsingFailed
        }

        // Parse tracks and metadata
        let projectName = url.deletingPathExtension().lastPathComponent
        let tracks = parseTracks(from: plist)
        let tempo = extractTempo(from: plist)
        let sampleRate = extractSampleRate(from: plist)
        let version = extractVersion(from: plist)

        return ParsedProject(
            name: projectName,
            sourceFile: url,
            dawType: dawType,
            tracks: tracks,
            tempo: tempo,
            sampleRate: sampleRate,
            version: version,
            key: nil
        )
    }
}
