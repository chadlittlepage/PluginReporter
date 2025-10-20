//
//  MainStageParser.swift
//  Plugin Reporter
//
//  Parser for MainStage concert files (.concert)
//  MainStage uses the same engine as Logic Pro with package/plist format
//
//  Note: Reuses LogicProParser logic since MainStage is built on Logic's engine
//

import Foundation

/// Parser for MainStage concert files (Package-based, Logic Pro compatible)
class MainStageParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .mainStage
    static let supportedExtensions: [String] = ["concert"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        print("🎭 Parsing MainStage Concert: \(url.lastPathComponent)")

        // MainStage concerts are package directories (like Logic projects)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParserError.invalidFileType
        }

        // MainStage uses similar structure to Logic Pro
        // Look for ProjectData or ConcertData file inside the package
        let projectDataURL = url.appendingPathComponent("Alternatives")
            .appendingPathComponent("000")
            .appendingPathComponent("ProjectData")

        let concertDataURL = url.appendingPathComponent("ConcertData")
        let fallbackURL = url.appendingPathComponent("ProjectData")

        var dataURL: URL?

        // Try various locations
        if FileManager.default.fileExists(atPath: projectDataURL.path) {
            dataURL = projectDataURL
            print("   Found ProjectData in Alternatives/000/")
        } else if FileManager.default.fileExists(atPath: concertDataURL.path) {
            dataURL = concertDataURL
            print("   Found ConcertData in root")
        } else if FileManager.default.fileExists(atPath: fallbackURL.path) {
            dataURL = fallbackURL
            print("   Found ProjectData in root")
        } else {
            throw ParserError.invalidProjectData("Concert data file not found in MainStage package")
        }

        // Read and parse the plist
        let data = try Data(contentsOf: dataURL!)

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw ParserError.xmlParsingFailed
        }

        // Parse the concert data (same structure as Logic Pro)
        let concertName = url.deletingPathExtension().lastPathComponent
        let tracks = parseTracks(from: plist, concertName: concertName)

        // Extract metadata
        let tempo = extractTempo(from: plist)
        let sampleRate = extractSampleRate(from: plist)
        let version = extractVersion(from: plist)

        return ParsedProject(
            name: concertName,
            sourceFile: url,
            dawType: .mainStage,
            tracks: tracks,
            tempo: tempo,
            sampleRate: sampleRate,
            version: version,
            key: nil
        )
    }

    // MARK: - Parsing Logic (Adapted from Logic Pro)

    private static func parseTracks(from plist: [String: Any], concertName: String) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        // MainStage organizes sounds differently than Logic
        // Try multiple paths: Patches, ChannelStrips, Tracks, Sets

        // Look for Patches (MainStage's primary organization)
        if let patches = plist["Patches"] as? [[String: Any]] {
            tracks.append(contentsOf: parsePatches(patches))
        }

        // Look for Sets (collections of patches)
        if let sets = plist["Sets"] as? [[String: Any]] {
            for set in sets {
                if let setPatches = set["Patches"] as? [[String: Any]] {
                    tracks.append(contentsOf: parsePatches(setPatches))
                }
            }
        }

        // Fallback to standard Logic track structure
        if tracks.isEmpty {
            if let trackList = plist["Tracks"] as? [[String: Any]] {
                tracks = parseLogicTracks(trackList)
            } else if let trackList = plist["TrackList"] as? [[String: Any]] {
                tracks = parseLogicTracks(trackList)
            }
        }

        // If still no tracks, do deep search
        if tracks.isEmpty {
            tracks = deepSearchTracks(in: plist, concertName: concertName)
        }

        return tracks
    }

    private static func parsePatches(_ patches: [[String: Any]]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        for (index, patchDict) in patches.enumerated() {
            // Extract patch name
            let patchName = patchDict["Name"] as? String
                ?? patchDict["PatchName"] as? String
                ?? "Patch \(index + 1)"

            print("🎹 Found patch: \(patchName)")

            var plugins: [ParsedPlugin] = []

            // Look for ChannelStrip (contains plugins)
            if let channelStrip = patchDict["ChannelStrip"] as? [String: Any] {
                if let inserts = channelStrip["Inserts"] as? [[String: Any]] {
                    plugins.append(contentsOf: parsePlugins(from: inserts, trackName: patchName, trackIndex: index))
                }
            }

            // Look for direct Inserts
            if let inserts = patchDict["Inserts"] as? [[String: Any]] {
                plugins.append(contentsOf: parsePlugins(from: inserts, trackName: patchName, trackIndex: index))
            }

            // Look for PluginData
            if let pluginData = patchDict["PluginData"] as? [[String: Any]] {
                plugins.append(contentsOf: parsePlugins(from: pluginData, trackName: patchName, trackIndex: index))
            }

            // Only add if we found plugins
            if !plugins.isEmpty {
                tracks.append(ParsedTrack(
                    name: patchName,
                    index: index,
                    plugins: plugins
                ))
                print("   ✅ Added patch with \(plugins.count) plugins")
            }
        }

        return tracks
    }

    private static func parseLogicTracks(_ trackList: [[String: Any]]) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        for (index, trackDict) in trackList.enumerated() {
            if let track = parseTrack(trackDict, index: index) {
                tracks.append(track)
            }
        }

        return tracks
    }

    private static func parseTrack(_ trackDict: [String: Any], index: Int) -> ParsedTrack? {
        // Extract track name
        let trackName = trackDict["Name"] as? String
            ?? trackDict["TrackName"] as? String
            ?? "Track \(index + 1)"

        var plugins: [ParsedPlugin] = []

        // Check various plugin locations
        if let pluginDataArray = trackDict["PluginData"] as? [[String: Any]] {
            plugins = parsePlugins(from: pluginDataArray, trackName: trackName, trackIndex: index)
        }

        if let inserts = trackDict["Inserts"] as? [[String: Any]] {
            plugins.append(contentsOf: parsePlugins(from: inserts, trackName: trackName, trackIndex: index))
        }

        if let channelStrip = trackDict["ChannelStrip"] as? [String: Any] {
            if let channelPlugins = channelStrip["Inserts"] as? [[String: Any]] {
                plugins.append(contentsOf: parsePlugins(from: channelPlugins, trackName: trackName, trackIndex: index))
            }
        }

        // Only return tracks with plugins
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
            // Skip bypassed empty slots
            if pluginDict["Bypass"] as? Bool == true && pluginDict["Name"] == nil {
                continue
            }

            // Extract plugin info
            var pluginName = pluginDict["Name"] as? String
                ?? pluginDict["PluginName"] as? String
                ?? pluginDict["identifier"] as? String
                ?? "Unknown Plugin"

            var manufacturer = pluginDict["Manufacturer"] as? String
                ?? pluginDict["Vendor"] as? String
                ?? "Unknown"

            var format: PluginFormat = .AU  // MainStage primarily uses AU

            // Check for format indicators
            if let pluginType = pluginDict["Type"] as? String {
                format = parsePluginFormat(pluginType)
            } else if let identifier = pluginDict["identifier"] as? String {
                format = parsePluginFormat(identifier)
            }

            // Apple native plugins
            if manufacturer == "Apple" || manufacturer.isEmpty {
                manufacturer = "Apple"

                if let bundleID = pluginDict["BundleID"] as? String {
                    pluginName = extractPluginNameFromBundle(bundleID, fallback: pluginName)
                }
            }

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
            print("   🔌 Found plugin: \(pluginName) by \(manufacturer)")
        }

        return plugins
    }

    // MARK: - Deep Search (fallback)

    private static func deepSearchTracks(in plist: [String: Any], concertName: String) -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []

        func searchForPlugins(in dict: Any) -> [[String: Any]] {
            var found: [[String: Any]] = []

            if let dict = dict as? [String: Any] {
                if dict["Name"] != nil || dict["PluginName"] != nil || dict["BundleID"] != nil {
                    found.append(dict)
                }

                for (_, value) in dict {
                    found.append(contentsOf: searchForPlugins(in: value))
                }
            } else if let array = dict as? [Any] {
                for item in array {
                    found.append(contentsOf: searchForPlugins(in: item))
                }
            }

            return found
        }

        let foundPlugins = searchForPlugins(in: plist)

        if !foundPlugins.isEmpty {
            let plugins = parsePlugins(from: foundPlugins, trackName: concertName, trackIndex: 0)

            if !plugins.isEmpty {
                tracks.append(ParsedTrack(
                    name: concertName,
                    index: 0,
                    plugins: plugins
                ))
            }
        }

        return tracks
    }

    // MARK: - Metadata Extraction

    private static func extractTempo(from plist: [String: Any]) -> Double? {
        plist["Tempo"] as? Double
            ?? plist["DefaultTempo"] as? Double
            ?? plist["InitialTempo"] as? Double
    }

    private static func extractSampleRate(from plist: [String: Any]) -> Int? {
        plist["SampleRate"] as? Int
            ?? plist["ProjectSampleRate"] as? Int
            ?? plist["AudioSampleRate"] as? Int
    }

    private static func extractVersion(from plist: [String: Any]) -> String? {
        if let version = plist["Version"] as? String {
            return "MainStage \(version)"
        }
        if let version = plist["ApplicationVersion"] as? String {
            return "MainStage \(version)"
        }
        return plist["MainStageVersion"] as? String
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
            return .AU  // Default for MainStage
        }
    }

    private static func extractPluginNameFromBundle(_ bundleID: String, fallback: String) -> String {
        let components = bundleID.components(separatedBy: ".")
        if let last = components.last, !last.isEmpty {
            return last
        }
        return fallback
    }

    private static func cleanPluginName(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: " (mono)", with: "")
            .replacingOccurrences(of: " (stereo)", with: "")
            .replacingOccurrences(of: " AU", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let match = cleaned.range(of: #"\s+\d+(\.\d+)*$"#, options: .regularExpression) {
            cleaned.removeSubrange(match)
        }

        return cleaned
    }
}
