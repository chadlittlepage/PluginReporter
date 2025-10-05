//
//  ColorUtilities.swift
//  PluginReporter
//
//  Shared utilities for plugin format colors and sorting
//

import SwiftUI

enum ColorUtilities {
    /// Returns sort order for plugin formats
    static func formatSortOrder(_ format: String) -> Int {
        switch format.uppercased() {
        case "VST3": return 0
        case "VST": return 1
        case "AU": return 2
        case "AAX": return 3
        case "CLAP": return 4
        case "LV2": return 5
        case "OBSLT": return 99
        default: return 50
        }
    }

    /// Returns color for plugin format
    static func colorForFormat(_ format: String) -> Color {
        switch format.uppercased() {
        case "VST3": return .blue
        case "VST": return .purple
        case "AU": return .green
        case "AAX": return .orange
        case "CLAP": return .pink
        case "LV2": return .cyan
        case "OBSLT": return .red
        default: return .gray
        }
    }
}
