//
//  FairlightParser.swift
//  Plugin Reporter
//
//  Parser for Fairlight/DaVinci Resolve project files (.drp)
//  Fairlight is the audio component of DaVinci Resolve
//  Uses binary format with embedded database - requires string extraction
//

import Foundation

/// Parser for Fairlight/DaVinci Resolve project files
class FairlightParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .fairlight
    static let supportedExtensions: [String] = ["drp"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the binary file
        let data = try Data(contentsOf: url)

        // Extract strings from binary data
        let strings = extractStrings(from: data)

        // Parse plugin information from extracted strings
        let parser = FairlightDataParser(strings: strings)
        let tracks = parser.parseTracks()

        // Extract metadata
        let tempo = parser.extractTempo()
        let sampleRate = parser.extractSampleRate()
        let version = parser.extractVersion()

        guard !tracks.isEmpty else {
            throw ParserError.invalidProjectData("No Fairlight audio tracks or plugins found in project")
        }

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .fairlight,
            tracks: tracks,
            tempo: tempo,
            sampleRate: sampleRate,
            version: version,
            key: nil
        )
    }

    // MARK: - String Extraction

    private static func extractStrings(from data: Data, minLength: Int = 4) -> [String] {
        var strings: [String] = []
        var currentString = ""
        var currentBytes: [UInt8] = []

        for byte in data {
            // Printable ASCII range (including extended)
            if (byte >= 32 && byte <= 126) || byte == 9 || byte == 10 || byte == 13 {
                currentBytes.append(byte)
            } else if byte == 0 && !currentBytes.isEmpty {
                // Null terminator - end of string
                if let string = String(bytes: currentBytes, encoding: .utf8),
                   string.count >= minLength {
                    strings.append(string)
                }
                currentBytes = []
            } else if !currentBytes.isEmpty {
                // Non-ASCII byte - end current string
                if let string = String(bytes: currentBytes, encoding: .utf8),
                   string.count >= minLength {
                    strings.append(string)
                }
                currentBytes = []
            }
        }

        // Handle final string if exists
        if !currentBytes.isEmpty,
           let string = String(bytes: currentBytes, encoding: .utf8),
           string.count >= minLength {
            strings.append(string)
        }

        return strings
    }
}

// MARK: - Data Parser

private class FairlightDataParser {

    private let strings: [String]

    init(strings: [String]) {
        self.strings = strings
    }

    // MARK: - Track Parsing

    func parseTracks() -> [ParsedTrack] {
        var tracks: [ParsedTrack] = []
        var currentTrackIndex = 0

        // Look for track and plugin patterns
        var potentialTracks: [String: [ParsedPlugin]] = [:]

        // Find plugins and their associated tracks
        for (index, string) in strings.enumerated() {
            // Plugin detection patterns
            if isLikelyPlugin(string) {
                let pluginName = string
                let manufacturer = findManufacturer(near: index)
                let format = detectPluginFormat(near: index)
                let trackName = findTrackName(near: index) ?? "Track \(potentialTracks.count + 1)"

                let plugin = ParsedPlugin(
                    name: cleanPluginName(pluginName),
                    manufacturer: manufacturer,
                    trackName: trackName,
                    trackIndex: potentialTracks[trackName]?.count ?? 0,
                    deviceIndex: potentialTracks[trackName]?.count ?? 0,
                    format: format
                )

                if potentialTracks[trackName] == nil {
                    potentialTracks[trackName] = []
                }
                potentialTracks[trackName]?.append(plugin)

                print("🔌 Found plugin: \(pluginName) on \(trackName)")
            }
        }

        // Convert to ParsedTrack objects
        for (trackName, plugins) in potentialTracks.sorted(by: { $0.key < $1.key }) {
            if !plugins.isEmpty {
                let track = ParsedTrack(
                    name: trackName,
                    index: currentTrackIndex,
                    plugins: plugins
                )
                tracks.append(track)
                currentTrackIndex += 1
                print("🎵 Added track '\(trackName)' with \(plugins.count) plugins")
            }
        }

        return tracks
    }

    // MARK: - Plugin Detection

    private func isLikelyPlugin(_ string: String) -> Bool {
        let lowerString = string.lowercased()

        // Known Fairlight/Resolve native plugins
        let nativeFairlightPlugins = [
            "fairlight fx",
            "channel strip",
            "parametric eq",
            "dynamics",
            "compressor",
            "limiter",
            "gate",
            "expander",
            "de-esser",
            "reverb",
            "delay",
            "chorus",
            "flanger",
            "phaser",
            "distortion",
            "modulation",
            "pitch",
            "vocal channel",
            "stereo fixer",
            "foley sampler"
        ]

        // Check for native Fairlight plugins
        for plugin in nativeFairlightPlugins {
            if lowerString.contains(plugin) && string.count < 100 {
                return true
            }
        }

        // Common plugin patterns
        let pluginPatterns = [
            "vst3", "vst", ".vst", ".component",
            "audio unit", "au plugin",
            "waves", "fabfilter", "soundtoys",
            "izotope", "slate", "universal audio",
            "plugin suite", "bundle"
        ]

        for pattern in pluginPatterns {
            if lowerString.contains(pattern) && string.count < 100 {
                return true
            }
        }

        // Check for plugin-like characteristics
        let hasPluginExtension = string.hasSuffix(".vst") ||
                                 string.hasSuffix(".vst3") ||
                                 string.hasSuffix(".component")

        let hasPluginWords = lowerString.contains("plugin") ||
                            lowerString.contains("effect") ||
                            lowerString.contains("processor")

        if hasPluginExtension || (hasPluginWords && string.count < 80) {
            return true
        }

        return false
    }

