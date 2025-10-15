//
//  FastFilterEngine.swift
//  PluginReporter
//
//  BRAND NEW - Simple, fast, and CORRECT filtering
//

import Foundation

/// Ultra-simple, ultra-fast filtering engine
/// NO complex logic - just straightforward filtering that WORKS
struct FastFilterEngine {

    /// Filter plugins based on selected criteria
    /// - Parameters:
    ///   - plugins: All plugins to filter
    ///   - formats: Selected format filters (empty = show all)
    ///   - publishers: Selected publisher filters (empty = show all)
    ///   - styles: Selected style filters (empty = show all)
    ///   - searchText: Search query (empty = no search)
    /// - Returns: Filtered array
    static func filter(
        plugins: [AppPluginItem],
        formats: Set<PluginFormat>,
        publishers: Set<String>,
        styles: Set<String>,
        searchText: String
    ) -> [AppPluginItem] {

        var result = plugins

        // STEP 1: Format filter
        // Empty set = show all, otherwise show only selected formats
        if !formats.isEmpty {
            result = result.filter { plugin in
                // Handle OBSLT special case
                if formats.contains(.OBSLT) {
                    if formats.count == 1 {
                        // Only OBSLT - show obsolete only
                        return plugin.obsolete
                    } else {
                        // OBSLT + others - show obsolete OR matching formats
                        if plugin.obsolete { return true }
                        let nonObslt = formats.filter { $0 != .OBSLT }
                        return nonObslt.contains { $0.rawValue == plugin.type }
                    }
                } else {
                    // Standard format filter
                    return formats.contains { $0.rawValue == plugin.type }
                }
            }
        }

        // STEP 2: Publisher filter
        // Empty set = show all, otherwise show only selected publishers
        if !publishers.isEmpty {
            result = result.filter { publishers.contains($0.publisher) }
        }

        // STEP 3: Style filter
        // Empty set = show all, otherwise show only selected styles
        if !styles.isEmpty {
            result = result.filter { styles.contains($0.style) }
        }

        // STEP 4: Search filter
        // Empty string = show all, otherwise search all fields
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { plugin in
                plugin.name.lowercased().contains(query) ||
                plugin.publisher.lowercased().contains(query) ||
                plugin.style.lowercased().contains(query) ||
                plugin.architectures.lowercased().contains(query) ||
                plugin.version.lowercased().contains(query) ||
                plugin.runtimeRequirement.lowercased().contains(query) ||
                plugin.type.lowercased() == query  // Exact match for type to avoid VST matching VST3
            }
        }

        return result
    }

    /// Sort plugins by given column
    static func sort(plugins: [AppPluginItem], by column: SortColumn, ascending: Bool) -> [AppPluginItem] {
        let sorted = plugins.sorted { a, b in
            let comparison: ComparisonResult

            switch column {
            case .name:
                comparison = a.name.localizedCaseInsensitiveCompare(b.name)
            case .publisher:
                comparison = a.publisher.localizedCaseInsensitiveCompare(b.publisher)
            case .type:
                comparison = a.type.localizedCaseInsensitiveCompare(b.type)
            case .style:
                comparison = a.style.localizedCaseInsensitiveCompare(b.style)
            case .version:
                comparison = a.version.localizedCaseInsensitiveCompare(b.version)
            case .date:
                if let dateA = a.date, let dateB = b.date {
                    comparison = dateA.compare(dateB)
                } else if a.date != nil {
                    comparison = .orderedAscending
                } else if b.date != nil {
                    comparison = .orderedDescending
                } else {
                    comparison = .orderedSame
                }
            case .size:
                if a.sizeBytes < b.sizeBytes {
                    comparison = .orderedAscending
                } else if a.sizeBytes > b.sizeBytes {
                    comparison = .orderedDescending
                } else {
                    comparison = .orderedSame
                }
            case .architectures:
                comparison = a.architectures.localizedCaseInsensitiveCompare(b.architectures)
            }

            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        return sorted
    }
}

/// Sort columns
enum SortColumn {
    case name, publisher, type, style, version, date, size, architectures
}
