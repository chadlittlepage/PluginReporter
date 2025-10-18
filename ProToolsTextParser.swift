//
//  ProToolsTextParser.swift
//  Plugin Reporter
//
//  Parser for Pro Tools "Session Info as Text" export files
//  (File -> Export -> Session Info as Text in Pro Tools)
//

import Foundation

/// Parser for Pro Tools text export files (Protocol-based)
class ProToolsTextParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .proTools
    static let supportedExtensions: [String] = ["txt"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Parse the text file
        let session = try parseTextFile(url: url)

        // Validate this is actually a Pro Tools export
        guard !session.sessionName.isEmpty else {
            throw ParserError.invalidProjectData("Not a valid Pro Tools Session Info export file")
        }

        // Convert to standardized ParsedProject
        let tracks = session.tracks.enumerated().map { (index, track) -> ParsedTrack in
            let plugins = track.plugins.enumerated().map { (pluginIndex, pluginName) -> ParsedPlugin in
                // Extract plugin name and manufacturer from string like "SSL 4K E (mono)"
                let cleanName = pluginName.replacingOccurrences(of: " (mono)", with: "")
                    .replacingOccurrences(of: " (stereo)", with: "")
                    .trimmingCharacters(in: .whitespaces)

                // Try to match with plugin summary to get manufacturer
                // Use exact match first, then fuzzy match as fallback
                var manufacturer = "Unknown"
                var pluginFormat = "AAX Native"

                if let matchedPlugin = session.plugins.first(where: { $0.pluginName == cleanName }) {
                    manufacturer = matchedPlugin.manufacturer
                    pluginFormat = matchedPlugin.format
                } else if let matchedPlugin = session.plugins.first(where: { $0.pluginName.contains(cleanName) || cleanName.contains($0.pluginName) }) {
                    manufacturer = matchedPlugin.manufacturer
                    pluginFormat = matchedPlugin.format
                }

                // Map plugin format string to PluginFormat enum
                let format: PluginFormat = {
                    if pluginFormat.contains("AAX") { return .AAX }
                    else if pluginFormat.contains("RTAS") { return .OBSLT }
                    else if pluginFormat.contains("AU") { return .AU }
                    else if pluginFormat.contains("VST3") { return .VST3 }
                    else if pluginFormat.contains("VST") { return .VST }
                    else { return .AAX }  // Default for Pro Tools
                }()

                return ParsedPlugin(
                    name: cleanName,
                    manufacturer: manufacturer,
                    trackName: track.name,
                    trackIndex: index,
                    deviceIndex: pluginIndex,
                    format: format
                )
            }

            return ParsedTrack(
                name: track.name,
                index: index,
                plugins: plugins
            )
        }

        return ParsedProject(
            name: session.sessionName,
            sourceFile: url,
            dawType: .proTools,
            tracks: tracks,
            tempo: nil,
            sampleRate: Int(session.sampleRate),
            version: nil,
            key: nil
        )
    }

    // MARK: - Internal Parsing

    private static func parseTextFile(url: URL) throws -> ProToolsSessionData {
        // Try UTF-8 first, then fall back to ISO Latin 1 (common for Pro Tools exports)
        let content: String
        if let utf8Content = try? String(contentsOf: url, encoding: .utf8) {
            content = utf8Content
        } else {
            content = try String(contentsOf: url, encoding: .isoLatin1)
        }

        let lines = content.components(separatedBy: .newlines)

        var sessionName = ""
        var sampleRate: Double = 0
        var bitDepth = ""
        var timecode = ""
        var timecodeFormat = ""
        var audioTrackCount = 0
        var audioClipCount = 0
        var audioFileCount = 0
        var tracks: [ProToolsTrackData] = []
        var plugins: [ProToolsPluginData] = []

        var currentSection = ""
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Parse header info
            if line.hasPrefix("SESSION NAME:") {
                sessionName = extractValue(from: line, after: "SESSION NAME:")
            } else if line.hasPrefix("SAMPLE RATE:") {
                if let rate = Double(extractValue(from: line, after: "SAMPLE RATE:")) {
                    sampleRate = rate
                }
            } else if line.hasPrefix("BIT DEPTH:") {
                bitDepth = extractValue(from: line, after: "BIT DEPTH:")
            } else if line.hasPrefix("SESSION START TIMECODE:") {
                timecode = extractValue(from: line, after: "SESSION START TIMECODE:")
            } else if line.hasPrefix("TIMECODE FORMAT:") {
                timecodeFormat = extractValue(from: line, after: "TIMECODE FORMAT:")
            } else if line.hasPrefix("# OF AUDIO TRACKS:") {
                audioTrackCount = Int(extractValue(from: line, after: "# OF AUDIO TRACKS:")) ?? 0
            } else if line.hasPrefix("# OF AUDIO CLIPS:") {
                audioClipCount = Int(extractValue(from: line, after: "# OF AUDIO CLIPS:")) ?? 0
            } else if line.hasPrefix("# OF AUDIO FILES:") {
                audioFileCount = Int(extractValue(from: line, after: "# OF AUDIO FILES:")) ?? 0
            }

            // Detect sections
            if line.contains("P L U G - I N S  L I S T I N G") {
                currentSection = "PLUGINS"
                i += 1 // Skip header
                i += 1 // Skip column headers
                continue
            } else if line.contains("T R A C K  L I S T I N G") {
                currentSection = "TRACKS"
                i += 1
                continue
            }

            // Parse plugins section
            if currentSection == "PLUGINS" && !line.isEmpty {
                if line.hasPrefix("MANUFACTURER") || line.hasPrefix("TRACK NAME:") {
                    // End of plugins section
                    currentSection = ""
                } else {
                    let plugin = parsePluginLine(line, lastManufacturer: plugins.last?.manufacturer)
                    if !plugin.pluginName.isEmpty {
                        plugins.append(plugin)
                    }
                }
            }

            // Parse tracks section
            if currentSection == "TRACKS" && line.hasPrefix("TRACK NAME:") {
                let track = parseTrack(lines: lines, startIndex: i)
                tracks.append(track)
            }

            i += 1
        }

        return ProToolsSessionData(
            sessionName: sessionName,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            timecode: timecode,
            timecodeFormat: timecodeFormat,
            audioTrackCount: audioTrackCount,
            audioClipCount: audioClipCount,
            audioFileCount: audioFileCount,
            tracks: tracks,
            plugins: plugins
        )
    }

    private static func extractValue(from line: String, after prefix: String) -> String {
        guard let range = line.range(of: prefix) else { return "" }
        return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
    }

    private static func parsePluginLine(_ line: String, lastManufacturer: String? = nil) -> ProToolsPluginData {
        // Split by tabs (Pro Tools uses tabs as delimiter)
        let components = line.components(separatedBy: "\t").filter { !$0.isEmpty }

        guard components.count >= 6 else {
            return ProToolsPluginData(
                manufacturer: "",
                pluginName: "",
                version: "",
                format: "",
                stems: "",
                instanceCount: ""
            )
        }

        // Handle manufacturer continuation pattern:
        // Pro Tools lists manufacturer once, then subsequent plugins from same vendor have empty manufacturer field
        let manufacturer = components[0].trimmingCharacters(in: .whitespaces)
        let finalManufacturer = manufacturer.isEmpty ? (lastManufacturer ?? "") : manufacturer

        return ProToolsPluginData(
            manufacturer: finalManufacturer,
            pluginName: components[1].trimmingCharacters(in: .whitespaces),
            version: components[2].trimmingCharacters(in: .whitespaces),
            format: components[3].trimmingCharacters(in: .whitespaces),
            stems: components[4].trimmingCharacters(in: .whitespaces),
            instanceCount: components[5].trimmingCharacters(in: .whitespaces)
        )
    }

    private static func parseTrack(lines: [String], startIndex: Int) -> ProToolsTrackData {
        var trackName = ""
        var comments = ""
        var userDelay = ""
        var state = ""
        var plugins: [String] = []

        var i = startIndex

        // Parse track name
        if lines[i].hasPrefix("TRACK NAME:") {
            trackName = extractValue(from: lines[i], after: "TRACK NAME:")
            i += 1
        }

        // Parse comments
        if i < lines.count && lines[i].hasPrefix("COMMENTS:") {
            comments = extractValue(from: lines[i], after: "COMMENTS:")
            i += 1
        }

        // Parse user delay
        if i < lines.count && lines[i].hasPrefix("USER DELAY:") {
            userDelay = extractValue(from: lines[i], after: "USER DELAY:")
            i += 1
        }

        // Parse state
        if i < lines.count && lines[i].hasPrefix("STATE:") {
            state = extractValue(from: lines[i], after: "STATE:")
            i += 1
        }

        // Parse plugins
        if i < lines.count && lines[i].hasPrefix("PLUG-INS:") {
            let pluginLine = extractValue(from: lines[i], after: "PLUG-INS:")
            if !pluginLine.isEmpty {
                // Split by tabs to get individual plugins
                plugins = pluginLine.components(separatedBy: "\t")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }

        return ProToolsTrackData(
            name: trackName,
            comments: comments,
            userDelay: userDelay,
            state: state,
            plugins: plugins
        )
    }
}

// MARK: - Internal Data Models

private struct ProToolsSessionData {
    let sessionName: String
    let sampleRate: Double
    let bitDepth: String
    let timecode: String
    let timecodeFormat: String
    let audioTrackCount: Int
    let audioClipCount: Int
    let audioFileCount: Int
    let tracks: [ProToolsTrackData]
    let plugins: [ProToolsPluginData]
}

private struct ProToolsTrackData {
    let name: String
    let comments: String
    let userDelay: String
    let state: String
    let plugins: [String]  // Plugin names like "SSL 4K E (mono)"
}

private struct ProToolsPluginData {
    let manufacturer: String
    let pluginName: String
    let version: String
    let format: String  // "AAX Native", etc.
    let stems: String   // "Mono / Mono", "Stereo / Stereo", etc.
    let instanceCount: String
}
