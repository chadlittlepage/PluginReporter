//
//  RenoiseParser.swift
//  Plugin Reporter
//
//  Parser for Renoise project files (.xrns)
//  XRNS files are ZIP archives containing XML + samples
//
//  Format: ZIP archive with Song.xml and samples
//  Reference: https://tutorials.renoise.com/wiki/XRNS_File_Format
//

import Foundation
#if os(macOS)
import Compression

/// Parser for Renoise XRNS project files
class RenoiseParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .renoise
    static let supportedExtensions: [String] = ["xrns"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // XRNS is a ZIP file containing Song.xml
        // We need to extract and parse Song.xml

        print("📦 Parsing Renoise XRNS file: \(url.lastPathComponent)")

        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Unzip the XRNS file
        try unzipXRNS(from: url, to: tempDir)

        // Look for Song.xml
        let songXMLPath = tempDir.appendingPathComponent("Song.xml")

        guard FileManager.default.fileExists(atPath: songXMLPath.path) else {
            throw ParserError.invalidProjectData("Song.xml not found in XRNS archive")
        }

        // Parse the XML
        let data = try Data(contentsOf: songXMLPath)
        let parser = RenoiseXMLParser()
        try parser.parse(data: data)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .renoise,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
        )
    }

    // MARK: - ZIP Extraction

    private static func unzipXRNS(from sourceURL: URL, to destinationURL: URL) throws {
        // Use NSTask to call unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", sourceURL.path, "-d", destinationURL.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ParserError.decompressionFailed
        }
    }
}

// MARK: - XML Parser

private class RenoiseXMLParser: NSObject, XMLParserDelegate {

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
    private var inPluginDevice = false
    private var inPluginProperties = false
    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentPluginPath = ""
    private var currentPluginFormat: PluginFormat = .VST3

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        print("\n📊 RENOISE PARSING COMPLETE")
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

        // Root element - RenoiseSong
        if elementName == "RenoiseSong" {
            // Version is in doc_version attribute
            if let docVersion = attributeDict["doc_version"] {
                version = "Renoise \(docVersion)"
            }
        }

        // Global song settings
        if elementName == "GlobalSongData" {
            // Will look for BeatsPerMin and SampleRate in child elements
        }

        // Track detection
        if elementName == "Track" || elementName == "SequencerTrack" {
            // Track name will be in a child element
            currentTrackName = nil
            currentPlugins = []
            currentDeviceIndex = 0
        }

        // Track name
        if elementName == "Name" && isInContext(["Track"]) {
            // Name content will come in foundCharacters
        }

        // Device chain detection (Renoise calls plugins "Devices")
        if elementName == "DeviceChain" {
            // Plugin devices will be children of this
        }

        // Plugin device detection
        if elementName == "PluginDevice" || elementName == "VstPluginDevice" ||
           elementName == "AudioUnitPluginDevice" || elementName == "LadspaPluginDevice" {
            inPluginDevice = true
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginPath = ""
            currentPluginFormat = .VST3  // Default

            // Determine format from element name
            if elementName == "VstPluginDevice" {
                currentPluginFormat = .VST
            } else if elementName == "AudioUnitPluginDevice" {
                currentPluginFormat = .AU
            } else if elementName == "LadspaPluginDevice" {
                currentPluginFormat = .VST  // Map LADSPA to VST
            }
        }

