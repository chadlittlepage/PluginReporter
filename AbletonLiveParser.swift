//
//  AbletonLiveParser.swift
//  Plugin Reporter
//
//  Created by Claude Code on 10/17/25.
//  Copyright © 2025 Chad Littlepage. All rights reserved.
//

import Foundation
import Compression

// Import zlib for gzip decompression
import zlib

/// Parser for Ableton Live .als project files (Version 2 - Protocol-based)
class AbletonLiveParserV2: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .abletonLive
    static let supportedExtensions: [String] = ["als"]

    static func parseProject(url: URL) throws -> ParsedProject {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ParserError.invalidFileType
        }

        // 1. Read gzipped data
        let gzippedData = try Data(contentsOf: url)

        // 2. Decompress
        guard let xmlData = decompress(gzippedData) else {
            throw ParserError.decompressionFailed
        }

        // 3. Parse XML
        let parser = ALSXMLParser()
        try parser.parse(xmlData)

        // 4. Create result using standardized ParsedProject
        let projectName = url.deletingPathExtension().lastPathComponent
        return ParsedProject(
            name: projectName, sourceFile: url, dawType: .abletonLive, tracks: parser.tracks, tempo: parser.tempo, sampleRate: parser.sampleRate, version: parser.version, key: parser.key
        )
    }

    // MARK: - Gzip Decompression

    private static func decompress(_ data: Data) -> Data? {
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Data? in
            guard let baseAddress = ptr.baseAddress else { return nil }

            let bufferSize = 1024 * 1024 // 1MB buffer
            var outputData = Data()

            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uint(data.count)

            let resultCode = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
            guard resultCode == Z_OK else { return nil }

            defer { inflateEnd(&stream) }

            repeat {
                let buffer = UnsafeMutablePointer<Bytef>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }

                stream.next_out = buffer
                stream.avail_out = uint(bufferSize)

                let inflateResult = inflate(&stream, Z_NO_FLUSH)
                guard inflateResult == Z_OK || inflateResult == Z_STREAM_END else {
                    return nil
                }

                let decompressedSize = bufferSize - Int(stream.avail_out)
                outputData.append(buffer, count: decompressedSize)

                if inflateResult == Z_STREAM_END {
                    break
                }
            } while stream.avail_out == 0

            return outputData
        }
    }

}

// MARK: - XML Parser

private class ALSXMLParser: NSObject, XMLParserDelegate {

    var tracks: [ParsedTrack] = []
    var tempo: Double?
    var sampleRate: Int?
    var version: String?
    var key: String?

    private var currentTrackName = ""
    private var currentTrackIndex = 0
    private var currentDeviceIndex = 0
    private var currentPlugins: [ParsedPlugin] = []

    private var inTrack = false
    private var inPluginDevice = false
    private var inPluginDesc = false
    private var inVst3PluginInfo = false
    private var inAuPluginInfo = false

    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentFormat: PluginFormat = .AU  // Default to AU like the old parser
    private var currentPluginPath = ""
    private var currentBrowserContentPath = ""

    private var elementStack: [String] = []
    private var characterBuffer = ""
    private var inVstPluginInfo = false

