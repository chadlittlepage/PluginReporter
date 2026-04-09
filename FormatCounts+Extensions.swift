//
//  FormatCounts+Extensions.swift
//  Plugin Reporter
//
//  Shared format counting utilities
//  Consolidates duplicate counting logic across the app
//

import Foundation

// MARK: - FormatCounts Structure

/// Shared structure for counting plugin formats
struct FormatCounts: Equatable, Hashable {
    var au: Int = 0
    var vst: Int = 0
    var vst3: Int = 0
    var aax: Int = 0
    var clap: Int = 0
    var lv2: Int = 0
    var obsolete: Int = 0
    var missing: Int = 0
}

// MARK: - Counting Extensions

extension FormatCounts {
    /// Increment counter for a given format type string
    mutating func increment(for type: String) {
        switch type.uppercased() {
        case "AU":   au += 1
        case "VST":  vst += 1
        case "VST3": vst3 += 1
        case "AAX":  aax += 1
        case "CLAP": clap += 1
        case "LV2":  lv2 += 1
        case "OBSLT", "OBSOLETE": obsolete += 1
        default: break
        }
    }
}

// MARK: - Helper Functions for Different Plugin Types

#if os(macOS)
/// Count formats from AppPluginItem array
func countFormats(for items: [AppPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in items {
        counts.increment(for: item.type)
        if item.obsolete && item.type.uppercased() != "OBSLT" && item.type.uppercased() != "OBSOLETE" {
            counts.obsolete += 1
        }
        if item.missing { counts.missing += 1 }
    }
    return counts
}
#endif

/// Count formats from ScannerPluginItem array
func countFormats(for items: [ScannerPluginItem]) -> FormatCounts {
    var counts = FormatCounts()
    for item in items {
        counts.increment(for: item.type)
        if item.obsolete && item.type.uppercased() != "OBSLT" && item.type.uppercased() != "OBSOLETE" {
            counts.obsolete += 1
        }
    }
    return counts
}
