//
//  ReaperParser.swift
//  Plugin Reporter
//
//  Parser for Reaper project files (.rpp, .rpp-bak)
//  Reaper uses a plain text format with clear hierarchical structure
//

import Foundation

/// Parser for Reaper (Cockos) project files
class ReaperParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .reaper
    static let supportedExtensions: [String] = ["rpp", "rpp-bak"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the plain text file
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Parse the project
        let parser = ReaperProjectParser()
        let projectData = try parser.parse(lines: lines)

        // Validate
        guard !projectData.tracks.isEmpty else {
            throw ParserError.invalidProjectData("No tracks found in Reaper project")
        }

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: .reaper, tracks: projectData.tracks, tempo: projectData.tempo, sampleRate: projectData.sampleRate, version: projectData.version, key: nil
        )
    }
}

// MARK: - Project Parser

private class ReaperProjectParser {

    var tempo: Double?
    var sampleRate: Int?
    var version: String?
    var tracks: [ParsedTrack] = []

    private var currentTrackName: String?
    private var currentTrackIndex = 0
    private var currentPlugins: [ParsedPlugin] = []
    private var indentLevel = 0

    func parse(lines: [String]) throws -> (tracks: [ParsedTrack], tempo: Double?, sampleRate: Int?, version: String?) {
        var lineIndex = 0

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                lineIndex += 1
                continue
            }

            // Extract Reaper version
            if trimmed.hasPrefix("<REAPER_PROJECT") {
                version = extractVersion(from: trimmed)
            }

            // Extract tempo (BPM)
            else if trimmed.hasPrefix("TEMPO") {
                tempo = extractTempo(from: trimmed)
            }

            // Extract sample rate
            else if trimmed.hasPrefix("SAMPLERATE") {
                sampleRate = extractSampleRate(from: trimmed)
            }

            // Track detection
            else if trimmed.hasPrefix("<TRACK") {
                // Parse the entire track block
                let (track, nextIndex) = try parseTrack(lines: lines, startIndex: lineIndex)
                if let track = track {
                    tracks.append(track)
                }
                lineIndex = nextIndex
                continue
            }

