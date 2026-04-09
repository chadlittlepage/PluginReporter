//
//  CubaseParser.swift
//  Plugin Reporter
//
//  Parser for Cubase and Nuendo project files (.cpr, .npr)
//  Binary RIFF-like format (Steinberg products)
//

import Foundation

/// Parser for Cubase and Nuendo project files
class CubaseParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .cubase
    static let supportedExtensions: [String] = ["cpr", "npr"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the binary file
        let data = try Data(contentsOf: url)

        // Parse binary format
        let parser = CubaseBinaryParser()
        try parser.parse(data: data)

        // Determine DAW type based on extension
        let dawType: DAWType = url.pathExtension.lowercased() == "npr" ? .nuendo : .cubase

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: dawType, tracks: parser.tracks, tempo: parser.tempo, sampleRate: parser.sampleRate, version: parser.version, key: nil
        )
    }
}

// MARK: - Nuendo Parser (Same format)

/// Parser for Nuendo project files (uses same parser as Cubase)
class NuendoParser: DAWParser {

    static let dawType: DAWType = .nuendo
    static let supportedExtensions: [String] = ["npr"]

    static func parseProject(url: URL) throws -> ParsedProject {
        // Delegate to Cubase parser (same format)
        return try CubaseParser.parseProject(url: url)
    }
}

// MARK: - Binary Parser

private class CubaseBinaryParser {

    var tempo: Double?
    var sampleRate: Int?
    var version: String?
    var tracks: [ParsedTrack] = []

    private var currentTrackName: String?
    private var currentTrackIndex = 0
    private var currentPlugins: [ParsedPlugin] = []
    private var currentDeviceIndex = 0
    private var currentPreset: String?

    func parse(data: Data) throws {
        print("\n🎹 CUBASE BINARY PARSING STARTED")
        print("   File size: \(data.count) bytes")

        // Extract all strings from binary data
        let strings = extractStrings(from: data)
        print("   Extracted \(strings.count) strings")

        // Parse version
        if let versionString = strings.first(where: { $0.contains("Cubase") && $0.contains("Version") }) {
            version = versionString
        }

        // Find plugin patterns
        var i = 0
        while i < strings.count {
            let str = strings[i]

            // Detect track names (preceded by "VST" or contains "DSP")
            if str.contains("VST") && str.contains("DSP") && !str.contains("Plugin") {
                currentTrackName = str
                print("🎵 Found track: \(str)")
            }

            // Detect "Plugin Name" marker
            if str == "Plugin Name" && i + 1 < strings.count {
                var pluginName = strings[i + 1]

                // Remove leading "#" (Cubase internal marker)
                if pluginName.hasPrefix("#") {
                    pluginName = String(pluginName.dropFirst())
                }

                // Look back for GUID
                var guid = ""
                if i >= 2 && strings[i - 2] == "GUID" {
                    guid = strings[i - 1]
                }

                // Determine format from GUID
                let format = detectFormat(from: guid, pluginName: pluginName)

                // Extract manufacturer (not always available in Cubase format)
                let manufacturer = extractManufacturer(from: pluginName, guid: guid)

                // Look ahead for preset information
                var preset = ""
                if i + 2 < strings.count {
                    // Look for preset_nameSi pattern followed by preset name
                    for j in (i + 2)..<min(i + 20, strings.count) {
                        if strings[j].contains("preset_name") && j + 1 < strings.count {
                            // Next string should be the preset name
                            var presetName = strings[j + 1]

                            // Filter out metadata strings
                            if !presetName.contains("Si") && !presetName.contains("preset") {
                                // Clean up Cubase delimiters (ends with "i" or contains "ipreset")
                                if presetName.hasSuffix("i") && !presetName.hasSuffix("Reverb i") {
                                    presetName = String(presetName.dropLast())
                                }

                                // Split on "ipreset" if it exists (e.g., "Defaultipreset_dirtyFi")
                                if let range = presetName.range(of: "ipreset") {
                                    presetName = String(presetName[..<range.lowerBound])
                                }

                                preset = presetName
                                print("   🎨 Found preset: \(presetName)")
                                break
                            }
                        }
                    }
                }

                // Skip built-in plugins unless it's a real plugin
                if !isBuiltInPlugin(pluginName) {
                    let plugin = ParsedPlugin(
                        name: pluginName, publisher: manufacturer, trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)", trackIndex: currentTrackIndex, deviceIndex: currentDeviceIndex, format: format, preset: preset
                    )
                    currentPlugins.append(plugin)
                    currentDeviceIndex += 1
                    print("   ✅ Added plugin: \(pluginName) [\(format.rawValue)] by \(manufacturer)\(preset.isEmpty ? "" : " - Preset: \(preset)")")
                }

                i += 1 // Skip the plugin name string
            }

            i += 1
        }

