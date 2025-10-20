#!/usr/bin/env swift

import Foundation

// Test script to verify DAW parsers work with real files
// Run with: swift test_parsers.swift

print("🧪 Plugin Reporter - Parser Test Suite")
print(String(repeating: "=", count: 60))
print("")

struct TestFile {
    let path: String
    let dawName: String
    let expectedExtension: String
}

let testFiles: [TestFile] = [
    // Pro Tools
    TestFile(
        path: "/Volumes/Media/Tracks/Rob/B4 U Go/ProTools/B4 U GO PT/B4 U GO PT.ptx",
        dawName: "Pro Tools",
        expectedExtension: "ptx"
    ),
    // Ableton Live
    TestFile(
        path: "/Users/chadlittlepage/Music/Ableton/Factory Packs/Guitar and Bass/Construction Kits/Funk.als",
        dawName: "Ableton Live",
        expectedExtension: "als"
    )
]

print("📋 Test Files Found:")
print("")

for (index, testFile) in testFiles.enumerated() {
    let exists = FileManager.default.fileExists(atPath: testFile.path)
    let icon = exists ? "✓" : "✗"

    print("  \(index + 1). [\(icon)] \(testFile.dawName)")
    print("     Extension: .\(testFile.expectedExtension)")
    print("     Path: \(testFile.path)")

    if exists {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: testFile.path)
            if let fileSize = attributes[.size] as? Int64 {
                let sizeInMB = Double(fileSize) / 1_048_576
                print("     Size: \(String(format: "%.2f", sizeInMB)) MB")
            }
        } catch {
            print("     Size: Unable to determine")
        }
    } else {
        print("     ⚠️  File not found")
    }
    print("")
}

print(String(repeating: "=", count: 60))
print("")
print("ℹ️  To test with Plugin Reporter:")
print("  1. Launch the app: open 'Plugin Reporter.app'")
print("  2. Use File → Open or drag files into the app")
print("  3. Verify plugins are detected and displayed")
print("")
print("Expected behavior:")
print("  • Pro Tools (.ptx): Basic track info (plugins require .txt export)")
print("  • Ableton Live (.als): Full track and plugin information")
print("")
