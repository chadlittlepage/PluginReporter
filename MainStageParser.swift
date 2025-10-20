//
//  MainStageParser.swift
//  Plugin Reporter
//
//  Parser for MainStage concert files (.concert)
//  MainStage uses the same engine as Logic Pro with package/plist format
//

import Foundation

/// Parser for MainStage concert files (Package-based, Logic Pro compatible)
/// Uses shared AppleDAWParser for common logic with Logic Pro and GarageBand
class MainStageParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .mainStage
    static let supportedExtensions: [String] = ["concert"]

    static func parseProject(url: URL) throws -> ParsedProject {
        // Delegate to shared Apple DAW parser
        return try AppleDAWParser.parseAppleProject(
            url: url,
            dawType: .mainStage,
            supportedExtensions: supportedExtensions,
            dawName: "MainStage"
        )
    }
}
