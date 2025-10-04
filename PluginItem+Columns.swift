// PluginItem+Columns.swift
// Convenience columns used by UI and exporters

import Foundation

public extension PluginItem {
    /// Human-readable date (eg. "Jan 9, 2025"). Empty if `date` is nil.
    var dateString: String {
        date.map(Humanize.date) ?? ""
    }

    /// Human-readable size (eg. "719 KB").
    var sizeString: String {
        Humanize.bytes(sizeBytes)
    }

    /// "Yes"/"No" string for obsolete flag.
    var obsoleteString: String {
        obsolete ? "Yes" : "No"
    }

    /// Numeric key (seconds since 1970) used for fast/s table sorting and JSON export.
    var dateSortKey: Double {
        date?.timeIntervalSince1970 ?? 0
    }
}
