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
        // Extract and parse the main XML file
        let xmlData = try extractMainXML(from: url)

        // Parse the XML
        let parser = StudioOneXMLParser()
        try parser.parse(data: xmlData)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .studioOne,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
        )
    }

    // MARK: - ZIP Extraction

    private static func extractMainXML(from url: URL) throws -> Data {
        // Studio One .song files are ZIP archives containing song.xml
        // We need to extract the XML file using the unzip command

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

        // Look for the main XML file (typically "song.xml" or "Song.xml")
        let possibleXMLNames = ["song.xml", "Song.xml", "project.xml", "Project.xml"]

        for xmlName in possibleXMLNames {
            let xmlPath = tempDir.appendingPathComponent(xmlName)
            if FileManager.default.fileExists(atPath: xmlPath.path) {
                print("✅ Found XML file: \(xmlName)")
                return try Data(contentsOf: xmlPath)
            }
        }

        // If specific file not found, search for any .xml file in the temp directory
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "xml" {
                    print("✅ Found XML file: \(fileURL.lastPathComponent)")
                    return try Data(contentsOf: fileURL)
                }
            }
        }

        throw ParserError.invalidProjectData("Could not find XML data in Studio One project")
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

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        print("\n📊 STUDIO ONE PARSING COMPLETE")
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

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        // End of plugin/device
        if elementName == "Device" || elementName == "Plugin" || elementName == "VST" || elementName == "VST3" || elementName == "PreSonusPlugin" || elementName == "NativeDevice" {
            inDevice = false
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
        if elementName == "Track" || elementName == "AudioTrack" || elementName == "InstrumentTrack" {
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
#endif