            lineIndex += 1
        }

        return (tracks: tracks, tempo: tempo, sampleRate: sampleRate, version: version)
    }

    // MARK: - Track Parsing

    private func parseTrack(lines: [String], startIndex: Int) throws -> (ParsedTrack?, Int) {
        var lineIndex = startIndex + 1
        var trackName = "Track \(currentTrackIndex + 1)"
        var plugins: [ParsedPlugin] = []
        var deviceIndex = 0
        var nestingLevel = 1  // We're inside a TRACK block

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Track opening of nested blocks
            if trimmed.hasPrefix("<") && !trimmed.hasPrefix("</") {
                nestingLevel += 1
            }

            // Track closing of blocks
            if trimmed.hasPrefix(">") {
                nestingLevel -= 1
                if nestingLevel == 0 {
                    // End of TRACK block
                    break
                }
            }

            // Extract track name
            if trimmed.hasPrefix("NAME") {
                trackName = extractTrackName(from: trimmed)
            }

            // VST plugin detection
            else if trimmed.hasPrefix("<VST") {
                if let plugin = parseVSTPlugin(from: trimmed, trackName: trackName, trackIndex: currentTrackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }

            // VST3 plugin detection
            else if trimmed.hasPrefix("<VST3") {
                if let plugin = parseVST3Plugin(from: trimmed, trackName: trackName, trackIndex: currentTrackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }

            // AU plugin detection
            else if trimmed.hasPrefix("<AU") {
                if let plugin = parseAUPlugin(from: trimmed, trackName: trackName, trackIndex: currentTrackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }

            // JS (Reaper native) plugin detection
            else if trimmed.hasPrefix("<JS") {
                if let plugin = parseJSPlugin(from: trimmed, trackName: trackName, trackIndex: currentTrackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }

            // CLAP plugin detection (Reaper 6.68+)
            else if trimmed.hasPrefix("<CLAP") {
                if let plugin = parseCLAPPlugin(from: trimmed, trackName: trackName, trackIndex: currentTrackIndex, deviceIndex: deviceIndex) {
                    plugins.append(plugin)
                    deviceIndex += 1
                }
            }

            lineIndex += 1
        }

        // Only create track if it has plugins
        let track: ParsedTrack?
        if !plugins.isEmpty {
            track = ParsedTrack(
                name: trackName, index: currentTrackIndex, plugins: plugins
            )
            currentTrackIndex += 1
        } else {
            track = nil
        }

        return (track, lineIndex + 1)
    }

    // MARK: - Plugin Parsing

    private func parseVSTPlugin(from line: String, trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Format: <VST "VST: FabFilter Pro-Q 3 (FabFilter)" FabFilterProQ3.vst
        // Or: <VST "VST: PluginName (Manufacturer)" filename

        guard let pluginInfo = extractQuotedString(from: line) else { return nil }

        // Remove "VST: " prefix
        var cleanInfo = pluginInfo
        if cleanInfo.hasPrefix("VST: ") {
            cleanInfo = String(cleanInfo.dropFirst(5))
        } else if cleanInfo.hasPrefix("VST2: ") {
            cleanInfo = String(cleanInfo.dropFirst(6))
        }

        // Extract plugin name and manufacturer
        // Format: "PluginName (Manufacturer)" or just "PluginName"
        let (name, manufacturer) = extractNameAndManufacturer(from: cleanInfo)

        return ParsedPlugin(
            name: name, publisher: manufacturer, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: .VST
        )
    }

    private func parseVST3Plugin(from line: String, trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Format: <VST3 "VST3: FabFilter Pro-Q 3 (FabFilter)" {GUID}

        guard let pluginInfo = extractQuotedString(from: line) else { return nil }

        var cleanInfo = pluginInfo
        if cleanInfo.hasPrefix("VST3: ") {
            cleanInfo = String(cleanInfo.dropFirst(6))
        }

        let (name, manufacturer) = extractNameAndManufacturer(from: cleanInfo)

        return ParsedPlugin(
            name: name, publisher: manufacturer, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: .VST3
        )
    }

    private func parseAUPlugin(from line: String, trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Format: <AU "AU: PluginName (Manufacturer)" aumu/aufx manufacturer

        guard let pluginInfo = extractQuotedString(from: line) else { return nil }

        var cleanInfo = pluginInfo
        if cleanInfo.hasPrefix("AU: ") {
            cleanInfo = String(cleanInfo.dropFirst(4))
        }

        let (name, manufacturer) = extractNameAndManufacturer(from: cleanInfo)

        return ParsedPlugin(
            name: name, publisher: manufacturer, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: .AU
        )
    }

    private func parseJSPlugin(from line: String, trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Format: <JS "JS: PluginName" filename.jsfx

        guard let pluginInfo = extractQuotedString(from: line) else { return nil }

        var cleanInfo = pluginInfo
        if cleanInfo.hasPrefix("JS: ") {
            cleanInfo = String(cleanInfo.dropFirst(4))
        }

        // JS plugins are Reaper native
        return ParsedPlugin(
            name: cleanInfo, publisher: "Cockos (Reaper)", trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: .VST3  // Treat as VST3 for compatibility
        )
    }

    private func parseCLAPPlugin(from line: String, trackName: String, trackIndex: Int, deviceIndex: Int) -> ParsedPlugin? {
        // Format: <CLAP "CLAP: PluginName (Manufacturer)" {ID}

        guard let pluginInfo = extractQuotedString(from: line) else { return nil }

        var cleanInfo = pluginInfo
        if cleanInfo.hasPrefix("CLAP: ") {
            cleanInfo = String(cleanInfo.dropFirst(6))
        }

        let (name, manufacturer) = extractNameAndManufacturer(from: cleanInfo)

        return ParsedPlugin(
            name: name, publisher: manufacturer, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: .CLAP
        )
    }

    // MARK: - Metadata Extraction

    private func extractVersion(from line: String) -> String? {
        // Format: <REAPER_PROJECT 0.1 "6.82" 1234567890
        let components = line.components(separatedBy: "\"")
        if components.count >= 2 {
            return "Reaper \(components[1])"
        }
        return nil
    }

    private func extractTempo(from line: String) -> Double? {
        // Format: TEMPO 120 4 4
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 2, let tempo = Double(components[1]) {
            return tempo
        }
        return nil
    }

    private func extractSampleRate(from line: String) -> Int? {
        // Format: SAMPLERATE 48000 0 0
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 2, let rate = Int(components[1]) {
            return rate
        }
        return nil
    }

    private func extractTrackName(from line: String) -> String {
        // Format: NAME "My Track Name"
        if let name = extractQuotedString(from: line), !name.isEmpty {
            return name
        }
        return "Track \(currentTrackIndex + 1)"
    }

    // MARK: - Helper Methods

    private func extractQuotedString(from line: String) -> String? {
        // Extract text between quotes
        guard let firstQuote = line.firstIndex(of: "\"") else { return nil }
        let afterFirstQuote = line.index(after: firstQuote)
        guard let secondQuote = line[afterFirstQuote...].firstIndex(of: "\"") else { return nil }

        return String(line[afterFirstQuote..<secondQuote])
    }

    private func extractNameAndManufacturer(from string: String) -> (name: String, publisher: String) {
        // Format: "PluginName (Manufacturer)" or just "PluginName"

        // Look for manufacturer in parentheses
        if let openParen = string.lastIndex(of: "("), let closeParen = string.lastIndex(of: ")"), openParen < closeParen {

            let name = string[..<openParen].trimmingCharacters(in: .whitespaces)
            let manufacturer = string[string.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespaces)

            return (name, manufacturer.isEmpty ? "Unknown" : manufacturer)
        }

        // No manufacturer found
        return (string.trimmingCharacters(in: .whitespaces), "Unknown")
    }
}