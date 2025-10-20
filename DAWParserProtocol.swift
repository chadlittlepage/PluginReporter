//
//  DAWParserProtocol.swift
//  Plugin Reporter
//
//  Protocol-based architecture for parsing multiple DAW project formats
//

import Foundation

// MARK: - Parser Protocol

/// Protocol that all DAW parsers must conform to
protocol DAWParser {
    /// The DAW type this parser handles
    static var dawType: DAWType { get }

    /// File extensions this parser can handle (e.g., ["als"] for Ableton Live)
    static var supportedExtensions: [String] { get }

    /// Parse a project file and return structured data
    /// - Parameter url: URL to the project file
    /// - Returns: Parsed project data
    /// - Throws: Parser-specific errors
    static func parseProject(url: URL) throws -> ParsedProject
}

// MARK: - Parsed Data Models

/// Standardized project data structure returned by all DAW parsers
struct ParsedProject {
    let name: String
    let sourceFile: URL
    let dawType: DAWType
    let tracks: [ParsedTrack]

    // Optional metadata fields
    let tempo: Double?
    let sampleRate: Int?
    let version: String?
    let key: String?

    /// All plugins from all tracks
    var allPlugins: [ParsedPlugin] {
        tracks.flatMap { $0.plugins }
    }

    init(
        name: String,
        sourceFile: URL,
        dawType: DAWType,
        tracks: [ParsedTrack],
        tempo: Double? = nil,
        sampleRate: Int? = nil,
        version: String? = nil,
        key: String? = nil
    ) {
        self.name = name
        self.sourceFile = sourceFile
        self.dawType = dawType
        self.tracks = tracks
        self.tempo = tempo
        self.sampleRate = sampleRate
        self.version = version
        self.key = key
    }
}

struct ParsedTrack {
    let name: String
    let index: Int
    let plugins: [ParsedPlugin]
}

struct ParsedPlugin {
    let name: String
    let manufacturer: String
    let trackName: String
    let trackIndex: Int
    let deviceIndex: Int
    let format: PluginFormat
}

// MARK: - Parser Registry

/// Central registry for all DAW parsers
class DAWParserRegistry {
    static let shared = DAWParserRegistry()

    private var parsers: [any DAWParser.Type] = []

    private init() {
        // Register built-in parsers
        registerParser(AbletonLiveParserV2.self)
        registerParser(ProToolsParser.self)  // Supports both .ptx and .txt files
        registerParser(BitwigParser.self)
        registerParser(LogicProParser.self)
        registerParser(GarageBandParser.self)
        registerParser(ReasonParser.self)
        registerParser(ReaperParser.self)
        registerParser(CubaseParser.self)
        registerParser(NuendoParser.self)
        registerParser(DigitalPerformerParser.self)
        registerParser(StudioOneParser.self)
        registerParser(FLStudioParser.self)
        registerParser(TracktionParser.self)
        registerParser(ArdourParser.self)
        registerParser(FairlightParser.self)
        #if os(macOS)
        registerParser(RenoiseParser.self)  // macOS only (uses Process for ZIP extraction)
        #endif
        registerParser(MainStageParser.self)
        registerParser(MixbusParser.self)
        // 17-18 DAW parsers (Renoise requires macOS)
    }

    /// Register a DAW parser
    func registerParser(_ parser: any DAWParser.Type) {
        parsers.append(parser)
        print("📦 Registered parser for \(parser.dawType.rawValue)")
    }

    /// Get parser for a specific DAW type
    func parser(for dawType: DAWType) -> (any DAWParser.Type)? {
        return parsers.first { $0.dawType == dawType }
    }

    /// Get parser for a file based on its extension
    func parser(for url: URL) -> (any DAWParser.Type)? {
        let ext = url.pathExtension.lowercased()
        return parsers.first { $0.supportedExtensions.contains(ext) }
    }

    /// Get all registered DAW types
    var supportedDAWs: [DAWType] {
        parsers.map { $0.dawType }
    }

    /// Get all supported file extensions
    var supportedExtensions: [String] {
        parsers.flatMap { $0.supportedExtensions }
    }

