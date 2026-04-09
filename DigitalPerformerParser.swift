//
//  DigitalPerformerParser.swift
//  Plugin Reporter
//
//  Parser for Digital Performer project files (.motu)
//  Digital Performer uses a proprietary binary format with embedded strings
//

import Foundation

/// Parser for Digital Performer (MOTU) project files
class DigitalPerformerParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .digitalPerformer
    static let supportedExtensions: [String] = ["dpdoc", "motu", "perf"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the binary file
        let data = try Data(contentsOf: url)

        // Extract readable strings from binary
        let strings = extractStrings(from: data)

        // Validate this is a DP file
        guard strings.contains(where: { $0.contains("Digital Performer") || $0.contains("MOTU") }) else {
            throw ParserError.invalidProjectData("Not a valid Digital Performer project file")
        }

        // Parse devices and plugins
        let devices = parseDevices(from: strings)

        guard !devices.isEmpty else {
            throw ParserError.invalidProjectData("No plugins found in Digital Performer project")
        }

        // Extract metadata
        let tempo = extractTempo(from: strings)
        let sampleRate = extractSampleRate(from: strings)
        let version = extractVersion(from: strings)

        // Group devices into tracks
        let tracks = groupDevicesIntoTracks(devices)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: .digitalPerformer, tracks: tracks, tempo: tempo, sampleRate: sampleRate, version: version, key: nil
        )
    }

    // MARK: - String Extraction

    private static func extractStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var currentString = Data()
        let minLength = 4

        // Extract ASCII and UTF-8 strings from binary
        for byte in data {
            // Printable ASCII characters
            if byte >= 0x20 && byte <= 0x7E {
                currentString.append(byte)
            } else {
                // End of string
                if currentString.count >= minLength {
                    if let string = String(data: currentString, encoding: .utf8) {
                        strings.append(string)
                    }
                }
                currentString = Data()
            }
        }

        // Last string
        if currentString.count >= minLength {
            if let string = String(data: currentString, encoding: .utf8) {
                strings.append(string)
            }
        }

        return strings
    }

    // MARK: - Device Parsing

    private struct DPDevice {
        let name: String
        let publisher: String
        let format: PluginFormat
        let trackName: String?
    }

    private static func parseDevices(from strings: [String]) -> [DPDevice] {
        var devices: [DPDevice] = []
        var seenDevices: Set<String> = []

        for (index, string) in strings.enumerated() {
            // AU plugins (primary format on macOS)
            if string.contains("AudioUnit") || string.hasSuffix(".component") {
                if let device = parseAUDevice(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST3 plugins
            else if string.hasSuffix(".vst3") || string.contains("VST3") {
                if let device = parseVST3Device(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST plugins
            else if string.hasSuffix(".vst") && !string.contains(".vst3") {
                if let device = parseVSTDevice(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // MAS plugins (MOTU Audio System - DP native)
            else if string.contains("MAS") || isMOTUNativePlugin(string) {
                if let device = parseMASDevice(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
        }

        return devices
    }

    private static func parseAUDevice(_ string: String, context: [String], index: Int) -> DPDevice? {
        // Extract plugin name from path or component name
        var pluginName = string
        if string.contains("/") {
            pluginName = string.components(separatedBy: "/").last ?? string
        }
        pluginName = pluginName
            .replacingOccurrences(of: ".component", with: "")
            .replacingOccurrences(of: "AudioUnit", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        var trackName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Look for manufacturer in nearby strings
            // BUT skip "MOTU" since that's the DAW manufacturer, not the plugin manufacturer
            let searchRange = max(0, index - 15)..<min(context.count, index + 15)
            for nearbyString in context[searchRange] {
                // Try to extract manufacturer from this string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    // SKIP if it's just the DAW manufacturer (MOTU for Digital Performer)
                    if extractedManufacturer != "MOTU" {
                        manufacturer = extractedManufacturer
                        break  // Found it, stop searching
                    }
                }
            }
        }

        // Look for track names
        let searchRange = max(0, index - 15)..<min(context.count, index + 15)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Track ") || nearbyString.contains("track:") {
                trackName = nearbyString
                break
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Check if it's an Apple plugin
        if pluginName.hasPrefix("AU") || string.contains("com.apple") {
            manufacturer = "Apple"
        }

        return DPDevice(
            name: pluginName, publisher: manufacturer, format: .AU, trackName: trackName
        )
    }

    private static func parseVST3Device(_ string: String, context: [String], index: Int) -> DPDevice? {
        var pluginName = string
        if string.contains("/") {
            pluginName = string.components(separatedBy: "/").last ?? string
        }
        pluginName = pluginName.replacingOccurrences(of: ".vst3", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        var trackName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Look for manufacturer in nearby strings
            // BUT skip "MOTU" since that's the DAW manufacturer, not the plugin manufacturer
            let searchRange = max(0, index - 15)..<min(context.count, index + 15)
            for nearbyString in context[searchRange] {
                // Try to extract manufacturer from this string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    // SKIP if it's just the DAW manufacturer (MOTU for Digital Performer)
                    if extractedManufacturer != "MOTU" {
                        manufacturer = extractedManufacturer
                        break  // Found it, stop searching
                    }
                }
            }
        }

        // Look for track names
        let searchRange = max(0, index - 15)..<min(context.count, index + 15)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Track ") || nearbyString.contains("track:") {
                trackName = nearbyString
                break
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return DPDevice(
            name: pluginName, publisher: manufacturer, format: .VST3, trackName: trackName
        )
    }

    private static func parseVSTDevice(_ string: String, context: [String], index: Int) -> DPDevice? {
        var pluginName = string
        if string.contains("/") {
            pluginName = string.components(separatedBy: "/").last ?? string
        }
        pluginName = pluginName.replacingOccurrences(of: ".vst", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        var trackName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Look for manufacturer in nearby strings
            // BUT skip "MOTU" since that's the DAW manufacturer, not the plugin manufacturer
            let searchRange = max(0, index - 15)..<min(context.count, index + 15)
            for nearbyString in context[searchRange] {
                // Try to extract manufacturer from this string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    // SKIP if it's just the DAW manufacturer (MOTU for Digital Performer)
                    if extractedManufacturer != "MOTU" {
                        manufacturer = extractedManufacturer
                        break  // Found it, stop searching
                    }
                }
            }
        }

        // Look for track names
        let searchRange = max(0, index - 15)..<min(context.count, index + 15)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Track ") || nearbyString.contains("track:") {
                trackName = nearbyString
                break
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return DPDevice(
            name: pluginName, publisher: manufacturer, format: .VST, trackName: trackName
        )
    }

    private static func parseMASDevice(_ string: String, context: [String], index: Int) -> DPDevice? {
        let deviceName = string
            .replacingOccurrences(of: "MAS", with: "")
            .trimmingCharacters(in: .whitespaces)

        var trackName: String?

        // Look for track context
        let searchRange = max(0, index - 10)..<min(context.count, index + 10)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Track ") || nearbyString.contains("track:") {
                trackName = nearbyString
            }
        }

        return DPDevice(
            name: deviceName, publisher: "MOTU", format: .AU, trackName: trackName
        )
    }

    // MARK: - MOTU Native Plugins

    private static func isMOTUNativePlugin(_ string: String) -> Bool {
        let motuPlugins = [
            // EQ
            "Parametric EQ", "MasterWorks EQ", "Precision EQ", "Leveler", "Compressor", "Multiband", "Dynamics", "ProVerb", "Delay", "Echo", "Chorus", "Flanger", "Phaser", "Tremolo", "Overdrive", "Tube", "Saturate", "Pitch Shift", "Time Stretch", "Trim", "Phase", "De-esser", "Gate"
        ]

        return motuPlugins.contains { string.contains($0) }
    }

    // MARK: - Track Grouping

    private static func groupDevicesIntoTracks(_ devices: [DPDevice]) -> [ParsedTrack] {
        // Group by track name if available, otherwise by format
        var trackGroups: [String: [DPDevice]] = [:]

        for device in devices {
            let trackKey = device.trackName ?? {
                switch device.format {
                case .AU: return "Audio Units"
                case .VST: return "VST Plugins"
                case .VST3: return "VST3 Plugins"
                default: return "Plugins"
                }
            }()

            if trackGroups[trackKey] == nil {
                trackGroups[trackKey] = []
            }
            trackGroups[trackKey]?.append(device)
        }

        // Convert to ParsedTrack array
        var tracks: [ParsedTrack] = []
        let sortedKeys = trackGroups.keys.sorted()

        for (trackIndex, trackName) in sortedKeys.enumerated() {
            guard let devices = trackGroups[trackName] else { continue }

            let plugins = devices.enumerated().map { (deviceIndex, device) -> ParsedPlugin in
                ParsedPlugin(
                    name: device.name, publisher: device.publisher, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: device.format
                )
            }

            tracks.append(ParsedTrack(
                name: trackName, index: trackIndex, plugins: plugins
            ))
        }

        return tracks
    }

    // MARK: - Metadata Extraction

    private static func extractTempo(from strings: [String]) -> Double? {
        for string in strings {
            // Look for tempo patterns
            if string.lowercased().contains("tempo") || string.lowercased().contains("bpm") {
                // Try to find a number nearby
                if let tempo = Double(string.filter { $0.isNumber || $0 == "." }) {
                    if tempo >= 20 && tempo <= 999 {
                        return tempo
                    }
                }
            }

            // Look for numeric patterns that might be tempo
            if string.count < 10 {  // Short strings might be tempo values
                if let value = Double(string), value >= 40 && value <= 300 {
                    // Likely a tempo value
                    return value
                }
            }
        }
        return nil
    }

    private static func extractSampleRate(from strings: [String]) -> Int? {
        let commonRates = [44100, 48000, 88200, 96000, 192000]

        for string in strings {
            if string.lowercased().contains("sample") || string.lowercased().contains("rate") {
                for rate in commonRates {
                    if string.contains(String(rate)) {
                        return rate
                    }
                }
            }

            // Direct match
            for rate in commonRates {
                if string == String(rate) {
                    return rate
                }
            }
        }

        return nil
    }

    private static func extractVersion(from strings: [String]) -> String? {
        for string in strings {
            // Look for Digital Performer version
            if string.contains("Digital Performer") {
                // Try to extract version number
                let pattern = #"(\d+(?:\.\d+)?)"#
                if let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) {
                    if let range = Range(match.range, in: string) {
                        return "Digital Performer \(string[range])"
                    }
                }
            }

            // Look for version patterns like "DP11" or "DP 11"
            if string.hasPrefix("DP") && string.count < 6 {
                return "Digital Performer \(string.replacingOccurrences(of: "DP", with: "").trimmingCharacters(in: .whitespaces))"
            }
        }
        return nil
    }

    // MARK: - Helper Methods

    private static func isManufacturerName(_ string: String) -> Bool {
        // Skip file paths and URLs
        if string.contains("/") || string.contains(".vst") || string.contains(".component") || string.contains(".au") {
            return false
        }

        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Celemony", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Apple", "MOTU", "Vienna", "Spitfire", "EastWest"
        ]

        return knownManufacturers.contains { string.contains($0) }
    }

    /// Extract manufacturer name from any string (including file paths)
    private static func extractManufacturerFromString(_ string: String) -> String? {
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Celemony", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Apple", "MOTU", "Vienna", "Spitfire", "EastWest"
        ]

        // Find which manufacturer is contained in this string
        for manufacturer in knownManufacturers {
            if string.contains(manufacturer) {
                return manufacturer
            }
        }

        return nil
    }

    private static func extractManufacturerFromName(_ pluginName: String) -> String {
        // First try to extract from the plugin name itself
        if let manufacturer = extractManufacturerFromString(pluginName) {
            return manufacturer
        }

        // Try to extract manufacturer from plugin name
        let components = pluginName.components(separatedBy: " ")
        if let first = components.first, first.count > 2 {
            // Check if first word matches known manufacturer
            if let manufacturer = extractManufacturerFromString(first) {
                return manufacturer
            }
        }

        return "Unknown"
    }
}