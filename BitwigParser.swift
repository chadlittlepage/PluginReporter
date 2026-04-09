//
//  BitwigParser.swift
//  Plugin Reporter
//
//  Parser for Bitwig Studio project files (.bwproject)
//  Uses string extraction from binary format
//

import Foundation

/// Parser for Bitwig Studio project files (String extraction method)
class BitwigParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .bitwig
    static let supportedExtensions: [String] = ["bwproject"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read binary file
        let data = try Data(contentsOf: url)

        // Extract strings from binary
        let strings = extractStrings(from: data)

        // Parse devices and plugins
        let devices = parseDevices(from: strings)

        // Validate we found something
        guard !devices.isEmpty else {
            throw ParserError.invalidProjectData("No devices found in Bitwig project")
        }

        // Extract track names
        let trackNames = extractTrackNames(from: strings)

        // Try to associate devices with tracks
        let tracks = associateDevicesWithTracks(devices: devices, trackNames: trackNames, strings: strings)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .bitwig,
            tracks: tracks,
            tempo: nil,
            sampleRate: nil,
            version: extractVersion(from: strings),
            key: nil
        )
    }

    // MARK: - String Extraction

    private static func extractStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var currentString = Data()
        let minLength = 4 // Minimum string length to consider

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

        // Don't forget last string
        if currentString.count >= minLength {
            if let string = String(data: currentString, encoding: .utf8) {
                strings.append(string)
            }
        }

        return strings
    }

    // MARK: - Device Parsing

    private struct BitwigDevice {
        let name: String
        let publisher: String
        let format: PluginFormat
        let isThirdParty: Bool
        let preset: String
    }

    private static func parseDevices(from strings: [String]) -> [BitwigDevice] {
        var devices: [BitwigDevice] = []
        var seenDevices: Set<String> = []

        for string in strings {
            // Skip preset files - they contain plugin UUIDs, not plugin names
            if string.contains(".vstpreset") || string.contains(".aupreset") {
                continue
            }

            // VST3 plugins
            if string.contains(".vst3") {
                if let device = parseVST3(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // AU plugins
            else if string.contains(".component") {
                if let device = parseAU(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST2 plugins
            else if string.contains(".vst") && !string.contains(".vst3") {
                if let device = parseVST2(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // CLAP plugins
            else if string.contains(".clap") {
                if let device = parseCLAP(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // Bitwig native devices
            else if string.hasSuffix(".bwdevice") {
                if let device = parseBitwigDevice(string, allStrings: strings) {
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

    private static func parseVST3(_ string: String, allStrings: [String]) -> BitwigDevice? {
        // Extract plugin name from path like "/Library/Audio/Plug-Ins/VST3/FabFilter Pro-MB.vst3"
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".vst3", with: "")

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else if let idx = allStrings.firstIndex(of: string) {
            // FALLBACK: Look at surrounding strings for manufacturer info
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract manufacturer from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(for: string, from: allStrings)

        return BitwigDevice(
            name: pluginName,
            publisher: manufacturer,
            format: .VST3,
            isThirdParty: true,
            preset: preset
        )
    }

    private static func parseAU(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".component", with: "")

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else if let idx = allStrings.firstIndex(of: string) {
            // FALLBACK: Look at surrounding strings for manufacturer info
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract manufacturer from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(for: string, from: allStrings)

        return BitwigDevice(
            name: pluginName,
            publisher: manufacturer,
            format: .AU,
            isThirdParty: true,
            preset: preset
        )
    }

    private static func parseVST2(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".vst", with: "")

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else if let idx = allStrings.firstIndex(of: string) {
            // FALLBACK: Look at surrounding strings for manufacturer info
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract manufacturer from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(for: string, from: allStrings)

        return BitwigDevice(
            name: pluginName,
            publisher: manufacturer,
            format: .VST,
            isThirdParty: true,
            preset: preset
        )
    }

    private static func parseCLAP(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".clap", with: "")

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else if let idx = allStrings.firstIndex(of: string) {
            // FALLBACK: Look at surrounding strings for manufacturer info
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract manufacturer from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(for: string, from: allStrings)

        return BitwigDevice(
            name: pluginName,
            publisher: manufacturer,
            format: .CLAP,
            isThirdParty: true,
            preset: preset
        )
    }

    private static func parseBitwigDevice(_ string: String, allStrings: [String]) -> BitwigDevice? {
        // Extract device name from "Polysynth.bwdevice" or path
        let deviceFileName: String
        if string.contains("/") {
            guard let fileName = string.components(separatedBy: "/").last else { return nil }
            deviceFileName = fileName
        } else {
            deviceFileName = string
        }

        let deviceName = deviceFileName.replacingOccurrences(of: ".bwdevice", with: "")

        // Extract preset name
        let preset = extractPresetName(for: string, from: allStrings)

        return BitwigDevice(
            name: deviceName,
            publisher: "Bitwig",
            format: .VST3, // Bitwig devices are treated as VST3 for consistency
            isThirdParty: false,
            preset: preset
        )
    }

    // MARK: - Helper Methods

    private static func isManufacturerName(_ string: String) -> Bool {
        // Skip file paths and URLs
        if string.contains("/") || string.contains(".vst") || string.contains(".component") || string.contains(".au") {
            return false
        }

        // Common manufacturer names
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope",
            "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla",
            "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL",
            "Sonnox", "Celemony", "Steinberg", "UJAM", "Output"
        ]

        return knownManufacturers.contains(where: { string.contains($0) })
    }

    /// Extract manufacturer name from any string (including file paths)
    private static func extractManufacturerFromString(_ string: String) -> String? {
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope",
            "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla",
            "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL",
            "Sonnox", "Celemony", "Steinberg", "UJAM", "Output"
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
        // e.g., "FabFilter Pro-Q 3" -> "FabFilter"
        let components = pluginName.components(separatedBy: " ")
        if let first = components.first, first.count > 2 {
            if let manufacturer = extractManufacturerFromString(first) {
                return manufacturer
            }
            return first
        }

        return "Unknown"
    }

    /// Extract preset name from surrounding strings near a plugin
    /// - Parameters:
    ///   - pluginString: The plugin path string
    ///   - allStrings: All extracted strings from the project
    /// - Returns: Preset name if found, empty string otherwise
    private static func extractPresetName(for pluginString: String, from allStrings: [String]) -> String {
        guard let idx = allStrings.firstIndex(of: pluginString) else { return "" }

        // Look for preset names in surrounding strings (within 5 positions after the plugin path)
        let searchRange = idx+1..<min(allStrings.count, idx + 6)

        for nearbyString in allStrings[searchRange] {
            // Skip file paths, system strings, and constants
            if nearbyString.contains("/") || nearbyString.contains(".") ||
               nearbyString.count < 3 || nearbyString.count > 50 {
                continue
            }

            // Skip all-caps strings (likely constants)
            if nearbyString.uppercased() == nearbyString && nearbyString.count > 4 {
                continue
            }

            // Skip common Bitwig system strings
            let skipStrings = ["MODULATORS", "AMOUNT", "ATTACK", "RELEASE", "DECAY",
                              "SUSTAIN", "FREQUENCY", "RESONANCE", "VOLUME", "PAN",
                              "ENABLED", "CHAIN", "DEVICE", "PLUGIN", "PRESET"]
            if skipStrings.contains(nearbyString.uppercased()) {
                continue
            }

            // Valid preset name: starts with capital or number, contains valid characters
            if let first = nearbyString.first, first.isUppercase || first.isNumber {
                return nearbyString
            }
        }

        return ""
    }

    private static func extractVersion(from strings: [String]) -> String? {
        // Look for Bitwig version info
        for (index, string) in strings.enumerated() {
            if string == "application_version_name" && index + 1 < strings.count {
                return strings[index + 1]
            }
        }
        return nil
    }

    /// Extract track names from Bitwig project strings
    private static func extractTrackNames(from strings: [String]) -> [String] {
        var trackNames: [String] = []
        var seenTracks = Set<String>()

        // Patterns that indicate track names in Bitwig projects
        let skipPatterns = [
            "/", ".", "Library", "Audio/", "Plug-Ins", "VST", "component",
            "Core Audio", "samples/", "BtWg", "MODULATORS", "AMOUNT", "ATTACK",
            "BANDS", "BRIGHTNESS", "BUILDUP", "All Device", "All Multisample",
            "All Music", "All Preset", "All Sample", "Any Creator", "Any Device",
            "Any File", "Any Tags", "Bitwig Studio", "com.bitwig"
        ]

        for (index, string) in strings.enumerated() {
            // Must be reasonable length
            guard string.count >= 4 && string.count <= 40 else { continue }

            // Must start with a capital letter or number
            guard let first = string.first, first.isUppercase || first.isNumber else { continue }

            // Skip strings matching skip patterns
            if skipPatterns.contains(where: { string.contains($0) }) {
                continue
            }

            // Skip if all caps (likely a constant or enum)
            if string.uppercased() == string && string.count > 4 {
                continue
            }

            // Look for track-like strings near plugin names
            // Track names often appear 0-5 positions before plugin paths
            if index + 5 < strings.count {
                let nextFew = strings[index+1...index+5]
                let hasPlugin = nextFew.contains(where: { $0.contains(".vst") || $0.contains(".component") || $0.contains(".clap") || $0.contains(".bwdevice") })

                if hasPlugin && !seenTracks.contains(string) {
                    trackNames.append(string)
                    seenTracks.insert(string)
                }
            }
        }

        // If we didn't find any track names, return a generic one
        if trackNames.isEmpty {
            return ["Bitwig Project"]
        }

        return trackNames
    }

    /// Associate devices with their tracks
    private static func associateDevicesWithTracks(devices: [BitwigDevice], trackNames: [String], strings: [String]) -> [ParsedTrack] {
        // Build a map of device names to track names
        var deviceToTrack: [String: String] = [:]

        // For each device, find the nearest track name that appears before it
        for device in devices {
            // Find the device's plugin path in strings
            let deviceSearchTerms = [
                "\(device.name).vst3",
                "\(device.name).vst",
                "\(device.name).component",
                "\(device.name).clap",
                "\(device.name).bwdevice"
            ]

            for (index, string) in strings.enumerated() {
                if deviceSearchTerms.contains(where: { string.contains($0) }) {
                    // Look backwards for a track name (within 20 positions)
                    let searchStart = max(0, index - 20)
                    for backIndex in stride(from: index - 1, through: searchStart, by: -1) {
                        if trackNames.contains(strings[backIndex]) {
                            deviceToTrack[device.name] = strings[backIndex]
                            break
                        }
                    }
                    break
                }
            }
        }

        // Group devices by track
        var trackPluginsMap: [String: [BitwigDevice]] = [:]
        for device in devices {
            let trackName = deviceToTrack[device.name] ?? trackNames.first ?? "Bitwig Project"
            trackPluginsMap[trackName, default: []].append(device)
        }

        // Create ParsedTrack objects
        var tracks: [ParsedTrack] = []
        for (trackIndex, trackName) in trackNames.enumerated() {
            guard let devices = trackPluginsMap[trackName] else { continue }

            let plugins = devices.enumerated().map { (deviceIndex, device) -> ParsedPlugin in
                ParsedPlugin(
                    name: device.name,
                    publisher: device.publisher,
                    trackName: trackName,
                    trackIndex: trackIndex,
                    deviceIndex: deviceIndex,
                    format: device.format,
                    preset: device.preset
                )
            }

            if !plugins.isEmpty {
                tracks.append(ParsedTrack(
                    name: trackName,
                    index: trackIndex,
                    plugins: plugins
                ))
            }
        }

        // If no tracks were created, fall back to a single generic track
        if tracks.isEmpty {
            let plugins = devices.enumerated().map { (index, device) -> ParsedPlugin in
                ParsedPlugin(
                    name: device.name,
                    publisher: device.publisher,
                    trackName: "Bitwig Project",
                    trackIndex: 0,
                    deviceIndex: index,
                    format: device.format,
                    preset: device.preset
                )
            }

            tracks.append(ParsedTrack(
                name: "Bitwig Project",
                index: 0,
                plugins: plugins
            ))
        }

        return tracks
    }
}