    func parse(_ data: Data) throws {
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        // Summary
        print("\n📊 PARSING COMPLETE")
        print("   Total tracks: \(tracks.count)")
        print("   Total plugins: \(tracks.flatMap { $0.plugins }.count)")
        print("   Tempo: \(tempo.map { String($0) } ?? "not found")")
        print("   Sample Rate: \(sampleRate.map { String($0) } ?? "not found")")
        print("   Version: \(version ?? "not found")")
        print("   Key: \(key ?? "not found")")
        print("---\n")
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {

        elementStack.append(elementName)
        characterBuffer = ""

        // Track detection
        if elementName == "MidiTrack" || elementName == "AudioTrack" || elementName == "ReturnTrack" {
            print("🎵 Found track: \(elementName)")
            inTrack = true
            currentDeviceIndex = 0
            currentPlugins = []
        }

        // Plugin device detection
        if elementName == "PluginDevice" {
            print("🔌 Found PluginDevice")
            print("   Attributes: \(attributeDict)")
            inPluginDevice = true
            currentPluginName = ""
            currentManufacturer = ""
            currentFormat = .AU  // Reset to AU default
            currentPluginPath = ""
            currentBrowserContentPath = ""
        }

        // Plugin description
        if elementName == "PluginDesc" {
            print("📝 Found PluginDesc")
            print("   Attributes: \(attributeDict)")
            inPluginDesc = true
        }

        // VST2 Plugin Info
        if inPluginDesc && elementName == "VstPluginInfo" {
            print("🔷 Found VstPluginInfo (VST2)")
            inVstPluginInfo = true
            currentFormat = .VST
        }

        // VST3 Plugin Info
        if inPluginDesc && elementName == "Vst3PluginInfo" {
            print("🔷 Found Vst3PluginInfo")
            inVst3PluginInfo = true
            currentFormat = .VST3
        }

        // AU Plugin Info
        if inPluginDesc && elementName == "AuPluginInfo" {
            print("🔷 Found AuPluginInfo")
            inAuPluginInfo = true
            currentFormat = .AU
        }

        // Log all elements when in plugin parsing mode
        if inPluginDevice || inPluginDesc {
            if !attributeDict.isEmpty {
                print("   → \(elementName): \(attributeDict)")
            }
        }

        // Extract plugin name from Name element (inside Vst3PluginInfo or AuPluginInfo)
        if (inVst3PluginInfo || inAuPluginInfo) && elementName == "Name" {
            if let value = attributeDict["Value"], !value.isEmpty {
                print("   ✅ Found plugin name: \(value)")
                currentPluginName = value
            }
        }

        // Extract manufacturer
        if (inVst3PluginInfo || inAuPluginInfo) && elementName == "Manufacturer" {
            if let value = attributeDict["Value"], !value.isEmpty {
                print("   ✅ Found publisher: \(value)")
                currentManufacturer = value
            }
        }

        // VST2: Extract plugin name from PlugName
        if inVstPluginInfo && elementName == "PlugName" {
            if let value = attributeDict["Value"], !value.isEmpty {
                print("   ✅ Found VST2 plugin name: \(value)")
                currentPluginName = value
            }
        }

        // VST2: Extract file path
        if inVstPluginInfo && elementName == "Path" {
            if let value = attributeDict["Value"], !value.isEmpty {
                print("   ✅ Found VST2 path: \(value)")
                currentPluginPath = value
            }
        }

        // VST3: Extract BrowserContentPath for plugin name/manufacturer
        if inPluginDevice && elementName == "BrowserContentPath" {
            if let value = attributeDict["Value"], !value.isEmpty {
                print("   ✅ Found BrowserContentPath: \(value)")
                currentBrowserContentPath = value
                // Parse VST3 plugin name and manufacturer from BrowserContentPath
                parseVST3BrowserPath(value)
            }
        }

        // Track name from UserName or EffectiveName
        if inTrack && (elementName == "UserName" || elementName == "EffectiveName") {
            if let value = attributeDict["Value"], !value.isEmpty {
                currentTrackName = value
            }
        }

        // Extract project metadata
        if elementName == "Tempo" {
            if let manual = attributeDict["Manual"], let tempoValue = Double(manual) {
                tempo = tempoValue
            }
        }

        if elementName == "SampleRate" {
            if let value = attributeDict["Value"], let rate = Int(value) {
                sampleRate = rate
            }
        }

        if elementName == "Creator" {
            if let value = attributeDict["Value"] {
                version = value
            }
        }

        if elementName == "GlobalQuantisation" {
            if let value = attributeDict["Value"], let keyValue = Int(value) {
                key = mapKeyValue(keyValue)
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {

        // End of plugin device
        if elementName == "PluginDevice" {
            print("🔌 End PluginDevice - Name: '\(currentPluginName)', Manufacturer: '\(currentManufacturer)', Format: \(currentFormat)")
            inPluginDevice = false

            // Add plugin if we have valid data
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: currentPluginName, publisher: currentManufacturer.isEmpty ? "Unknown" : currentManufacturer, trackName: currentTrackName.isEmpty ? "Track \(currentTrackIndex + 1)" : currentTrackName, trackIndex: currentTrackIndex, deviceIndex: currentDeviceIndex, format: currentFormat
                )
                currentPlugins.append(plugin)
                print("   ✅ Added plugin: \(currentPluginName)")
                currentDeviceIndex += 1
            } else {
                print("   ❌ Plugin name was empty, not adding")
            }
        }

        // End of VstPluginInfo, Vst3PluginInfo, or AuPluginInfo
        if elementName == "VstPluginInfo" {
            inVstPluginInfo = false
        }
        if elementName == "Vst3PluginInfo" {
            inVst3PluginInfo = false
        }
        if elementName == "AuPluginInfo" {
            inAuPluginInfo = false
        }

        // End of plugin description
        if elementName == "PluginDesc" {
            inPluginDesc = false
        }

        // End of track
        if elementName == "MidiTrack" || elementName == "AudioTrack" || elementName == "ReturnTrack" {
            print("🎵 End track '\(currentTrackName.isEmpty ? "Track \(currentTrackIndex + 1)" : currentTrackName)' - Plugins: \(currentPlugins.count)")
            inTrack = false

            // Only add track if it has plugins
            if !currentPlugins.isEmpty {
                let trackName = currentTrackName.isEmpty ? "Track \(currentTrackIndex + 1)" : currentTrackName
                let track = ParsedTrack(
                    name: trackName, index: currentTrackIndex, plugins: currentPlugins
                )
                tracks.append(track)
                print("   ✅ Added track with \(currentPlugins.count) plugins")
            } else {
                print("   ⚠️ Track had no plugins, not adding")
            }

            currentTrackIndex += 1
            currentTrackName = ""
            currentPlugins = []
        }

        elementStack.removeLast()
        characterBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer += string
    }

    // MARK: - Helpers

    private func parsePluginFormat(_ formatString: String) -> PluginFormat {
        let lower = formatString.lowercased()

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
            return .unknown
        }
    }

    private func mapKeyValue(_ value: Int) -> String {
        // Ableton Live key mapping (0-11 = C to B)
        let keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let normalizedValue = value % 12
        return keys[normalizedValue]
    }

    /// Parse VST3 plugin name and manufacturer from BrowserContentPath
    /// Format: "view:X-Plugins#Universal%20Audio:UAD%20Lexicon%20224"
    /// or: "view:X-Plugins#Universal%20Audio%20(UADx):UADx%20Lexicon%20224%20Digital%20Reverb"
    private func parseVST3BrowserPath(_ path: String) {
        // Split by '#' to get the part after it
        let components = path.components(separatedBy: "#")
        guard components.count > 1 else { return }

        // Get the part after '#': "Universal%20Audio:UAD%20Lexicon%20224"
        let afterHash = components[1]

        // Split by ':' to separate manufacturer from plugin name
        let parts = afterHash.components(separatedBy: ":")
        guard parts.count > 1 else { return }

        // Decode URL encoding (%20 -> space, etc.)
        let manufacturer = parts[0].removingPercentEncoding ?? parts[0]
        let pluginName = parts[1].removingPercentEncoding ?? parts[1]

        // Only set if we don't already have values (prefer explicit values)
        if currentManufacturer.isEmpty {
            currentManufacturer = manufacturer
            print("   ✅ Extracted manufacturer from path: \(manufacturer)")
        }

        if currentPluginName.isEmpty {
            currentPluginName = pluginName
            print("   ✅ Extracted plugin name from path: \(pluginName)")
        }
    }
}