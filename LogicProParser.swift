//
//  LogicProParser.swift
//  Plugin Reporter
//
//  Parser for Logic Pro project files (.logic, .logicx)
//  Logic projects are package directories containing ProjectData plist
//

import Foundation

#if os(macOS)
/// Parser for Logic Pro project files (Package-based)
/// Uses shared AppleDAWParser for common logic with GarageBand and MainStage
class LogicProParser: DAWParser {

    // MARK: - DAWParser Protocol Conformance

    static let dawType: DAWType = .logicPro
    static let supportedExtensions: [String] = ["logic", "logicx"]

    static func parseProject(url: URL) throws -> ParsedProject {
        // Delegate to shared Apple DAW parser
        return try AppleDAWParser.parseAppleProject(
            url: url, dawType: .logicPro, supportedExtensions: supportedExtensions, dawName: "Logic Pro"
        )
    }
}
#endif