        // Plugin properties
        if elementName == "PluginProperties" && inPluginDevice {
            inPluginProperties = true
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        let content = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract global tempo
        if elementName == "BeatsPerMin" && isInContext(["GlobalSongData"]) {
            if let tempoValue = Double(content), tempo == nil {
                tempo = tempoValue
            }
        }

        // Extract sample rate (not always present in XRNS, Renoise defaults to 44100)
        if elementName == "SampleRate" {
            if let rate = Int(content) {
                sampleRate = rate
            }
        }

        // Track name
        if elementName == "Name" && isInContext(["Track"]) && currentTrackName == nil {
            if !content.isEmpty {
                currentTrackName = content
                print("🎵 Found track: \(content)")
            }
        }

        // Plugin name (inside PluginProperties or directly)
        if elementName == "PluginDisplayName" && inPluginDevice {
            currentPluginName = content
            print("   🔌 Found plugin: \(content)")
        } else if elementName == "PluginIdentifier" && inPluginDevice && currentPluginName.isEmpty {
            // Fallback to identifier if no display name
            currentPluginName = extractPluginNameFromIdentifier(content)
        }

        // Plugin path (can extract manufacturer from path)
        if elementName == "PluginPath" && inPluginDevice {
            currentPluginPath = content
            currentManufacturer = extractManufacturerFromPath(content)
        }

        // End of plugin properties
        if elementName == "PluginProperties" && inPluginProperties {
            inPluginProperties = false
        }

        // End of plugin device
        if (elementName == "PluginDevice" || elementName == "VstPluginDevice" ||
            elementName == "AudioUnitPluginDevice" || elementName == "LadspaPluginDevice") && inPluginDevice {
            inPluginDevice = false

            // Add plugin if we have valid data
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: cleanPluginName(currentPluginName),
                    manufacturer: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer,
                    trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)",
                    trackIndex: currentTrackIndex,
                    deviceIndex: currentDeviceIndex,
                    format: currentPluginFormat
                )
                currentPlugins.append(plugin)
                currentDeviceIndex += 1
                print("   ✅ Added plugin: \(plugin.name) by \(plugin.manufacturer)")
            }

            // Reset state
            currentPluginName = ""
            currentManufacturer = ""
            currentPluginPath = ""
        }

        // End of track
        if elementName == "Track" || elementName == "SequencerTrack" {
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

    private func isInContext(_ contextElements: [String]) -> Bool {
        // Check if we're currently inside any of the specified elements
        for element in contextElements {
            if elementStack.contains(element) {
                return true
            }
        }
        return false
    }

    private func extractPluginNameFromIdentifier(_ identifier: String) -> String {
        // Identifiers can be like: "VST:Manufacturer:PluginName"
        let components = identifier.components(separatedBy: ":")
        if components.count >= 3 {
            return components[2]
        } else if components.count >= 2 {
            return components[1]
        }
        return identifier
    }

    private func extractManufacturerFromPath(_ path: String) -> String {
        // Paths often contain manufacturer name
        // E.g., "/Library/Audio/Plug-Ins/VST/FabFilter/Pro-Q 3.vst"

        let components = path.components(separatedBy: "/")

        // Look for manufacturer in path
        for i in 0..<components.count {
            let component = components[i]

            // Skip common directory names
            if component.lowercased() == "library" ||
               component.lowercased() == "audio" ||
               component.lowercased() == "plug-ins" ||
               component.lowercased() == "vst" ||
               component.lowercased() == "vst3" ||
               component.lowercased() == "au" ||
               component.lowercased() == "components" {
                continue
            }

            // If we have a manufacturer-like name, and it's not a file
            if !component.isEmpty && !component.contains(".") && component.count > 2 {
                return component
            }
        }

        return "Unknown"
    }

    private func cleanPluginName(_ name: String) -> String {
        // Remove common suffixes and clean up
        var cleaned = name
            .replacingOccurrences(of: " (mono)", with: "")
            .replacingOccurrences(of: " (stereo)", with: "")
            .replacingOccurrences(of: " VST", with: "")
            .replacingOccurrences(of: " VST3", with: "")
            .replacingOccurrences(of: " AU", with: "")
            .replacingOccurrences(of: ".vst", with: "")
            .replacingOccurrences(of: ".vst3", with: "")
            .replacingOccurrences(of: ".component", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove version numbers at the end
        if let match = cleaned.range(of: #"\s+v?\d+(\.\d+)*$"#, options: .regularExpression) {
            cleaned.removeSubrange(match)
        }

        return cleaned
    }
}
#endif // os(macOS)
