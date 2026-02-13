//
//  ProToolsParser.swift
//  Plugin Reporter
//
//  Parser for Pro Tools session files (.ptx)
//  Note: PTX files are encrypted binary format. For full plugin data,
//  users should export "Session Info as Text" from Pro Tools.
//
//  Format support:
//  - .ptx (binary, encrypted) - Limited track info, no plugins
//  - .txt (text export) - Full session info including plugins
//

import Foundation

/// Parser for Pro Tools PTX session files
/// Note: Due to the encrypted nature of .ptx files, this parser extracts
/// basic track information only. For complete plugin data, users should
/// use File -> Export -> Session Info as Text in Pro Tools and use
/// the ProToolsTextParser instead.
class ProToolsParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .proTools
    static let supportedExtensions: [String] = ["ptx", "txt"]

    static func parseProject(url: URL) throws -> ParsedProject {
        let ext = url.pathExtension.lowercased()

        guard supportedExtensions.contains(ext) else {
            throw ParserError.invalidFileType
        }

        // Route to appropriate parser based on extension and content
        if ext == "txt" {
            // Use text parser for exported session info
            return try ProToolsTextParser.parseProject(url: url)
        } else {
            // Check if PTX is XML or binary (read once, pass through)
            let data = try Data(contentsOf: url)

            // Check if it starts with XML declaration
            if let prefix = String(data: data.prefix(100), encoding: .utf8),
               prefix.contains("<?xml") {
                // This is an XML PTX file (test format)
                return try parseXMLPTX(url: url, data: data)
            } else {
                // Parse binary PTX file (pass data to avoid re-reading)
                return try parseBinaryPTX(url: url, data: data)
            }
        }
    }

    // MARK: - XML PTX Parsing (Test Format)

    private static func parseXMLPTX(url: URL, data: Data) throws -> ParsedProject {
        // Parse XML
        let parser = ProToolsXMLParser()
        try parser.parse(data: data)

        return ParsedProject(
            name: url.deletingPathExtension().lastPathComponent,
            sourceFile: url,
            dawType: .proTools,
            tracks: parser.tracks,
            tempo: parser.tempo,
            sampleRate: parser.sampleRate,
            version: parser.version,
            key: nil
        )
    }

    // MARK: - Binary PTX Parsing

    private static func parseBinaryPTX(url: URL, data: Data) throws -> ParsedProject {
        // Data already passed in - no duplicate file read!

        // Validate file is not empty
        guard !data.isEmpty else {
            throw ParserError.emptyFile
        }

        // Validate minimum file size (PTX files should be at least a few KB)
        guard data.count >= 100 else {
            throw ParserError.corruptedFile
        }

        // PTX files are XOR encrypted - we'll extract what we can from strings
        let tracks = try extractTracksFromBinary(data: data)
        let sessionName = extractSessionNameFromBinary(data: data, fallback: url.deletingPathExtension().lastPathComponent)

        // Build parsed tracks
        let parsedTracks = tracks.enumerated().map { (index, trackName) -> ParsedTrack in
            // PTX binary doesn't contain plugin info in accessible format
            // Return track with no plugins
            return ParsedTrack(
                name: trackName,
                index: index,
                plugins: []
            )
        }

        return ParsedProject(
            name: sessionName,
            sourceFile: url,
            dawType: .proTools,
            tracks: parsedTracks,
            tempo: nil,
            sampleRate: extractSampleRateFromBinary(data: data),
            version: extractVersionFromBinary(data: data),
            key: nil
        )
    }

    // MARK: - Binary Data Extraction

    /// Extract readable strings from binary data
    private static func extractStrings(from data: Data, minLength: Int = 4) -> [String] {
        var strings: [String] = []
        var currentString = Data()

        for byte in data {
            // Printable ASCII range (including space)
            if (byte >= 0x20 && byte <= 0x7E) {
                currentString.append(byte)
            } else {
                if currentString.count >= minLength {
                    if let str = String(data: currentString, encoding: .utf8) {
                        strings.append(str)
                    }
                }
                currentString = Data()
            }
        }

        // Don't forget the last string
        if currentString.count >= minLength {
            if let str = String(data: currentString, encoding: .utf8) {
                strings.append(str)
            }
        }

        return strings
    }

    /// Check if a string looks like a valid track name
    private static func isLikelyTrackName(_ str: String) -> Bool {
        // Must be reasonable length
        guard str.count >= 3 && str.count <= 50 else { return false }

        // Must have mostly alphanumeric and common punctuation
        let validChars = str.filter { $0.isLetter || $0.isNumber || " -_.,()#".contains($0) }
        guard Double(validChars.count) / Double(str.count) >= 0.8 else { return false }

        // Must have some letters
        guard str.contains(where: { $0.isLetter }) else { return false }

        // Skip strings with too many special characters in a row
        var specialCount = 0
        for char in str {
            if !char.isLetter && !char.isNumber && char != " " {
                specialCount += 1
                if specialCount > 2 {
                    return false
                }
            } else {
                specialCount = 0
            }
        }

        let lowerStr = str.lowercased()

        // Skip system strings
        let skipKeywords = ["protools", ".pt", "media", "audio", "session", "tracks",
                           "backup", "info #", "wavecache", "fade"]
        if skipKeywords.contains(where: { lowerStr.contains($0) }) {
            return false
        }

        // Skip dates
        if ["2024-", "2023-", "2022-", "202"].contains(where: { str.contains($0) }) {
            return false
        }

        // Skip paths and extensions
        if str.contains("/") || str.contains("\\") || str.hasPrefix(".") {
            return false
        }

        return true
    }

    /// Extract track names from binary PTX data
    /// PTX files contain track names as null-terminated strings
    /// Note: Due to encryption, extraction is limited to well-formed strings
    private static func extractTracksFromBinary(data: Data) throws -> [String] {
        let strings = extractStrings(from: data, minLength: 3)

        var trackNames: [String] = []
        var seenTracks = Set<String>()

        // Count string occurrences
        var stringCounts: [String: Int] = [:]
        for str in strings {
            if isLikelyTrackName(str) {
                stringCounts[str, default: 0] += 1
            }
        }

        // Track names typically appear 2-5 times in PTX files
        // Also include standard Pro Tools tracks
        for (str, count) in stringCounts {
            let isStandardTrack = ["Click 1", "Inst 1", "Master 1"].contains(str)
            if ((count >= 2 && count <= 6) || (isStandardTrack && count >= 2)) &&
               !seenTracks.contains(str) {
                trackNames.append(str)
                seenTracks.insert(str)
            }
        }

        // If we found no tracks, fall back to searching for standard tracks
        if trackNames.isEmpty {
            let standardTracks = ["Click 1", "Inst 1", "Master 1"]
            for track in standardTracks {
                if strings.contains(track) {
                    trackNames.append(track)
                }
            }
        }

        // Sort alphabetically for consistent output
        trackNames.sort()

        return trackNames
    }

    /// Extract session name from binary data
    private static func extractSessionNameFromBinary(data: Data, fallback: String) -> String {
        let strings = extractStrings(from: data, minLength: 5)

        // Look for strings that end with ".ptx" - these are usually the session name
        for str in strings {
            if str.hasSuffix(".ptx") || str.hasSuffix(".PTX") {
                return str.replacingOccurrences(of: ".ptx", with: "")
                    .replacingOccurrences(of: ".PTX", with: "")
            }
        }

        return fallback
    }

    /// Extract sample rate from binary data
    private static func extractSampleRateFromBinary(data: Data) -> Int? {
        // Common sample rates in Pro Tools
        let commonRates = [44100, 48000, 88200, 96000, 176400, 192000]

        // Look for these values in the binary data
        // Pro Tools stores sample rate as 32-bit integers
        for i in 0..<(data.count - 4) {
            let value = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: i, as: UInt32.self)
            }

            if commonRates.contains(Int(value)) {
                return Int(value)
            }
        }

        return nil
    }

    /// Extract Pro Tools version from binary data
    private static func extractVersionFromBinary(data: Data) -> String? {
        // PTX file header contains version info in the first few bytes
        // The version is typically in the format like "0010111100101011"
        if data.count < 20 {
            return nil
        }

        // Try to extract version string from header
        if let versionStr = String(data: data.prefix(100), encoding: .utf8) {
            // Look for version patterns
            if versionStr.contains("001011") {
                // This is Pro Tools 10-12 format
                return "10-12"
            }
        }

        return nil
    }
}

