//
//  StudioOneParser.swift
//  Plugin Reporter
//
//  Parser for PreSonus Studio One project files (.song)
//  Studio One uses a ZIP archive containing XML files
//

import Foundation
import Compression

#if os(macOS)
/// Parser for Studio One (PreSonus) project files
class StudioOneParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .studioOne
    static let supportedExtensions: [String] = ["song"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // Studio One .song files are ZIP archives
        // Extract both song.xml (for tracks/metadata) and audiomixer.xml (for plugins)
        let (songData, mixerData) = try extractProjectFiles(from: url)

        // Parse the XMLs
        let parser = StudioOneXMLParser()
        try parser.parse(songData: songData, mixerData: mixerData)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent, sourceFile: url, dawType: .studioOne, tracks: parser.tracks, tempo: parser.tempo, sampleRate: parser.sampleRate, version: parser.version, key: nil
        )
    }

    // MARK: - ZIP Extraction

    private static func extractProjectFiles(from url: URL) throws -> (songData: Data, mixerData: Data?) {
        // Studio One .song files are ZIP archives containing:
        // - Song/song.xml (tracks, metadata)
        // - Devices/audiomixer.xml (plugins)

        print("📦 Extracting Studio One .song file: \(url.lastPathComponent)")

        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Unzip the .song file
        try unzipSongFile(from: url, to: tempDir)

        // Look for Song/song.xml
        var songData: Data?
        let songPaths = [
            tempDir.appendingPathComponent("Song/song.xml"), tempDir.appendingPathComponent("Song/Song.xml"), tempDir.appendingPathComponent("song.xml"), tempDir.appendingPathComponent("Song.xml")
        ]

        for path in songPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                print("✅ Found song.xml at: \(path.lastPathComponent)")
                songData = try Data(contentsOf: path)
                break
            }
        }

        guard let songXML = songData else {
            throw ParserError.invalidProjectData("Could not find song.xml in Studio One project")
        }

        // Look for Devices/audiomixer.xml (contains plugins)
        var mixerData: Data?
        let mixerPaths = [
            tempDir.appendingPathComponent("Devices/audiomixer.xml"), tempDir.appendingPathComponent("Devices/AudioMixer.xml"), tempDir.appendingPathComponent("audiomixer.xml")
        ]

        for path in mixerPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                print("✅ Found audiomixer.xml at: \(path.lastPathComponent)")
                mixerData = try Data(contentsOf: path)
                break
            }
        }

        return (songXML, mixerData)
    }

    private static func unzipSongFile(from sourceURL: URL, to destinationURL: URL) throws {
        // Use unzip command to extract .song file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", sourceURL.path, "-d", destinationURL.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ Unzip error: \(errorMessage)")
            throw ParserError.decompressionFailed
        }

        print("✅ Successfully extracted .song archive")
    }
}

// MARK: - XML Parser

private class StudioOneXMLParser: NSObject, XMLParserDelegate {

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
    private var inDevice = false
    private var inPlugin = false
    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentPluginFormat: PluginFormat = .VST3

    func parse(songData: Data, mixerData: Data?) throws {
        // First parse song.xml for track names and metadata
        print("🎵 Parsing song.xml for track names and metadata...")
        let songParser = XMLParser(data: songData)
        songParser.delegate = self

        guard songParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        // Then parse audiomixer.xml for plugins
        if let mixerXML = mixerData {
            print("🔌 Parsing audiomixer.xml for plugins...")
            try parseMixerXML(data: mixerXML)
        } else {
            print("⚠️ No audiomixer.xml found - project may have no plugins")
        }

        print("\n📊 STUDIO ONE PARSING COMPLETE")
        print("   Total tracks: \(tracks.count)")
        print("   Total plugins: \(tracks.flatMap { $0.plugins }.count)")
        print("   Tempo: \(tempo.map { String($0) } ?? "not found")")
        print("   Sample Rate: \(sampleRate.map { String($0) } ?? "not found")")
        print("   Version: \(version ?? "not found")")
        print("---\n")
    }

    // MARK: - Mixer XML Parsing

