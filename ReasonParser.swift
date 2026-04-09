//
//  ReasonParser.swift
//  Plugin Reporter
//
//  Parser for Reason Studios project files (.reason, .rns)
//  Reason files are compressed XML/binary hybrid format
//

import Foundation
import Compression

/// Parser for Reason Studios project files
class ReasonParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .reason
    static let supportedExtensions: [String] = ["reason", "rns"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the file data
        let data = try Data(contentsOf: url)

        // Reason files are typically gzip compressed XML or binary
        // Try to extract readable strings first (works for both formats)
        let strings = extractStrings(from: data)

        // Parse devices and plugins from strings
        let devices = parseDevices(from: strings)

        guard !devices.isEmpty else {
            throw ParserError.invalidProjectData("No devices found in Reason project")
        }

        // Extract metadata
        let tempo = extractTempo(from: strings)
        let sampleRate = extractSampleRate(from: strings)
        let version = extractVersion(from: strings)

        // Group devices into tracks
        let tracks = groupDevicesIntoTracks(devices)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: .reason, tracks: tracks, tempo: tempo, sampleRate: sampleRate, version: version, key: nil
        )
    }

    // MARK: - String Extraction

    private static func extractStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var currentString = Data()
        let minLength = 4

        // Extract ASCII strings from binary data
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

    private struct ReasonDevice {
        let name: String
        let publisher: String
        let type: DeviceType
        let format: PluginFormat

        enum DeviceType {
            case nativeRack      // Reason's built-in rack devices
            case vst2            // VST2 plugins
            case vst3            // VST3 plugins
            case rackExtension   // Reason Rack Extensions (.re)
        }
    }

    private static func parseDevices(from strings: [String]) -> [ReasonDevice] {
        var devices: [ReasonDevice] = []
        var seenDevices: Set<String> = []

        for (index, string) in strings.enumerated() {
            // VST3 plugins
            if string.hasSuffix(".vst3") || string.contains("vst3") {
                if let device = parseVST3Device(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST2 plugins
            else if string.hasSuffix(".vst") && !string.contains(".vst3") {
                if let device = parseVST2Device(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // Rack Extensions (.re)
            else if string.contains(".re") || string.contains("RackExtension") {
                if let device = parseRackExtension(string, context: strings, index: index) {
                    let key = "\(device.name)_\(device.publisher)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // Reason native devices (common device names)
            else if isReasonNativeDevice(string) {
                if let device = parseReasonNativeDevice(string) {
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

    private static func parseVST3Device(_ string: String, context: [String], index: Int) -> ReasonDevice? {
        // Extract plugin name from path
        var pluginName = string
        if string.contains("/") {
            pluginName = string.components(separatedBy: "/").last ?? string
        }
        pluginName = pluginName.replacingOccurrences(of: ".vst3", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Look for manufacturer in nearby strings
            let searchRange = max(0, index - 10)..<min(context.count, index + 10)
            for nearbyString in context[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return ReasonDevice(
            name: pluginName, publisher: manufacturer, type: .vst3, format: .VST3
        )
    }

    private static func parseVST2Device(_ string: String, context: [String], index: Int) -> ReasonDevice? {
        var pluginName = string
        if string.contains("/") {
            pluginName = string.components(separatedBy: "/").last ?? string
        }
        pluginName = pluginName.replacingOccurrences(of: ".vst", with: "")
            .trimmingCharacters(in: .whitespaces)

        // FIRST: Try to extract manufacturer from the plugin path itself
        var manufacturer = "Unknown"
        if let extractedFromPath = extractManufacturerFromString(string) {
            manufacturer = extractedFromPath
        } else {
            // FALLBACK: Look for manufacturer in nearby strings
            let searchRange = max(0, index - 10)..<min(context.count, index + 10)
            for nearbyString in context[searchRange] {
                // Extract manufacturer name from string (works for paths too)
                if let extractedManufacturer = extractManufacturerFromString(nearbyString) {
                    manufacturer = extractedManufacturer
                    break
                }
            }
        }

        // Final fallback: Extract from plugin name
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return ReasonDevice(
            name: pluginName, publisher: manufacturer, type: .vst2, format: .VST
        )
    }

    private static func parseRackExtension(_ string: String, context: [String], index: Int) -> ReasonDevice? {
        // Rack Extensions have special naming like "se.propellerheads.RV7000"
        let deviceName = string
            .replacingOccurrences(of: ".re", with: "")
            .replacingOccurrences(of: "RackExtension", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Try to extract from reverse domain notation
        if deviceName.contains(".") {
            let parts = deviceName.components(separatedBy: ".")
            if parts.count >= 3 {
                let manufacturer = parts[1].capitalized // e.g., "propellerheads"
                let name = parts[2...].joined(separator: " ") // e.g., "RV7000"
                return ReasonDevice(
                    name: name, publisher: manufacturer.isEmpty ? "Reason Studios" : manufacturer, type: .rackExtension, format: .VST3  // Treated as VST3 for compatibility
                )
            }
        }

        return ReasonDevice(
            name: deviceName, publisher: "Reason Studios", type: .rackExtension, format: .VST3
        )
    }

    private static func parseReasonNativeDevice(_ string: String) -> ReasonDevice? {
        return ReasonDevice(
            name: string, publisher: "Reason Studios", type: .nativeRack, format: .VST3  // Treated as VST3 for compatibility
        )
    }

    // MARK: - Device Recognition

    private static func isReasonNativeDevice(_ string: String) -> Bool {
        let nativeDevices = [
            // Instruments
            "Thor", "Malstrom", "Subtractor", "NN-19", "NN-XT", "Dr. Octo Rex", "Redrum", "Kong", "Grain", "Europa", "Monotone", "Klang", "RV7000", "Scream 4", "The Echo", "Alligator", "Pulveriser", "Synchronous", "Audiomatic", "Sweeper", "Polar", "MClass", "Combinator", "Line Mixer 6:2", "MClass Equalizer", "MClass Compressor", "MClass Stereo Imager", "MClass Maximizer", "DDL-1", "D-11", "ECF-42", "CF-101", "PH-90", "UN-16", "COMP-01", "PEQ-2", "BV512", "Spider CV", "Spider Audio", "Matrix Pattern Sequencer", "Algoritm", "Friktion", "Scenic", "Radical Piano"
        ]

        return nativeDevices.contains { string.contains($0) }
    }

    // MARK: - Track Grouping

    private static func groupDevicesIntoTracks(_ devices: [ReasonDevice]) -> [ParsedTrack] {
        // Reason doesn't have a clear track structure in the file format
        // We create logical groups based on device types

        var tracksByType: [String: [ReasonDevice]] = [:]

        for device in devices {
            let trackName: String
            switch device.type {
            case .nativeRack: 
                trackName = "Reason Rack"
            case .vst2: 
                trackName = "VST Plugins"
            case .vst3: 
                trackName = "VST3 Plugins"
            case .rackExtension: 
                trackName = "Rack Extensions"
            }

            if tracksByType[trackName] == nil {
                tracksByType[trackName] = []
            }
            tracksByType[trackName]?.append(device)
        }

        // Convert to ParsedTrack array
        var tracks: [ParsedTrack] = []
        let sortedKeys = tracksByType.keys.sorted()

        for (trackIndex, trackName) in sortedKeys.enumerated() {
            guard let devices = tracksByType[trackName] else { continue }

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
            // Look for tempo patterns like "Tempo", "BPM", or numeric tempo values
            if string.lowercased().contains("tempo") || string.lowercased().contains("bpm") {
                // Try to find a number in nearby strings
                if let tempo = Double(string.filter { $0.isNumber || $0 == "." }) {
                    if tempo >= 20 && tempo <= 999 {
                        return tempo
                    }
                }
            }
        }
        return nil
    }

    private static func extractSampleRate(from strings: [String]) -> Int? {
        let commonRates = [44100, 48000, 88200, 96000, 192000]

        for string in strings {
            if string.lowercased().contains("samplerate") || string.lowercased().contains("sample_rate") {
                for rate in commonRates {
                    if string.contains(String(rate)) {
                        return rate
                    }
                }
            }
        }

        return nil
    }

    private static func extractVersion(from strings: [String]) -> String? {
        for string in strings {
            // Look for version patterns like "Reason 12.5" or "Version 11.3"
            if string.lowercased().contains("reason") && string.contains(".") {
                // Extract version number
                let pattern = #"(\d+\.\d+(?:\.\d+)?)"#
                if let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) {
                    if let range = Range(match.range, in: string) {
                        return "Reason \(string[range])"
                    }
                }
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
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Celemony", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Reason Studios", "Propellerhead"
        ]

        return knownManufacturers.contains { string.contains($0) }
    }

    /// Extract manufacturer name from any string (including file paths)
    private static func extractManufacturerFromString(_ string: String) -> String? {
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope", "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla DSP", "Valhalla", "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL", "Sonnox", "Celemony", "Steinberg", "UJAM", "Output", "Serum", "u-he", "Kilohearts", "Reason Studios", "Propellerhead"
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
}