    /// Parse a project file using the appropriate parser
    func parseProject(url: URL, dawType: DAWType) throws -> ParsedProject {
        guard let parser = parser(for: dawType) else {
            throw ParserError.unsupportedDAWType(dawType)
        }
        return try parser.parseProject(url: url)
    }

    /// Auto-detect and parse a project file based on extension
    func parseProject(url: URL) throws -> ParsedProject {
        guard let parser = parser(for: url) else {
            throw ParserError.unsupportedFileExtension(url.pathExtension)
        }
        return try parser.parseProject(url: url)
    }
}

// MARK: - Parser Errors

enum ParserError: LocalizedError {
    case unsupportedDAWType(DAWType)
    case unsupportedFileExtension(String)
    case invalidFileType
    case decompressionFailed
    case xmlParsingFailed
    case invalidProjectData(String)
    case emptyFile
    case corruptedFile

    var errorDescription: String? {
        switch self {
        case .unsupportedDAWType(let type):
            return "Parser not available for \(type.rawValue)"
        case .unsupportedFileExtension(let ext):
            return "No parser available for .\(ext) files"
        case .invalidFileType:
            return "Invalid or corrupted project file"
        case .decompressionFailed:
            return "Failed to decompress project file"
        case .xmlParsingFailed:
            return "Failed to parse project XML/data"
        case .invalidProjectData(let reason):
            return "Invalid project data: \(reason)"
        case .emptyFile:
            return "The file is empty (0 bytes). This may be a backup file or corrupted project."
        case .corruptedFile:
            return "The file appears to be corrupted or incomplete. Please try opening the original project file."
        }
    }
}

// MARK: - Shared Metadata Extraction Utilities

/// Protocol extension providing common metadata extraction methods
/// Eliminates duplicate extraction code across 8+ parser implementations
extension DAWParser {

    /// Extract tempo/BPM from a dictionary with common key variations
    /// - Parameters:
    ///   - dict: Dictionary containing potential tempo data
    ///   - keys: Array of keys to check (defaults to common tempo keys)
    /// - Returns: Tempo as Double, or nil if not found
    static func extractTempo(from dict: [String: Any], keys: [String] = ["Tempo", "BPM", "tempo", "bpm"]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            }
            if let value = dict[key] as? Int {
                return Double(value)
            }
            if let value = dict[key] as? String, let parsed = Double(value) {
                return parsed
            }
        }
        return nil
    }

    /// Extract sample rate from a dictionary with common key variations
    /// - Parameters:
    ///   - dict: Dictionary containing potential sample rate data
    ///   - keys: Array of keys to check (defaults to common sample rate keys)
    /// - Returns: Sample rate as Int, or nil if not found
    static func extractSampleRate(from dict: [String: Any], keys: [String] = ["SampleRate", "SamplingRate", "sampleRate", "sample_rate"]) -> Int? {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            }
            if let value = dict[key] as? Double {
                return Int(value)
            }
            if let value = dict[key] as? String, let parsed = Int(value) {
                return parsed
            }
        }
        return nil
    }

    /// Extract version string from a dictionary or string with common patterns
    /// - Parameters:
    ///   - dict: Dictionary containing potential version data
    ///   - keys: Array of keys to check (defaults to common version keys)
    /// - Returns: Version string, or nil if not found
    static func extractVersion(from dict: [String: Any], keys: [String] = ["Version", "version", "AppVersion", "ProgramVersion"]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                return value
            }
            if let value = dict[key] as? Int {
                return String(value)
            }
            if let value = dict[key] as? Double {
                return String(format: "%.1f", value)
            }
        }
        return nil
    }

    /// Extract version from a string using regex pattern
    /// - Parameters:
    ///   - string: String containing version information
    ///   - pattern: Regex pattern to match version (defaults to digits and dots)
    /// - Returns: Extracted version string, or nil if not found
    static func extractVersionFromString(_ string: String, pattern: String = #"(\d+\.?\d*\.?\d*)"#) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else {
            return nil
        }

        if let versionRange = Range(match.range(at: 1), in: string) {
            return String(string[versionRange])
        }

        return nil
    }
}
