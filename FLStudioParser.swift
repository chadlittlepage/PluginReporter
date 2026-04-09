//
//  FLStudioParser.swift
//  Plugin Reporter
//
//  Parser for FL Studio project files (.flp)
//  FL Studio uses a complex proprietary binary format
//  This parser uses string extraction and pattern matching
//

import Foundation

/// Parser for FL Studio project files
class FLStudioParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .flStudio
    static let supportedExtensions: [String] = ["flp"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the binary file
        let data = try Data(contentsOf: url)

        // Validate FL Studio file signature
        guard isFLPFile(data) else {
            throw ParserError.invalidProjectData("Not a valid FL Studio project file")
        }

        // Extract readable strings from binary
        let strings = extractStrings(from: data)

        // Parse plugins from strings
        let devices = parseDevices(from: strings, data: data)

        guard !devices.isEmpty else {
            throw ParserError.invalidProjectData("No plugins found in FL Studio project")
        }

        // Extract metadata
        let tempo = extractTempo(from: strings)
        let version = extractVersion(from: strings)

        // Group devices into channels/tracks
        let tracks = groupDevicesIntoTracks(devices)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: .flStudio, tracks: tracks, tempo: tempo, sampleRate: 44100, version: version, key: nil
        )
    }

    // MARK: - File Validation

    private static func isFLPFile(_ data: Data) -> Bool {
        // FL Studio files start with specific header bytes
        // Common signature: "FLhd" or "FLdt"
        guard data.count >= 4 else { return false }

        let header = data.prefix(4)
        let headerString = String(data: header, encoding: .ascii) ?? ""

        return headerString.hasPrefix("FLh") || headerString.hasPrefix("FLd")
    }

    // MARK: - String Extraction

    private static func extractStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var currentString = Data()
        let minLength = 3

        // Extract ASCII and UTF-8 strings
        for byte in data {
            // Printable ASCII characters
            if byte >= 0x20 && byte <= 0x7E {
                currentString.append(byte)
            } else if byte == 0x00 {
                // Null terminator - end of string
                if currentString.count >= minLength {
                    if let string = String(data: currentString, encoding: .utf8) {
                        strings.append(string)
                    }
                }
                currentString = Data()
            } else {
                // Non-printable - might be end of string
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

    private struct FLDevice {
        let name: String
        let publisher: String
        let format: PluginFormat
        let channelName: String?
        let preset: String
    }

    private static func parseDevices(from strings: [String], data: Data) -> [FLDevice] {
        var devices: [FLDevice] = []
        var seenDevices: Set<String> = []

        for (index, string) in strings.enumerated() {
            // VST3 plugins
            if string.hasSuffix(".vst3") || string.contains("VST3") {
                if let device = parseVST3Device(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST plugins
            else if (string.hasSuffix(".dll") || string.hasSuffix(".vst")) && !string.contains(".vst3") {
                if let device = parseVSTDevice(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // AU plugins (macOS FL Studio 20+)
            else if string.hasSuffix(".component") || string.contains("AudioUnit") {
                if let device = parseAUDevice(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // FL Studio native plugins
            else if isFLNativePlugin(string) {
                if let device = parseFLNativePlugin(string, context: strings, index: index) {
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

    private static func parseVST3Device(_ string: String, context: [String], index: Int) -> FLDevice? {
        var pluginName = string
        if string.contains("/") || string.contains("\\") {
            let components = string.components(separatedBy: CharacterSet(charactersIn: "/\\"))
            pluginName = components.last ?? string
        }
        pluginName = pluginName
            .replacingOccurrences(of: ".vst3", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        var channelName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Search nearby strings for manufacturer and channel info
            let searchRange = max(0, index - 20)..<min(context.count, index + 20)
            for nearbyString in context[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if manufacturer == "Unknown", let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                }
            }
        }

        // Look for channel names
        let searchRange = max(0, index - 20)..<min(context.count, index + 20)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Channel ") || nearbyString.contains("channel:") {
                channelName = nearbyString
                break
            }
        }

        // Final fallback: Extract from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(from: context, near: index)

        return FLDevice(
            name: pluginName, publisher: manufacturer, format: .VST3, channelName: channelName, preset: preset
        )
    }

    private static func parseVSTDevice(_ string: String, context: [String], index: Int) -> FLDevice? {
        var pluginName = string
        if string.contains("/") || string.contains("\\") {
            let components = string.components(separatedBy: CharacterSet(charactersIn: "/\\"))
            pluginName = components.last ?? string
        }
        pluginName = pluginName
            .replacingOccurrences(of: ".dll", with: "")
            .replacingOccurrences(of: ".vst", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        var channelName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Search nearby strings for manufacturer
            let searchRange = max(0, index - 20)..<min(context.count, index + 20)
            for nearbyString in context[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if manufacturer == "Unknown", let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                }
            }
        }

        // Look for channel names
        let searchRange = max(0, index - 20)..<min(context.count, index + 20)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Channel ") || nearbyString.contains("channel:") {
                channelName = nearbyString
                break
            }
        }

        // Final fallback: Extract from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(from: context, near: index)

        return FLDevice(
            name: pluginName, publisher: manufacturer, format: .VST, channelName: channelName, preset: preset
        )
    }

    private static func parseAUDevice(_ string: String, context: [String], index: Int) -> FLDevice? {
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
        var channelName: String?

        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Search nearby strings for manufacturer
            let searchRange = max(0, index - 20)..<min(context.count, index + 20)
            for nearbyString in context[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if manufacturer == "Unknown", let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                }
            }
        }

        // Look for channel names
        let searchRange = max(0, index - 20)..<min(context.count, index + 20)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Channel ") {
                channelName = nearbyString
                break
            }
        }

        // Final fallback: Extract from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        // Extract preset name
        let preset = extractPresetName(from: context, near: index)

        return FLDevice(
            name: pluginName, publisher: manufacturer, format: .AU, channelName: channelName, preset: preset
        )
    }

    private static func parseFLNativePlugin(_ string: String, context: [String], index: Int) -> FLDevice? {
        var channelName: String?

        let searchRange = max(0, index - 10)..<min(context.count, index + 10)
        for nearbyString in context[searchRange] {
            if nearbyString.hasPrefix("Channel ") {
                channelName = nearbyString
            }
        }

        // Extract preset name
        let preset = extractPresetName(from: context, near: index)

        return FLDevice(
            name: string, publisher: "Image-Line", format: .VST3, channelName: channelName, preset: preset
        )
    }

    // MARK: - FL Studio Native Plugins

    private static func isFLNativePlugin(_ string: String) -> Bool {
        let flPlugins = [
            // Synths
            "3xOsc", "BooBass", "FL Keys", "FPC", "Harmless", "Harmor", "FLEX", "Sytrus", "Sawer", "Toxic Biohazard", "Morphine", "Sakura", "Drumaxx", "Poizone", "Transistor Bass", "DirectWave", "Slicex", "FPC", "Fruity Reverb", "Fruity Delay", "Fruity Chorus", "Fruity Flanger", "Fruity Phaser", "Fruity Filter", "Fruity Parametric EQ", "Fruity Limiter", "Fruity Compressor", "Fruity Multiband Compressor", "Fruity Reeverb 2", "Fruity Delay Bank", "Fruity Vocoder", "Gross Beat", "Vocodex", "NewTone", "Pitcher", "Fruity Balance", "Fruity Stereo Shaper", "Fruity Send", "Fruity Mute", "Fruity Notebook", "Fruity Formula Controller"
        ]

        return flPlugins.contains { string.contains($0) }
    }

    // MARK: - Track Grouping

    private static func groupDevicesIntoTracks(_ devices: [FLDevice]) -> [ParsedTrack] {
        // Group by channel name if available, otherwise by format
        var trackGroups: [String: [FLDevice]] = [:]

        for device in devices {
            let trackKey = device.channelName ?? {
                switch device.format {
                case .VST: return "VST Plugins"
                case .VST3: return "VST3 Plugins"
                case .AU: return "Audio Units"
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
                    name: device.name, publisher: device.publisher, trackName: trackName, trackIndex: trackIndex, deviceIndex: deviceIndex, format: device.format, preset: device.preset
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
            // FL Studio might store tempo as "140 BPM" or just "140"
            if string.lowercased().contains("bpm") {
                let numbers = string.filter { $0.isNumber || $0 == "." }
                if let tempo = Double(numbers), tempo >= 20 && tempo <= 999 {
                    return tempo
                }
            }

            // Look for numeric values in reasonable tempo range
            if string.count < 6, let value = Double(string) {
                if value >= 60 && value <= 200 {
                    // Likely a tempo value
                    return value
                }
            }
        }
        return nil
    }

    private static func extractVersion(from strings: [String]) -> String? {
        for string in strings {
            // FL Studio version patterns
            if string.contains("FL Studio") && string.contains(".") {
                return string
            }

            // Look for version numbers like "20.9" or "21.0"
            if string.hasPrefix("FL ") || string.contains("Studio") {
                let pattern = #"(\d+\.\d+(?:\.\d+)?)"#
                if let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) {
                    if let range = Range(match.range, in: string) {
                        return "FL Studio \(string[range])"
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Helper Methods

    /// Extract preset name from nearby strings
    /// - Parameters:
    ///   - context: All extracted strings
    ///   - index: Current index
    /// - Returns: Preset name if found, empty string otherwise
    private static func extractPresetName(from context: [String], near index: Int) -> String {
        // FL Studio often stores preset names near plugin references
        // Search within 10 positions before and after
        let searchRange = max(0, index - 10)..<min(context.count, index + 10)

        for nearbyString in context[searchRange] {
            // Skip system strings, file paths, and short strings
            if nearbyString.contains("/") || nearbyString.contains("\\") ||
               nearbyString.contains(".vst") || nearbyString.contains(".dll") ||
               nearbyString.count < 3 || nearbyString.count > 60 {
                continue
            }

            // Skip all-caps strings (likely constants)
            if nearbyString.uppercased() == nearbyString && nearbyString.count > 4 {
                continue
            }

            // Skip common FL Studio system strings
            let skipStrings = ["Channel", "Mixer", "Pattern", "Automation", "Playlist", "VST", "VST3", "Plugin", "Effect", "Instrument"]
            if skipStrings.contains(where: { nearbyString.contains($0) }) {
                continue
            }

            // Valid preset name: starts with capital or number, reasonable length
            if let first = nearbyString.first, first.isUppercase || first.isNumber {
                // Additional filter: preset names often contain spaces or underscores
                if nearbyString.contains(" ") || nearbyString.contains("_") || nearbyString.count >= 5 {
                    return nearbyString
                }
            }
        }

        return ""
    }

    private static func isManufacturerName(_ string: String) -> Bool {
        // Skip file paths and URLs
        if string.contains("/") || string.contains(".vst") || string.contains(".component") || string.contains(".au") || string.contains(".dll") {
            return false
        }

        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Image-Line", "Cymatics", "Splice", "Arcade"
        ]

        return knownManufacturers.contains { string.contains($0) }
    }

    /// Extract manufacturer name from any string (including file paths)
    private static func extractManufacturerFromString(_ string: String) -> String? {
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Image-Line", "Cymatics", "Splice", "Arcade"
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

        let components = pluginName.components(separatedBy: " ")
        if let first = components.first, first.count > 2 {
            if let manufacturer = extractManufacturerFromString(first) {
                return manufacturer
            }
            return first
        }

        return "Unknown"
    }
}