        // Create final track with plugins
        if !currentPlugins.isEmpty {
            let track = ParsedTrack(
                name: currentTrackName ?? "Main Track", index: 0, plugins: currentPlugins
            )
            tracks.append(track)
        }

        print("\n📊 CUBASE PARSING COMPLETE")
        print("   Total tracks: \(tracks.count)")
        print("   Total plugins: \(tracks.flatMap { $0.plugins }.count)")
        print("   Version: \(version ?? "not found")")
        print("---\n")
    }

    // MARK: - Helper Methods

    /// Extract readable strings from binary data
    private func extractStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var currentString = ""
        let minLength = 3 // Minimum string length to consider

        for byte in data {
            // Printable ASCII range (32-126) plus newline/tab
            if (byte >= 32 && byte <= 126) || byte == 9 || byte == 10 {
                currentString.append(Character(UnicodeScalar(byte)))
            } else {
                // End of string
                if currentString.count >= minLength {
                    let trimmed = currentString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        strings.append(trimmed)
                    }
                }
                currentString = ""
            }
        }

        // Add final string if any
        if currentString.count >= minLength {
            let trimmed = currentString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                strings.append(trimmed)
            }
        }

        return strings
    }

    /// Detect plugin format from GUID pattern
    private func detectFormat(from guid: String, pluginName: String) -> PluginFormat {
        // VST3 GUIDs are 32-character hex strings
        if guid.count == 32 || guid.hasPrefix("$") && guid.count == 33 {
            // Check if it looks like a VST2 ID (starts with numeric)
            let cleanGuid = guid.replacingOccurrences(of: "$", with: "")
            if cleanGuid.prefix(8).allSatisfy({ $0.isHexDigit }) {
                // VST2 uses 4-byte integers, VST3 uses full GUIDs
                return cleanGuid.count == 32 ? .VST3 : .VST
            }
            return .VST3
        }

        // Check plugin name for hints
        if pluginName.lowercased().contains("vst3") {
            return .VST3
        } else if pluginName.lowercased().contains("vst") {
            return .VST
        } else if pluginName.lowercased().contains("au") {
            return .AU
        }

        return .VST3 // Default for Cubase
    }

    /// Extract manufacturer from plugin name or GUID
    private func extractManufacturer(from pluginName: String, guid: String) -> String {
        // Try to extract from GUID if it contains readable text
        if guid.contains("UAD") || guid.contains("uad") {
            return "Universal Audio"
        }

        // Extract from plugin name prefix (# already stripped at this point)
        if pluginName.hasPrefix("UAD") {
            return "Universal Audio"
        }

        // Common manufacturer prefixes
        let prefixes = [
            "UADx": "Universal Audio", "UAD": "Universal Audio", "FabFilter": "FabFilter", "Waves": "Waves", "Soundtoys": "Soundtoys", "iZotope": "iZotope"
        ]

        for (prefix, manufacturer) in prefixes {
            if pluginName.hasPrefix(prefix) {
                return manufacturer
            }
        }

        return "Unknown"
    }

    /// Check if this is a built-in Cubase plugin or parameter (filter out)
    private func isBuiltInPlugin(_ name: String) -> Bool {
        let builtIns = [
            "Input Filter", "EQ", "Standard Panner", "Inserts", "Sends", "Audio Input Count", "Audio Output Count", "Audio Input Arrangement", "Audio Output Arrangement", "Event Input Count", "Event Output Count", "MIDI Input", "MIDI Output"
        ]

        return builtIns.contains(name)
    }
}