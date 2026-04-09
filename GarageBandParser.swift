//
//  GarageBandParser.swift
//  Plugin Reporter
//
//  Parser for GarageBand project files (.band)
//  GarageBand projects are package directories containing ProjectData plist
//

import Foundation

#if os(macOS)
/// Parser for GarageBand project files (Package-based)
/// Uses shared AppleDAWParser for common logic with Logic Pro and MainStage
class GarageBandParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .garageBand
    static let supportedExtensions: [String] = ["band"]

    static func parseProject(url: URL) throws -> ParsedProject {
        // Delegate to shared Apple DAW parser
        return try AppleDAWParser.parseAppleProject(
            url: url, dawType: .garageBand, supportedExtensions: supportedExtensions, dawName: "GarageBand"
        )
    }
}
#endif