    private func findManufacturer(near index: Int) -> String {
        // Search nearby strings for manufacturer names
        let searchRange = max(0, index - 5)...min(strings.count - 1, index + 5)

        let manufacturers = [
            "Waves", "FabFilter", "Soundtoys", "iZotope", "Slate Digital",
            "Universal Audio", "Plugin Alliance", "Native Instruments",
            "Antares", "Celemony", "Eventide", "Lexicon", "TC Electronic",
            "Softube", "Brainworx", "SPL", "Sonnox", "McDSP",
            "Blackmagic Design", "Fairlight", "DaVinci"
        ]

        for i in searchRange {
            let string = strings[i]
            for manufacturer in manufacturers {
                if string.contains(manufacturer) {
                    return manufacturer
                }
            }
        }

        // Check if it's a native Fairlight plugin
        if strings[index].lowercased().contains("fairlight") {
            return "Fairlight"
        }

        return "Unknown"
    }

    private func findTrackName(near index: Int) -> String? {
        // Search nearby strings for track names
        let searchRange = max(0, index - 10)...min(strings.count - 1, index + 3)

        for i in searchRange {
            let string = strings[i]

            // Look for track-like patterns
            if string.hasPrefix("Track") || string.hasPrefix("Audio") ||
               string.hasPrefix("A") && string.count < 10 {
                return string
            }

            // Check for common track naming patterns
            let trackPatterns = ["Vocals", "Guitar", "Bass", "Drums", "Keys",
                               "Piano", "Synth", "Strings", "Brass", "Lead",
                               "Pad", "FX", "Dialogue", "Music", "SFX"]

            for pattern in trackPatterns {
                if string.contains(pattern) && string.count < 50 {
                    return string
                }
            }
        }

        return nil
    }

    private func detectPluginFormat(near index: Int) -> PluginFormat {
        let searchRange = max(0, index - 3)...min(strings.count - 1, index + 3)

        for i in searchRange {
            let string = strings[i].lowercased()

            if string.contains("vst3") {
                return .VST3
            } else if string.contains("vst") {
                return .VST
            } else if string.contains("au") || string.contains("audio unit") ||
                      string.contains(".component") {
                return .AU
            } else if string.contains("aax") {
                return .AAX
            }
        }

        // Default to VST3 for unknown
        return .VST3
    }

    // MARK: - Metadata Extraction

    func extractTempo() -> Double? {
        for string in strings {
            // Look for tempo patterns like "120.0 BPM" or "Tempo: 128"
            if string.lowercased().contains("bpm") || string.lowercased().contains("tempo") {
                // Extract numbers
                let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Double($0) }
                    .filter { $0 >= 40 && $0 <= 300 }  // Reasonable tempo range

                if let tempo = numbers.first {
                    return tempo
                }
            }
        }
        return nil
    }

    func extractSampleRate() -> Int? {
        for string in strings {
            // Look for common sample rates
            let commonRates = [44100, 48000, 88200, 96000, 176400, 192000]

            for rate in commonRates {
                if string.contains(String(rate)) {
                    return rate
                }
            }
        }
        return nil
    }

    func extractVersion() -> String? {
        for string in strings {
            // Look for DaVinci Resolve version patterns
            if string.contains("DaVinci Resolve") || string.contains("Resolve") {
                // Try to find version number nearby
                if let versionMatch = string.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
                    let version = String(string[versionMatch])
                    return "DaVinci Resolve \(version)"
                }
                return "DaVinci Resolve"
            }

            if string.contains("Fairlight") && string.contains("Version") {
                return string
            }
        }
        return nil
    }

    // MARK: - Helper Methods

    private func cleanPluginName(_ name: String) -> String {
        var cleaned = name
            // Remove file extensions
            .replacingOccurrences(of: ".vst3", with: "")
            .replacingOccurrences(of: ".vst", with: "")
            .replacingOccurrences(of: ".component", with: "")
            .replacingOccurrences(of: ".dll", with: "")
            // Remove format suffixes
            .replacingOccurrences(of: " VST3", with: "")
            .replacingOccurrences(of: " VST", with: "")
            .replacingOccurrences(of: " AU", with: "")
            .replacingOccurrences(of: " (mono)", with: "")
            .replacingOccurrences(of: " (stereo)", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Extract name from full path if needed
        if cleaned.contains("/") {
            cleaned = cleaned.components(separatedBy: "/").last ?? cleaned
        }
        if cleaned.contains("\\") {
            cleaned = cleaned.components(separatedBy: "\\").last ?? cleaned
        }

        return cleaned
    }
}
