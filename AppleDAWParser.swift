//
//  AppleDAWParser.swift
//  Plugin Reporter
//
//  Shared base parser for Apple DAW applications (Logic Pro, GarageBand, MainStage)
//  These apps use the same plist-based project format
//

import Foundation

#if os(macOS)
/// Shared parsing logic for Apple DAW applications
/// Logic Pro, GarageBand, and MainStage all use the same ProjectData plist format
public class AppleDAWParser {

    // MARK: - Shared Parsing Methods

    /// Parse tracks from Apple DAW plist format
    public static func parseTracks(from plist: [String: Any]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        // Apple DAWs store tracks in various locations depending on version
        // Common paths: "Tracks", "TrackList", or "patches" (MainStage)
        var tracksArray: [[String: Any]] = []

        if let trackList = plist["Tracks"] as? [[String: Any]] {
            tracksArray = trackList
        } else if let trackList = plist["TrackList"] as? [[String: Any]] {
            tracksArray = trackList
        } else if let patches = plist["patches"] as? [[String: Any]] {
            // MainStage uses "patches" instead of tracks
            tracksArray = patches
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

        // Always return track, even if it has no plugins
        return ParsedTrack(name: trackName, index: index, plugins: plugins)
    }

    /// Parse plugins from a track dictionary
    static func parsePlugins(from dict: [String: Any], trackName: String, trackIndex: Int) -> [ParsedPlugin] {
        var plugins: [ParsedPlugin] = []
        var deviceIndex = 0

        // Look for plugin arrays in common locations
        let possiblePluginKeys = ["PluginData", "Plugins", "InsertEffects", "Inserts", "AudioUnitPreset"]

        for key in possiblePluginKeys {
            if let pluginArray = dict[key] as? [[String: Any]] {
                for pluginDict in pluginArray {
                    if let plugin = parsePluginDict(pluginDict, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex) {
                        plugins.append(plugin)
                        deviceIndex += 1
                    }
                }
            } else if let singlePlugin = dict[key] as? [String: Any] {
                if let plugin = parsePluginDict(singlePlugin, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }
        }

        // MainStage specific: Look inside channelStrips
        if let channelStrips = dict["channelStrips"] as? [[String: Any]] {
            for channelStrip in channelStrips {
                // Check for Plugins inside each channel strip
                if let pluginArray = channelStrip["Plugins"] as? [[String: Any]] {
                    for pluginDict in pluginArray {
                        if let plugin = parsePluginDict(pluginDict, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex) {
                            plugins.append(plugin)
                            deviceIndex += 1
                        }
                    }
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
        var manufacturer = dict["Manufacturer"] as? String
            ?? dict["Vendor"] as? String
            ?? dict["manufacturer"] as? String
            ?? "Unknown"

        guard let pluginName = name else { return nil }

        // If manufacturer is Unknown or a test placeholder, try to detect from plugin name
        if manufacturer == "Unknown" || manufacturer == "Test Vendor" || manufacturer.isEmpty {
            manufacturer = detectManufacturerFromName(pluginName)
        }

        // Determine format (Apple DAWs primarily use AU)
        let format = PluginFormat.AU

        return ParsedPlugin(
            name: pluginName, publisher: manufacturer, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: format
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
        // Try standard locations (both capitalized and lowercase versions)
        let alternativesURL = packageURL
            .appendingPathComponent("Alternatives")
            .appendingPathComponent("000")
            .appendingPathComponent("ProjectData")

        let fallbackURL = packageURL.appendingPathComponent("ProjectData")
        let fallbackURLLower = packageURL.appendingPathComponent("projectData")

        // Check all locations and prefer non-encrypted version
        var candidateURLs: [URL] = []

        if FileManager.default.fileExists(atPath: alternativesURL.path) {
            candidateURLs.append(alternativesURL)
        }
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            candidateURLs.append(fallbackURL)
        }
        if FileManager.default.fileExists(atPath: fallbackURLLower.path) {
            candidateURLs.append(fallbackURLLower)
        }

        guard !candidateURLs.isEmpty else {
            throw ParserError.invalidProjectData("ProjectData file not found in \(dawName) project package")
        }

        // Find first non-encrypted file (doesn't start with #G)
        for url in candidateURLs {
            if let data = try? Data(contentsOf: url), data.count >= 2, !(data[0] == 0x23 && data[1] == 0x47) {  // Not #G
                print("✅ Found parseable ProjectData at: \(url.lastPathComponent) (in \(url.deletingLastPathComponent().lastPathComponent))")
                return url
            }
        }

        // All files are encrypted, return first one (will fail with proper error message)
        print("⚠️ All ProjectData files are encrypted")
        return candidateURLs[0]
    }

    /// Parse Apple DAW project with common logic
    public static func parseAppleProject(
        url: URL, dawType: DAWType, supportedExtensions: [String], dawName: String
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

        // Check if this is Apple binary format (starts with #G signature)
        // Binary format introduced: Logic Pro 10.5, GarageBand 10.4, MainStage 3.5 (all Nov 2020)
        if data.count >= 2 && data[0] == 0x23 && data[1] == 0x47 {
            let errorMessage: String
            switch dawType {
            case .logicPro: 
                errorMessage = "⚠️ Logic Pro 10.5+ projects cannot be imported.\n\nLogic Pro 10.5 and newer use an encrypted proprietary format that Apple does not provide access to.\n\nONLY Logic Pro 10.4.8 and older projects are supported."
            case .garageBand: 
                errorMessage = "⚠️ GarageBand 10.4+ projects cannot be imported.\n\nGarageBand 10.4 and newer use an encrypted proprietary format that Apple does not provide access to.\n\nONLY GarageBand 10.3.x and older projects are supported."
            case .mainStage: 
                errorMessage = "⚠️ MainStage 3.5+ projects cannot be imported.\n\nMainStage 3.5 and newer use an encrypted proprietary format that Apple does not provide access to.\n\nONLY MainStage 3.4.x and older projects are supported."
            default: 
                errorMessage = "⚠️ \(dawName) projects cannot be imported.\n\n\(dawName) uses an encrypted proprietary format that Apple does not provide access to."
            }
            throw ParserError.invalidProjectData(errorMessage)
        }

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
            name: projectName, sourceFile: url, dawType: dawType, tracks: tracks, tempo: tempo, sampleRate: sampleRate, version: version, key: nil
        )
    }

    /// Detect manufacturer/publisher from plugin name
    static func detectManufacturerFromName(_ pluginName: String) -> String {
        let lower = pluginName.lowercased()

        // Known manufacturer patterns in plugin names
        if lower.contains("fabfilter") { return "FabFilter" }
        if lower.contains("waves") { return "Waves" }
        if lower.contains("valhalla") { return "Valhalla DSP" }
        if lower.contains("soundtoys") { return "Soundtoys" }
        if lower.contains("izotope") { return "iZotope" }
        if lower.contains("slate") { return "Slate Digital" }
        if lower.contains("native instruments") || lower.contains("kontakt") || lower.contains("massive") { return "Native Instruments" }
        if lower.contains("serum") { return "Xfer Records" }
        if lower.contains("arturia") { return "Arturia" }
        if lower.contains("omnisphere") || lower.contains("keyscape") { return "Spectrasonics" }
        if lower.contains("output") { return "Output" }
        if lower.contains("u-he") || lower.contains("diva") || lower.contains("zebra") { return "u-he" }
        if lower.contains("plugin alliance") || lower.contains("bx_") || lower.contains("brainworx") { return "Plugin Alliance" }
        if lower.contains("softube") { return "Softube" }
        if lower.contains("celemony") || lower.contains("melodyne") { return "Celemony" }
        if lower.contains("auto-tune") || lower.contains("antares") { return "Antares" }
        if lower.contains("spitfire") { return "Spitfire Audio" }
        if lower.contains("ssl ") || lower.starts(with: "ssl") { return "Solid State Logic" }
        if lower.contains("uad ") || lower.contains("universal audio") { return "Universal Audio" }
        if lower.contains("avid") || lower.contains("pro tools") { return "Avid" }
        if lower.contains("lexicon") { return "Lexicon" }
        if lower.contains("eventide") { return "Eventide" }

        return "Unknown"
    }
}
#endif