    private func parseMixerXML(data: Data) throws {
        let mixerParser = StudioOneMixerParser()
        try mixerParser.parse(data: data)

        // Match plugins to tracks by track label
        for (trackLabel, plugins) in mixerParser.trackPlugins {
            // Find the track with this label
            if let trackIndex = tracks.firstIndex(where: { $0.name == trackLabel }) {
                // Update the track with plugins
                var updatedTrack = tracks[trackIndex]
                updatedTrack = ParsedTrack(
                    name: updatedTrack.name, index: updatedTrack.index, plugins: plugins
                )
                tracks[trackIndex] = updatedTrack
                print("✅ Added \(plugins.count) plugins to track '\(trackLabel)'")
            } else {
                // Track not found - create a new one
                let newTrack = ParsedTrack(
                    name: trackLabel, index: tracks.count, plugins: plugins
                )
                tracks.append(newTrack)
                print("✅ Created new track '\(trackLabel)' with \(plugins.count) plugins")
            }
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        characterBuffer = ""
        currentAttributes = attributeDict

        // Song metadata
        if elementName == "Song" {
            if let versionString = attributeDict["version"] {
                version = "Studio One \(versionString)"
            }
        }

        // Tempo detection
        if elementName == "Tempo" {
            if let value = attributeDict["value"], let tempoValue = Double(value) {
                tempo = tempoValue
            } else if let bpm = attributeDict["bpm"], let tempoValue = Double(bpm) {
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
        if elementName == "Track" || elementName == "AudioTrack" || elementName == "InstrumentTrack" {
            currentTrackName = attributeDict["name"] ?? attributeDict["title"] ?? "Track \(currentTrackIndex + 1)"
            currentPlugins = []
            currentDeviceIndex = 0
            print("🎵 Found track: \(currentTrackName ?? "Unnamed")")
        }

        // Device/Plugin detection
        if elementName == "Device" || elementName == "Plugin" || elementName == "VST" || elementName == "VST3" {
            inDevice = true
            inPlugin = true
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginFormat = .VST3

            // Extract plugin info from attributes
            if let name = attributeDict["name"] {
                currentPluginName = name
            } else if let title = attributeDict["title"] {
                currentPluginName = title
            } else if let id = attributeDict["id"] {
                currentPluginName = id
            }

            if let vendor = attributeDict["vendor"] {
                currentManufacturer = vendor
            } else if let manufacturer = attributeDict["manufacturer"] {
                currentManufacturer = manufacturer
            }

            // Determine format
            if elementName == "VST3" || attributeDict["type"]?.contains("VST3") == true {
                currentPluginFormat = .VST3
            } else if elementName == "VST" || attributeDict["type"]?.contains("VST") == true {
                currentPluginFormat = .VST
            } else if attributeDict["type"]?.contains("AU") == true {
                currentPluginFormat = .AU
            }

            print("   🔌 Found plugin: \(currentPluginName) by \(currentManufacturer)")
        }

        // PreSonus native plugins
        if elementName == "PreSonusPlugin" || elementName == "NativeDevice" {
            inDevice = true
            inPlugin = true
            currentManufacturer = "PreSonus"
            currentPluginFormat = .VST3

            if let name = attributeDict["name"] ?? attributeDict["title"] {
                currentPluginName = name
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {

        // End of plugin/device
        if elementName == "Device" || elementName == "Plugin" || elementName == "VST" || elementName == "VST3" || elementName == "PreSonusPlugin" || elementName == "NativeDevice" {
            inDevice = false
            inPlugin = false

            // Add plugin if we have valid data
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: currentPluginName, publisher: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer, trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)", trackIndex: currentTrackIndex, deviceIndex: currentDeviceIndex, format: currentPluginFormat
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
        if elementName == "Track" || elementName == "AudioTrack" || elementName == "InstrumentTrack" || elementName == "MediaTrack" {
            // Always add track (plugins will be added later from audiomixer.xml)
            let trackName = currentTrackName ?? "Track \(currentTrackIndex + 1)"
            let track = ParsedTrack(
                name: trackName, index: currentTrackIndex, plugins: currentPlugins  // Will be empty for now, updated later
            )
            tracks.append(track)

            if currentPlugins.isEmpty {
                print("🎵 Added track '\(trackName)' (plugins will be loaded from mixer)")
            } else {
                print("🎵 Added track '\(trackName)' with \(currentPlugins.count) plugins")
            }

            currentTrackIndex += 1
            currentTrackName = nil
            currentPlugins = []
            currentDeviceIndex = 0
        }

        // Handle character data
        if !characterBuffer.isEmpty {
            let trimmed = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

            if elementName == "Name" && inPlugin && !trimmed.isEmpty {
                currentPluginName = trimmed
            }

            if elementName == "Vendor" && inPlugin && !trimmed.isEmpty {
                currentManufacturer = trimmed
            }

            if elementName == "Manufacturer" && inPlugin && !trimmed.isEmpty {
                currentManufacturer = trimmed
            }
        }

        elementStack.removeLast()
        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }
}

// MARK: - Mixer XML Parser

private class StudioOneMixerParser: NSObject, XMLParserDelegate {

    // Map of track label -> plugins
    var trackPlugins: [String: [ParsedPlugin]] = [:]

    private var currentTrackLabel: String?
    private var currentTrackIndex = 0
    private var currentPlugins: [ParsedPlugin] = []
    private var currentDeviceIndex = 0

    // Plugin parsing state
    private var inInserts = false
    private var inDeviceData = false
    private var currentPluginName = ""
    private var currentPluginCategory = ""
    private var currentPluginSubCategory = ""

    // XML parsing state
    private var elementStack: [String] = []
    private var currentAttributes: [String: String] = [:]

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        currentAttributes = attributeDict

        // AudioTrackChannel contains the track label and plugins
        if elementName == "AudioTrackChannel" {
            currentTrackLabel = attributeDict["label"] ?? attributeDict["name"]
            currentPlugins = []
            currentDeviceIndex = 0

            if let label = currentTrackLabel {
                print("🎵 Found mixer channel: \(label)")
            }
        }

        // Inserts section contains the plugin slots
        if elementName == "Attributes" && attributeDict["x:id"] == "Inserts" {
            inInserts = true
        }

        // Each plugin slot (FX01, FX02, etc.)
        if inInserts && elementName == "Attributes" && attributeDict["name"]?.starts(with: "FX") == true {
            currentDeviceIndex = parseSlotNumber(attributeDict["name"] ?? "")
        }

        // deviceData contains the plugin name
        if elementName == "Attributes" && attributeDict["x:id"] == "deviceData" {
            inDeviceData = true
            currentPluginName = attributeDict["name"] ?? ""
        }

        // classInfo contains plugin category info
        if inDeviceData && elementName == "Attributes" && attributeDict["x:id"] == "classInfo" {
            currentPluginCategory = attributeDict["category"] ?? ""
            currentPluginSubCategory = attributeDict["subCategory"] ?? ""

            // If we don't have a plugin name yet, try to get it from classInfo
            if currentPluginName.isEmpty {
                currentPluginName = attributeDict["name"] ?? ""
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {

        // End of deviceData - add the plugin
        if elementName == "Attributes" && inDeviceData {
            inDeviceData = false

            if !currentPluginName.isEmpty, let trackLabel = currentTrackLabel {
                // Determine manufacturer from subcategory
                let manufacturer = extractManufacturer(from: currentPluginSubCategory, pluginName: currentPluginName)

                // Determine format (AU for native, VST3 for others)
                let format: PluginFormat = currentPluginSubCategory.contains("(Native)") ? .AU : .VST3

                let plugin = ParsedPlugin(
                    name: currentPluginName, publisher: manufacturer, trackName: trackLabel, trackIndex: currentTrackIndex, deviceIndex: currentDeviceIndex, format: format
                )

                currentPlugins.append(plugin)
                print("   🔌 Found plugin: \(currentPluginName) by \(manufacturer)")
            }

            // Reset plugin state
            currentPluginName = ""
            currentPluginCategory = ""
            currentPluginSubCategory = ""
        }

        // End of Inserts section
        if elementName == "Attributes" && inInserts {
            inInserts = false
        }

        // End of AudioTrackChannel - save plugins for this track
        if elementName == "AudioTrackChannel" {
            if let trackLabel = currentTrackLabel, !currentPlugins.isEmpty {
                trackPlugins[trackLabel] = currentPlugins
                print("✅ Stored \(currentPlugins.count) plugins for track '\(trackLabel)'")
            }

            currentTrackLabel = nil
            currentPlugins = []
            currentTrackIndex += 1
        }

        elementStack.removeLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Not needed for attribute-based parsing
    }

    // MARK: - Helper Methods

    private func parseSlotNumber(_ slotName: String) -> Int {
        // Extract number from "FX01", "FX02", etc.
        let digits = slotName.filter { $0.isNumber }
        return Int(digits) ?? 0
    }

    private func extractManufacturer(from subCategory: String, pluginName: String) -> String {
        // Native Studio One plugins
        if subCategory.contains("(Native)") {
            return "PreSonus"
        }

        // Try to extract from subcategory
        // Format: "(Native)/Dynamics" or "Waves/Dynamics"
        if let manufacturer = subCategory.components(separatedBy: "/").first {
            let cleaned = manufacturer.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            if !cleaned.isEmpty && cleaned != "Native" {
                return cleaned
            }
        }

        // Fallback to Unknown
        return "Unknown"
    }
}
#endif