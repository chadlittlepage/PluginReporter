//
//  TracktionParser.swift
//  Plugin Reporter
//
//  Parser for Tracktion Waveform project files (.tracktionedit)
//  Tracktion uses a clean XML format
//

import Foundation

/// Parser for Tracktion Waveform project files
class TracktionParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .tracktion
    static let supportedExtensions: [String] = ["tracktionedit"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Read the XML file
        let data = try Data(contentsOf: url)

        // Parse XML
        let parser = TracktionXMLParser()
        try parser.parse(data: data)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .tracktion,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
        )
    }
}

// MARK: - XML Parser

private class TracktionXMLParser: NSObject, XMLParserDelegate {

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

        print("\n📊 TRACKTION PARSING COMPLETE")
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
        if elementName == "EDIT" {
            if let versionString = attributeDict["version"] {
                version = "Tracktion \(versionString)"
            }

            // Tempo
            if let tempoString = attributeDict["tempo"], let tempoValue = Double(tempoString) {
                tempo = tempoValue
            }
        }

        // Sample rate (often in PROJECTDATA or EDIT)
        if elementName == "PROJECTDATA" {
            if let rateString = attributeDict["sampleRate"], let rate = Int(rateString) {
                sampleRate = rate
            }
        }

        // Track detection
        if elementName == "TRACK" {
            currentTrackName = attributeDict["name"] ?? "Track \(currentTrackIndex + 1)"
            currentPlugins = []
            currentDeviceIndex = 0
            print("🎵 Found track: \(currentTrackName ?? "Unnamed")")
        }

        // Plugin detection - Tracktion uses various plugin element names
        if elementName == "PLUGIN" || elementName == "VST" || elementName == "VST3" ||
           elementName == "AU" || elementName == "TRACKTIONPLUGIN" {
            inPlugin = true
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginFormat = .VST3

            // Extract plugin info from attributes
            if let name = attributeDict["name"] {
                currentPluginName = name
            } else if let filename = attributeDict["filename"] {
                // Extract name from filename
                currentPluginName = extractPluginNameFromFilename(filename)
            } else if let uid = attributeDict["uid"] {
                currentPluginName = uid
            }

            // Manufacturer
            if let manufacturer = attributeDict["manufacturer"] {
                currentManufacturer = manufacturer
            }

            // Format detection
            if elementName == "VST3" || attributeDict["type"]?.contains("VST3") == true {
                currentPluginFormat = .VST3
            } else if elementName == "VST" || attributeDict["type"]?.contains("VST") == true {
                currentPluginFormat = .VST
            } else if elementName == "AU" || attributeDict["type"]?.contains("AU") == true {
                currentPluginFormat = .AU
            } else if elementName == "TRACKTIONPLUGIN" {
                currentPluginFormat = .VST3  // Treat as VST3 for compatibility
                if currentManufacturer.isEmpty {
                    currentManufacturer = "Tracktion"
                }
            }

            print("   🔌 Found plugin: \(currentPluginName) by \(currentManufacturer)")
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        // End of plugin
        if elementName == "PLUGIN" || elementName == "VST" || elementName == "VST3" ||
           elementName == "AU" || elementName == "TRACKTIONPLUGIN" {
            inPlugin = false

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
        if elementName == "TRACK" {
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

    private func extractPluginNameFromFilename(_ filename: String) -> String {
        // Extract plugin name from path like "/Library/Audio/Plug-Ins/VST3/FabFilter Pro-Q 3.vst3"
        var name = filename

        // Get last path component
        if filename.contains("/") {
            name = filename.components(separatedBy: "/").last ?? filename
        } else if filename.contains("\\") {
            name = filename.components(separatedBy: "\\").last ?? filename
        }

        // Remove file extensions
        name = name
            .replacingOccurrences(of: ".vst3", with: "")
            .replacingOccurrences(of: ".vst", with: "")
            .replacingOccurrences(of: ".dll", with: "")
            .replacingOccurrences(of: ".component", with: "")
            .trimmingCharacters(in: .whitespaces)

        return name
    }
}
