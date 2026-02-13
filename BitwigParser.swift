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

        // Create tracks from devices
        // Note: Bitwig binary format doesn't easily reveal track structure,
        // so we create a single "All Devices" track
        let plugins = devices.enumerated().map { (index, device) -> ParsedPlugin in
            ParsedPlugin(
                name: device.name,
                manufacturer: device.manufacturer,
                trackName: "Bitwig Project",
                trackIndex: 0,
                deviceIndex: index,
                format: device.format
            )
        }

        let track = ParsedTrack(
            name: "Bitwig Project",
            index: 0,
            plugins: plugins
        )

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .bitwig,
            tracks: [track],
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
        let manufacturer: String
        let format: PluginFormat
        let isThirdParty: Bool
    }

    private static func parseDevices(from strings: [String]) -> [BitwigDevice] {
        var devices: [BitwigDevice] = []
        var seenDevices: Set<String> = []

        for string in strings {
            // VST3 plugins
            if string.contains(".vst3") {
                if let device = parseVST3(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.manufacturer)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // AU plugins
            else if string.contains(".component") {
                if let device = parseAU(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.manufacturer)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // VST2 plugins
            else if string.contains(".vst") && !string.contains(".vst3") {
                if let device = parseVST2(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.manufacturer)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // CLAP plugins
            else if string.contains(".clap") {
                if let device = parseCLAP(string, allStrings: strings) {
                    let key = "\(device.name)_\(device.manufacturer)"
                    if !seenDevices.contains(key) {
                        devices.append(device)
                        seenDevices.insert(key)
                    }
                }
            }
            // Bitwig native devices
            else if string.hasSuffix(".bwdevice") {
                if let device = parseBitwigDevice(string) {
                    let key = "\(device.name)_\(device.manufacturer)"
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

        // Try to find manufacturer in nearby strings
        var manufacturer = "Unknown"
        if let idx = allStrings.firstIndex(of: string) {
            // Look at surrounding strings for manufacturer info
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                if isManufacturerName(nearbyString) {
                    manufacturer = nearbyString
                    break
                }
            }
        }

        // Extract manufacturer from plugin name if possible
        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return BitwigDevice(
            name: pluginName,
            manufacturer: manufacturer,
            format: .VST3,
            isThirdParty: true
        )
    }

    private static func parseAU(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".component", with: "")

        var manufacturer = "Unknown"
        if let idx = allStrings.firstIndex(of: string) {
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                if isManufacturerName(nearbyString) {
                    manufacturer = nearbyString
                    break
                }
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return BitwigDevice(
            name: pluginName,
            manufacturer: manufacturer,
            format: .AU,
            isThirdParty: true
        )
    }

    private static func parseVST2(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".vst", with: "")

        var manufacturer = "Unknown"
        if let idx = allStrings.firstIndex(of: string) {
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                if isManufacturerName(nearbyString) {
                    manufacturer = nearbyString
                    break
                }
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return BitwigDevice(
            name: pluginName,
            manufacturer: manufacturer,
            format: .VST,
            isThirdParty: true
        )
    }

    private static func parseCLAP(_ string: String, allStrings: [String]) -> BitwigDevice? {
        guard let pluginFileName = string.components(separatedBy: "/").last else { return nil }

        let pluginName = pluginFileName.replacingOccurrences(of: ".clap", with: "")

        var manufacturer = "Unknown"
        if let idx = allStrings.firstIndex(of: string) {
            let searchRange = max(0, idx - 10)..<min(allStrings.count, idx + 10)
            for nearbyString in allStrings[searchRange] {
                if isManufacturerName(nearbyString) {
                    manufacturer = nearbyString
                    break
                }
            }
        }

        if manufacturer == "Unknown" {
            manufacturer = extractManufacturerFromName(pluginName)
        }

        return BitwigDevice(
            name: pluginName,
            manufacturer: manufacturer,
            format: .CLAP,
            isThirdParty: true
        )
    }

    private static func parseBitwigDevice(_ string: String) -> BitwigDevice? {
        // Extract device name from "Polysynth.bwdevice" or path
        let deviceFileName: String
        if string.contains("/") {
            guard let fileName = string.components(separatedBy: "/").last else { return nil }
            deviceFileName = fileName
        } else {
            deviceFileName = string
        }

        let deviceName = deviceFileName.replacingOccurrences(of: ".bwdevice", with: "")

        return BitwigDevice(
            name: deviceName,
            manufacturer: "Bitwig",
            format: .VST3, // Bitwig devices are treated as VST3 for consistency
            isThirdParty: false
        )
    }

    // MARK: - Helper Methods

    private static func isManufacturerName(_ string: String) -> Bool {
        // Common manufacturer names
        let knownManufacturers = [
            "FabFilter", "Waves", "Native Instruments", "Arturia", "iZotope",
            "Soundtoys", "Plugin Alliance", "UAD", "Slate Digital", "Valhalla",
            "Xfer", "Dada Life", "Softube", "Eventide", "Lexicon", "SSL",
            "Sonnox", "Celemony", "Steinberg", "UJAM", "Output"
        ]

        return knownManufacturers.contains(where: { string.contains($0) })
    }

    private static func extractManufacturerFromName(_ pluginName: String) -> String {
        // Try to extract manufacturer from plugin name
        // e.g., "FabFilter Pro-Q 3" -> "FabFilter"
        let components = pluginName.components(separatedBy: " ")
        if let first = components.first, first.count > 2 {
            return first
        }

        return "Unknown"
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
}
