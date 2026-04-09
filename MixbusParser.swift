//
//  MixbusParser.swift
//  Plugin Reporter
//
//  Parser for Harrison Mixbus project files (.mixbus)
//  Mixbus is based on Ardour, so it uses the same XML format
//
//  Note: Reuses ArdourParser logic since Mixbus is a fork of Ardour
//

import Foundation

/// Parser for Harrison Mixbus project files (XML-based, Ardour compatible)
class MixbusParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .mixbus
    static let supportedExtensions: [String] = ["mixbus"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        print("🎚️  Parsing Mixbus Session: \(url.lastPathComponent)")

        // Read the XML file (Mixbus uses Ardour's XML format)
        let data = try Data(contentsOf: url)

        // Parse XML using Mixbus-aware parser
        let parser = MixbusXMLParser()
        try parser.parse(data: data)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .mixbus,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
        )
    }
}

// MARK: - XML Parser (Based on Ardour)

private class MixbusXMLParser: NSObject, XMLParserDelegate {

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
    private var inPlugin = false
    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentPluginFormat: PluginFormat = .VST3

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        print("\n📊 MIXBUS PARSING COMPLETE")
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
                attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        characterBuffer = ""
        currentAttributes = attributeDict

        // Session metadata (root element)
        if elementName == "Session" {
            // Extract version
            if let versionString = attributeDict["version"] {
                version = "Mixbus (Ardour \(versionString))"
            }

            // Sample rate
            if let rateString = attributeDict["sample-rate"], let rate = Int(rateString) {
                sampleRate = rate
            }
        }

        // Tempo information
        if elementName == "Tempo" {
            if let tempoString = attributeDict["beats-per-minute"], let tempoValue = Double(tempoString) {
                if tempo == nil {
                    tempo = tempoValue
                }
            }
        }

        // Route detection (Mixbus/Ardour calls tracks "Routes")
        if elementName == "Route" || elementName == "AudioTrack" || elementName == "MidiTrack" {
            currentTrackName = attributeDict["name"] ?? "Track \(currentTrackIndex + 1)"
            currentPlugins = []
            currentDeviceIndex = 0
            print("🎵 Found track: \(currentTrackName ?? "Unnamed")")
        }

        // Plugin detection - Mixbus uses Processor elements
        if elementName == "Processor" {
            // Check if this is a plugin (not a built-in processor)
            if let type = attributeDict["type"],
               type.contains("lv2") || type.contains("vst") || type.contains("au") || type.contains("ladspa") {
                inPlugin = true
                currentPluginName = ""
                currentManufacturer = ""
                currentPluginFormat = .VST3

                // Extract plugin name
                if let name = attributeDict["name"] {
                    currentPluginName = name
                }

                // Determine format from type
                if type.contains("lv2") {
                    currentPluginFormat = .VST3  // Map LV2 to VST3
                    currentManufacturer = extractLV2Manufacturer(from: attributeDict)
                } else if type.contains("vst3") {
                    currentPluginFormat = .VST3
                } else if type.contains("vst") {
                    currentPluginFormat = .VST
                } else if type.contains("au") {
                    currentPluginFormat = .AU
                } else if type.contains("ladspa") {
                    currentPluginFormat = .VST  // Map LADSPA to VST
                }

                print("   🔌 Found plugin: \(currentPluginName)")
            }
            // Harrison Mixbus native plugins and processors
            else if let name = attributeDict["name"] {
                // Mixbus adds Harrison-branded channel strips and plugins
                let harrisonPlugins = ["harrison", "mixbus", "channel strip", "eq", "comp", "limiter", "tape sat"]

                let lowerName = name.lowercased()
                let isHarrisonPlugin = harrisonPlugins.contains { lowerName.contains($0) }

                // Skip meters and basic processors, but include Harrison effects
                if isHarrisonPlugin && !isBuiltInProcessor(name) {
                    inPlugin = true
                    currentPluginName = name
                    currentManufacturer = "Harrison"
                    currentPluginFormat = .VST3
                    print("   🔌 Found Harrison plugin: \(currentPluginName)")
                }
            }
        }

        // LV2 plugin info
        if elementName == "lv2" && inPlugin {
            if let uri = attributeDict["uri"] {
                currentManufacturer = extractManufacturerFromLV2URI(uri)
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        // End of plugin
        if elementName == "Processor" && inPlugin {
            inPlugin = false

            // Add plugin if valid
            if !currentPluginName.isEmpty && !isBuiltInProcessor(currentPluginName) {
                let plugin = ParsedPlugin(
                    name: cleanPluginName(currentPluginName),
                    publisher: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer,
                    trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)",
                    trackIndex: currentTrackIndex,
                    deviceIndex: currentDeviceIndex,
                    format: currentPluginFormat
                )
                currentPlugins.append(plugin)
                currentDeviceIndex += 1
                print("   ✅ Added plugin: \(plugin.name) by \(plugin.publisher)")
            }

            // Reset state
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginFormat = .VST3
        }

        // End of track/route
        if elementName == "Route" || elementName == "AudioTrack" || elementName == "MidiTrack" {
            // Only add track if it has plugins
            if !currentPlugins.isEmpty {
                let trackName = currentTrackName ?? "Track \(currentTrackIndex + 1)"
                let track = ParsedTrack(
                    name: trackName,
                    index: currentTrackIndex,
                    plugins: currentPlugins
                )
                tracks.append(track)
                print("🎵 Added track '\(trackName)' with \(currentPlugins.count) plugins")
            }

            currentTrackIndex += 1
            currentTrackName = nil
            currentPlugins = []
            currentDeviceIndex = 0
        }

        elementStack.removeLast()
        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    // MARK: - Helper Methods

    private func extractLV2Manufacturer(from attributes: [String: String]) -> String {
        if let type = attributes["type"], type.contains("lv2") {
            let components = type.components(separatedBy: "/")
            if components.count > 2 {
                return components[2].capitalized
            }
        }
        return "Unknown"
    }

    private func extractManufacturerFromLV2URI(_ uri: String) -> String {
        let components = uri.components(separatedBy: "/")

        // Try to find manufacturer in URI path
        if let domainIndex = components.firstIndex(where: { $0.contains(".") }) {
            if domainIndex + 1 < components.count {
                let manufacturer = components[domainIndex + 1]
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                return manufacturer.capitalized
            }
        }

        // Fallback: extract from domain
        if let domain = components.first(where: { $0.contains(".") }) {
            let parts = domain.components(separatedBy: ".")
            if parts.count >= 2 {
                return parts[parts.count - 2].capitalized
            }
        }

        return "Unknown"
    }

    private func isBuiltInProcessor(_ name: String) -> Bool {
        let builtInProcessors = [
            "meter",
            "main outs",
            "fader",
            "amp",
            "trim",
            "polarity",
            "phase",
            "gain",
            "monitor"
        ]

        return builtInProcessors.contains { name.lowercased().contains($0.lowercased()) }
    }

    private func cleanPluginName(_ name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: " (mono)", with: "")
            .replacingOccurrences(of: " (stereo)", with: "")
            .replacingOccurrences(of: " VST", with: "")
            .replacingOccurrences(of: " VST3", with: "")
            .replacingOccurrences(of: " AU", with: "")
            .replacingOccurrences(of: " LV2", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove version numbers
        if let match = cleaned.range(of: #"\s+v?\d+(\.\d+)*$"#, options: .regularExpression) {
            cleaned.removeSubrange(match)
        }

        return cleaned
    }
}