// MARK: - XML Parser

private class ProToolsXMLParser: NSObject, XMLParserDelegate {

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
    private var currentAttributes: [String: String] = [:]

    // Plugin parsing state
    private var currentPluginName = ""
    private var currentManufacturer = ""
    private var currentPluginFormat: PluginFormat = .AAX

    func parse(data: Data) throws {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        guard xmlParser.parse() else {
            throw ParserError.xmlParsingFailed
        }

        print("\n📊 PRO TOOLS XML PARSING COMPLETE")
        print("   Total tracks: \(tracks.count)")
        print("   Total plugins: \(tracks.flatMap { $0.plugins }.count)")
        print("   Version: \(version ?? "not found")")
        print("---\n")
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {

        elementStack.append(elementName)
        currentAttributes = attributeDict

        // Session metadata
        if elementName == "Session" {
            if let versionString = attributeDict["version"] {
                version = "Pro Tools \(versionString)"
            }
        }

        // Track detection
        if elementName == "Track" {
            currentTrackName = attributeDict["name"] ?? "Track \(currentTrackIndex + 1)"
            currentPlugins = []
            currentDeviceIndex = 0
            print("🎵 Found track: \(currentTrackName ?? "Unnamed")")
        }

        // Plugin detection
        if elementName == "Plugin" {
            currentPluginName = attributeDict["name"] ?? ""
            currentManufacturer = attributeDict["manufacturer"] ?? "Unknown"

            // Determine format from type attribute
            if let type = attributeDict["type"] {
                currentPluginFormat = parsePluginType(type)
            } else {
                currentPluginFormat = .AAX  // Default for Pro Tools
            }

            // Add plugin immediately
            if !currentPluginName.isEmpty {
                let plugin = ParsedPlugin(
                    name: currentPluginName,
                    manufacturer: currentManufacturer,
                    trackName: currentTrackName ?? "Track \(currentTrackIndex + 1)",
                    trackIndex: currentTrackIndex,
                    deviceIndex: currentDeviceIndex,
                    format: currentPluginFormat
                )
                currentPlugins.append(plugin)
                currentDeviceIndex += 1
                print("   ✅ Added plugin: \(currentPluginName) (\(currentPluginFormat))")

                // Reset
                currentPluginName = ""
                currentManufacturer = ""
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        // End of track
        if elementName == "Track" {
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

        elementStack.removeLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Not needed for this simple XML format
    }

    // MARK: - Helper Methods

    private func parsePluginType(_ typeString: String) -> PluginFormat {
        let lower = typeString.lowercased()

        if lower.contains("aax") {
            return .AAX
        } else if lower.contains("vst3") {
            return .VST3
        } else if lower.contains("vst") {
            return .VST
        } else if lower.contains("au") || lower.contains("audiounit") {
            return .AU
        } else {
            return .AAX  // Default for Pro Tools
        }
    }
}

// MARK: - Parser Information

extension ProToolsParser {
    /// Get information about PTX parsing limitations
    static var parsingNotes: String {
        """
        Pro Tools PTX File Parser

        ⚠️  IMPORTANT NOTES:

        PTX files (.ptx) are encrypted binary session files used by Pro Tools 10+.
        Due to the proprietary encryption, this parser has limitations:

        WHAT THIS PARSER EXTRACTS FROM .PTX FILES:
        ✓ Track names (basic extraction from binary)
        ✓ Session name
        ✓ Sample rate (if detectable)
        ✗ Plugin information (NOT available in binary format)
        ✗ Detailed track settings
        ✗ Automation data
        ✗ Mixer settings

        RECOMMENDED WORKFLOW FOR FULL PLUGIN DATA:

        1. Open your session in Pro Tools
        2. Go to File → Export → Session Info as Text
        3. Save the .txt file
        4. Import the .txt file in Plugin Reporter

        The text export contains complete information including:
        • All plugins with manufacturer, version, and format (AAX/AU/VST)
        • Plugin instances per track
        • Complete track listing
        • Session metadata

        For questions about PTX format support, please note that Avid's
        PTX format is proprietary and encrypted. Full parsing requires
        reverse engineering or using Pro Tools' official export features.
        """
    }
}
