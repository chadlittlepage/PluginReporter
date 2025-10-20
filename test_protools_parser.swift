#!/usr/bin/env swift

//
//  test_protools_parser.swift
//  Plugin Reporter
//
//  Quick test script for ProToolsParser
//

import Foundation

// Load the parser files
let testFileURL = URL(fileURLWithPath: "/Volumes/Media/Tracks/Rob/B4 U Go/ProTools/B4 U GO PT/B4 U GO PT.ptx")

print("🧪 Testing ProToolsParser with real .ptx file")
print("File: \(testFileURL.lastPathComponent)")
print("Size: \(try! Data(contentsOf: testFileURL).count) bytes")
print("")

do {
    let result = try ProToolsParser.parseProject(url: testFileURL)

    print("✅ Parsing successful!")
    print("")
    print("📊 Session Information:")
    print("   Name: \(result.name)")
    print("   DAW: \(result.dawType.rawValue)")
    print("   Sample Rate: \(result.sampleRate.map { String($0) } ?? "Unknown")")
    print("   Version: \(result.version ?? "Unknown")")
    print("")
    print("🎵 Tracks Found: \(result.tracks.count)")

    for (index, track) in result.tracks.enumerated() {
        print("   [\(index + 1)] \(track.name)")
        if !track.plugins.isEmpty {
            print("       Plugins: \(track.plugins.count)")
            for plugin in track.plugins {
                print("         • \(plugin.name) by \(plugin.manufacturer)")
            }
        } else {
            print("       (No plugins - use 'Export Session Info as Text' for plugin data)")
        }
    }

    print("")
    print("ℹ️  Note: PTX files are encrypted binary format.")
    print("   For complete plugin information, export session info as text from Pro Tools.")

} catch {
    print("❌ Error parsing file: \(error)")
}
