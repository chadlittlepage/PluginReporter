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

        let session = try parseTextFile(url: url)

        guard !session.sessionName.isEmpty else {
            throw ParserError.invalidProjectData("Not a valid Pro Tools Session Info export file")
        }

        // Log extracted metadata
        print("📊 Pro Tools Session Metadata:")
        print("   • Name: \(session.sessionName)")
        print("   • Sample Rate: \(Int(session.sampleRate)) Hz")
        if !session.bitDepth.isEmpty {
            print("   • Bit Depth: \(session.bitDepth)")
        }
        if !session.timecodeFormat.isEmpty {
            print("   • Timecode Format: \(session.timecodeFormat)")
        }
        if !session.sessionStartTimecode.isEmpty {
            print("   • Start Timecode: \(session.sessionStartTimecode)")
        }
        print("   • Tracks: \(session.tracks.count)")
        print("   • Total Plugins: \(session.plugins.count)")

        // Convert to standardized ParsedProject
        var allTracks: [ParsedTrack] = []
        var pluginsFoundOnTracks: Set<String> = []

        // First, process all audio tracks from TRACK LISTING
        let audioTracks = session.tracks.enumerated().map { (index, track) -> ParsedTrack in
            let plugins = track.plugins.enumerated().map { (pluginIndex, pluginName) -> ParsedPlugin in
                // Clean plugin name (remove stereo/mono suffixes)
                let cleanName = pluginName
                    .replacingOccurrences(of: " (mono)", with: "")
                    .replacingOccurrences(of: " (stereo)", with: "")
                    .trimmingCharacters(in: .whitespaces)

                // Track which plugins we've found on audio tracks
                pluginsFoundOnTracks.insert(cleanName)

                // Match with plugin summary to get manufacturer and format
                var manufacturer = "Unknown"
                var pluginFormat = "AAX Native"

                if let matchedPlugin = session.plugins.first(where: { $0.pluginName == cleanName }) {
                    manufacturer = matchedPlugin.publisher
                    pluginFormat = matchedPlugin.format
                } else if let matchedPlugin = session.plugins.first(where: { $0.pluginName.contains(cleanName) || cleanName.contains($0.pluginName) }) {
                    manufacturer = matchedPlugin.publisher
                    pluginFormat = matchedPlugin.format
                }

                // Fallback: detect manufacturer from plugin name
                if manufacturer == "Unknown" || manufacturer.isEmpty {
                    manufacturer = detectManufacturerFromName(cleanName)
                }

                // Map plugin format string to PluginFormat enum
                let format: PluginFormat = {
                    if pluginFormat.contains("AAX") { return .AAX } else if pluginFormat.contains("RTAS") { return .OBSLT } else if pluginFormat.contains("AU") { return .AU } else if pluginFormat.contains("VST3") { return .VST3 } else if pluginFormat.contains("VST") { return .VST } else { return .AAX }  // Default for Pro Tools
                }()

                // Get version from matched plugin
                var version = ""
                if let matchedPlugin = session.plugins.first(where: { $0.pluginName == cleanName }) {
                    version = matchedPlugin.version
                } else if let matchedPlugin = session.plugins.first(where: { $0.pluginName.contains(cleanName) || cleanName.contains($0.pluginName) }) {
                    version = matchedPlugin.version
                }

                return ParsedPlugin(
                    name: cleanName,
                    publisher: manufacturer,
                    trackName: track.name,
                    trackIndex: index,
                    deviceIndex: pluginIndex,
                    type: format.rawValue,
                    version: version  // Pass through version
                )
            }

            return ParsedTrack(
                name: track.name,
                index: index,
                plugins: plugins
            )
        }

        allTracks.append(contentsOf: audioTracks)

        // Now add plugins from PLUGINS LISTING that weren't on any audio track
        // These are likely on MIDI/Instrument/Aux/Bus/Master tracks
        var otherTrackPlugins: [ParsedPlugin] = []

        for (index, pluginData) in session.plugins.enumerated() {
            if !pluginsFoundOnTracks.contains(pluginData.pluginName) {
                // Map plugin format string to PluginFormat enum
                let format: PluginFormat = {
                    if pluginData.format.contains("AAX") { return .AAX } else if pluginData.format.contains("RTAS") { return .OBSLT } else if pluginData.format.contains("AU") { return .AU } else if pluginData.format.contains("VST3") { return .VST3 } else if pluginData.format.contains("VST") { return .VST } else { return .AAX }
                }()

                // Determine likely track type based on plugin characteristics
                let trackType = categorizePlugin(pluginData.pluginName, manufacturer: pluginData.publisher)

                let plugin = ParsedPlugin(
                    name: pluginData.pluginName,
                    publisher: pluginData.publisher.isEmpty ? detectManufacturerFromName(pluginData.pluginName) : pluginData.publisher,
                    trackName: trackType,
                    trackIndex: audioTracks.count, // These come after audio tracks
                    deviceIndex: index,
                    type: format.rawValue,
                    version: pluginData.version  // Pass through version
                )

                otherTrackPlugins.append(plugin)
            }
        }

        // Group "other" plugins by their track type
        let groupedOtherPlugins = Dictionary(grouping: otherTrackPlugins, by: { $0.trackName })

        for (trackName, plugins) in groupedOtherPlugins.sorted(by: { $0.key < $1.key }) {
            let track = ParsedTrack(
                name: trackName,
                index: allTracks.count,
                plugins: plugins.enumerated().map { (index, plugin) in
                    ParsedPlugin(
                        name: plugin.name,
                        publisher: plugin.publisher,
                        trackName: trackName,
                        trackIndex: allTracks.count,
                        deviceIndex: index,
                        type: plugin.type  // Use type string directly
                    )
                }
            )
            allTracks.append(track)
        }

        // Construct comprehensive version string from all metadata
        var versionComponents: [String] = []
        if !session.bitDepth.isEmpty {
            versionComponents.append(session.bitDepth)
        }
        if !session.timecodeFormat.isEmpty {
            versionComponents.append(session.timecodeFormat)
        }
        let versionString = versionComponents.isEmpty ? nil : versionComponents.joined(separator: " • ")

        return ParsedProject(
            name: session.sessionName,
            sourceFile: url,
            dawType: .proTools,
            tracks: allTracks,
            tempo: nil,
            sampleRate: Int(session.sampleRate),
            version: versionString,
            key: session.sessionStartTimecode.isEmpty ? nil : session.sessionStartTimecode
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
        var bitDepth: String = ""
        var timecodeFormat: String = ""
        var sessionStartTimecode: String = ""
        var tracks: [ProToolsTrackData] = []
        var plugins: [ProToolsPluginData] = []

        var currentSection = ""
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Parse ALL header metadata
            if line.hasPrefix("SESSION NAME:") {
                sessionName = extractValue(from: line, after: "SESSION NAME:")
            } else if line.hasPrefix("SAMPLE RATE:") {
                if let rate = Double(extractValue(from: line, after: "SAMPLE RATE:")) {
                    sampleRate = rate
                }
            } else if line.hasPrefix("BIT DEPTH:") {
                bitDepth = extractValue(from: line, after: "BIT DEPTH:")
            } else if line.hasPrefix("TIMECODE FORMAT:") {
                timecodeFormat = extractValue(from: line, after: "TIMECODE FORMAT:")
            } else if line.hasPrefix("SESSION START TIMECODE:") {
                sessionStartTimecode = extractValue(from: line, after: "SESSION START TIMECODE:")
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
                    currentSection = ""
                } else {
                    let plugin = parsePluginLine(line, lastManufacturer: plugins.last?.publisher)
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
            timecodeFormat: timecodeFormat,
            sessionStartTimecode: sessionStartTimecode,
            tracks: tracks,
            plugins: plugins
        )
    }

    private static func extractValue(from line: String, after prefix: String) -> String {
        guard let range = line.range(of: prefix) else { return "" }
        return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
    }

    private static func detectManufacturerFromName(_ pluginName: String) -> String {
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

    private static func categorizePlugin(_ pluginName: String, manufacturer: String) -> String {
        let lower = pluginName.lowercased()

        // Virtual instruments / Synths
        if lower.contains("xpand") || lower.contains("mini grand") || lower.contains("groovecell") ||
           lower.contains("kontakt") || lower.contains("massive") || lower.contains("serum") ||
           lower.contains("omnisphere") || lower.contains("keyscape") || lower.contains("diva") ||
           lower.contains("zebra") || lower.contains("synth") || lower.contains("piano") ||
           lower.contains("organ") || lower.contains("strings") || lower.contains("brass") {
            return "MIDI / Instrument Tracks"
        }

        // MIDI effects / note processing
        if lower.contains("note stack") || lower.contains("velocity control") ||
           lower.contains("pitch control") || lower.contains("arpeggiator") ||
           lower.contains("chord") {
            return "MIDI / Instrument Tracks"
        }

        // Reverb / Delay (often on Aux/Send tracks)
        if lower.contains("reverb") || lower.contains("delay") || lower.contains("echo") ||
           lower.contains("mod delay") {
            return "Aux / Bus / Master Tracks"
        }

        // Dynamics processors (often on Master/Bus)
        if lower.contains("limiter") || lower.contains("maximizer") ||
           lower.contains("compressor") || lower.contains("dyn3") ||
           lower.contains("impact") {
            return "Aux / Bus / Master Tracks"
        }

        // EQs and filters (often on Master/Bus)
        if lower.contains("eq") || lower.contains("equalizer") ||
           lower.contains("filter") {
            return "Aux / Bus / Master Tracks"
        }

        // Saturation / Distortion (often on Master/Bus)
        if lower.contains("saturation") || lower.contains("tape") ||
           lower.contains("distortion") || lower.contains("overdrive") {
            return "Aux / Bus / Master Tracks"
        }

        // Modulation effects (often on Aux/Send)
        if lower.contains("chorus") || lower.contains("flanger") ||
           lower.contains("phaser") || lower.contains("tremolo") ||
           lower.contains("vibrato") {
            return "Aux / Bus / Master Tracks"
        }

        // Spatial / Stereo (often on Aux/Bus/Master)
        if lower.contains("stereo") || lower.contains("width") ||
           lower.contains("pan") || lower.contains("imager") {
            return "Aux / Bus / Master Tracks"
        }

        // Utility plugins
        if lower.contains("click") || lower.contains("tuner") {
            return "Utility Tracks"
        }

        // Default to Aux/Bus/Master (more likely than "Other")
        return "Aux / Bus / Master Tracks"
    }

    private static func parsePluginLine(_ line: String, lastManufacturer: String? = nil) -> ProToolsPluginData {
        let components = line.components(separatedBy: "\t").filter { !$0.isEmpty }

        guard components.count >= 4 else {
            return ProToolsPluginData(publisher: "", pluginName: "", version: "", format: "")
        }

        // Handle manufacturer continuation pattern
        let manufacturer = components[0].trimmingCharacters(in: .whitespaces)
        let finalManufacturer = manufacturer.isEmpty ? (lastManufacturer ?? "") : manufacturer

        return ProToolsPluginData(
            publisher: finalManufacturer,
            pluginName: components[1].trimmingCharacters(in: .whitespaces),
            version: components[2].trimmingCharacters(in: .whitespaces),
            format: components[3].trimmingCharacters(in: .whitespaces)
        )
    }

    private static func parseTrack(lines: [String], startIndex: Int) -> ProToolsTrackData {
        var trackName = ""
        var plugins: [String] = []
        var i = startIndex

        // Parse track name
        if lines[i].hasPrefix("TRACK NAME:") {
            trackName = extractValue(from: lines[i], after: "TRACK NAME:")
            i += 1
        }

        // Skip to plugins line
        while i < lines.count {
            if lines[i].hasPrefix("PLUG-INS:") {
                let pluginLine = extractValue(from: lines[i], after: "PLUG-INS:")
                if !pluginLine.isEmpty {
                    plugins = pluginLine.components(separatedBy: "\t")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
                break
            }
            i += 1
        }

        return ProToolsTrackData(name: trackName, plugins: plugins)
    }
}

// MARK: - Internal Data Models

private struct ProToolsSessionData {
    let sessionName: String
    let sampleRate: Double
    let bitDepth: String
    let timecodeFormat: String
    let sessionStartTimecode: String
    let tracks: [ProToolsTrackData]
    let plugins: [ProToolsPluginData]
}

private struct ProToolsTrackData {
    let name: String
    let plugins: [String]
}

private struct ProToolsPluginData {
    let publisher: String
    let pluginName: String
    let version: String
    let format: String
}
