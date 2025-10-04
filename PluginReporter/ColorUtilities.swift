//
//  ColorUtilities.swift
//  Plugin Reporter
//
//  Shared color utilities for plugin type badges
//

import SwiftUI

/// Provides consistent colors for plugin format types across the app
enum ColorUtilities {

    /// Returns the standard color for a given plugin format type
    /// - Parameter format: The plugin format (AU, VST, VST3, AAX, CLAP, LV2, OBSLT, etc.)
    /// - Returns: The SwiftUI Color for that format
    static func colorForFormat(_ format: String) -> Color {
        switch format.uppercased() {
        case "AU": return .blue
        case "VST": return .green
        case "VST3": return .cyan
        case "AAX": return .purple
        case "CLAP": return .orange
        case "LV2": return .gray
        case "LADSPA": return .indigo
        case "RTAS": return .mint
        case "OBSLT", "OBSOLETE": return .red
        default: return .gray
        }
    }

    /// Returns the sort order for plugin formats (used for consistent display ordering)
    /// - Parameter format: The plugin format
    /// - Returns: Sort order index (lower numbers appear first)
    static func formatSortOrder(_ format: String) -> Int {
        switch format.uppercased() {
        case "AU": return 1
        case "VST": return 2
        case "VST3": return 3
        case "AAX": return 4
        case "CLAP": return 5
        case "LV2": return 6
        case "LADSPA": return 7
        case "RTAS": return 8
        case "OBSLT", "OBSOLETE": return 99
        default: return 50
        }
    }
}
