//
//  CubaseParser.swift
//  Plugin Reporter
//
//  Parser for Cubase and Nuendo project files (.cpr, .npr)
//  Both use the same XML-based format (Steinberg products)
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

        // Read the file
        let data = try Data(contentsOf: url)

        // Parse XML
        let parser = CubaseXMLParser()
        try parser.parse(data: data)

        // Determine DAW type based on extension
        let dawType: DAWType = url.pathExtension.lowercased() == "npr" ? .nuendo : .cubase

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: dawType,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
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

// MARK: - XML Parser

private class CubaseXMLParser: NSObject, XMLParserDelegate {

    var tempo: Double?
    var sampleRate: Int?
    var version: String?
    var tracks: [ParsedTrack] = []

    private var currentTrackName: String?
    private var currentTrackIndex = 0
    private var currentPlugins: [ParsedPlugin] = []
    private var currentDeviceIndex = 0

    // XML parsing state
    private var elementStack: [String] = []
    private var characterBuffer = ""
    private var currentAttributes: [String: String] = [:]

    // Plugin parsing state
    private var inPluginSlot = false
    private var inVSTPlugin = false
    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentPluginFormat: PluginFormat = .VST3

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        print("\n📊 CUBASE PARSING COMPLETE")
        print("   Total tracks: \(tracks.count)")
        print("   Total plugins: \(tracks.flatMap { $0.plugins }.count)")
        print("   Tempo: \(tempo.map { String($0) } ?? "not found")")
        print("   Sample Rate: \(sampleRate.map { String($0) } ?? "not found")")
        print("   Version: \(version ?? "not found")")
        print("---\n")
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {

        elementStack.append(elementName)
        characterBuffer = ""
        currentAttributes = attributeDict

        // Project metadata
        if elementName == "Project" {
            if let versionString = attributeDict["version"] {
                version = "Cubase \(versionString)"
            }
        }

        // Tempo detection
        if elementName == "Tempo" {
            if let value = attributeDict["value"], let tempoValue = Double(value) {
                tempo = tempoValue
            }
        }

        // Sample rate detection
        if elementName == "SampleRate" {
            if let value = attributeDict["value"], let rate = Int(value) {
                sampleRate = rate
            }
        }

        // Track detection
        if elementName == "Track" || elementName == "AudioTrack" || elementName == "MIDITrack" || elementName == "InstrumentTrack" {
            currentTrackName = attributeDict["name"] ?? "Track \(currentTrackIndex + 1)"
            currentPlugins = []
            currentDeviceIndex = 0
        }

        // Plugin/Insert detection
        if elementName == "PluginSlot" || elementName == "Insert" || elementName == "Inserts" {
            inPluginSlot = true
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginFormat = .VST3
        }

        // VST plugin detection - handle both nested and standalone
        if elementName == "VSTPlugin" || elementName == "Plugin" {
            inVSTPlugin = true
            inPluginSlot = true  // Treat VSTPlugin as being in a plugin slot

            // Extract plugin info from attributes
            if let name = attributeDict["name"] {
                currentPluginName = name
            }
            if let vendor = attributeDict["vendor"] {
                currentManufacturer = vendor
            }
            if let uid = attributeDict["uid"] {
                currentPluginName = currentPluginName.isEmpty ? uid : currentPluginName
            }

            // Determine format from attributes
            if let pluginType = attributeDict["type"] {
                currentPluginFormat = parsePluginType(pluginType)
            } else if let classID = attributeDict["classID"] {
                // VST3 plugins have a classID
                currentPluginFormat = .VST3
            }

            // If we have a name, add the plugin immediately (for simple format)
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: currentPluginName,
                    manufacturer: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer,
                    trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)",
                    trackIndex: currentTrackIndex,
                    deviceIndex: currentDeviceIndex,
                    format: currentPluginFormat
                )
                currentPlugins.append(plugin)
                currentDeviceIndex += 1
                print("   ✅ Added plugin: \(currentPluginName) by \(currentManufacturer)")

                // Reset for next plugin
                currentPluginName = ""
                currentManufacturer = ""
            }
        }

        // Plugin name in different locations
        if (elementName == "Name" || elementName == "PluginName") && (inVSTPlugin || inPluginSlot) {
            if let name = attributeDict["value"], !name.isEmpty {
                currentPluginName = name
            }
        }

        // Manufacturer/Vendor
        if (elementName == "Vendor" || elementName == "Manufacturer") && (inVSTPlugin || inPluginSlot) {
            if let vendor = attributeDict["value"], !vendor.isEmpty {
                currentManufacturer = vendor
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        // End of VST Plugin
        if elementName == "VSTPlugin" || elementName == "Plugin" {
            inVSTPlugin = false
        }

        // End of plugin slot
        if elementName == "PluginSlot" || elementName == "Insert" {
            inPluginSlot = false

            // Add plugin if we have valid data
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: currentPluginName,
                    manufacturer: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer,
                    trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)",
                    trackIndex: currentTrackIndex,
                    deviceIndex: currentDeviceIndex,
                    format: currentPluginFormat
                )
                currentPlugins.append(plugin)
                currentDeviceIndex += 1
                print("   ✅ Added plugin: \(currentPluginName) by \(currentManufacturer)")
            }

            // Reset state
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginFormat = .VST3
        }

        // End of track
        if elementName == "Track" || elementName == "AudioTrack" || elementName == "MIDITrack" || elementName == "InstrumentTrack" {
            // Always add track, even if it has no plugins
            let trackName = currentTrackName ?? "Track \(currentTrackIndex + 1)"
            let track = ParsedTrack(
                name: trackName,
                index: currentTrackIndex,
                plugins: currentPlugins
            )
            tracks.append(track)

            if currentPlugins.isEmpty {
                print("🎵 Added track '\(trackName)' (no plugins)")
            } else {
                print("🎵 Added track '\(trackName)' with \(currentPlugins.count) plugins")
            }

            currentTrackIndex += 1
            currentTrackName = nil
            currentPlugins = []
            currentDeviceIndex = 0
        }

        // Handle character data for elements
        if !characterBuffer.isEmpty {
            let trimmed = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

            if elementName == "Name" && (inVSTPlugin || inPluginSlot) && !trimmed.isEmpty {
                currentPluginName = trimmed
            }

            if elementName == "Vendor" && (inVSTPlugin || inPluginSlot) && !trimmed.isEmpty {
                currentManufacturer = trimmed
            }
        }

        elementStack.removeLast()
        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    // MARK: - Helper Methods

    private func parsePluginType(_ typeString: String) -> PluginFormat {
        let lower = typeString.lowercased()

        if lower.contains("vst3") {
            return .VST3
        } else if lower.contains("vst") {
            return .VST
        } else if lower.contains("au") || lower.contains("audiounit") {
            return .AU
        } else if lower.contains("aax") {
            return .AAX
        } else if lower.contains("clap") {
            return .CLAP
        } else {
            return .VST3  // Default for Cubase
        }
    }
}
