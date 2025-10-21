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
        plugins: [PluginItem],
        formats: Set<PluginFormat>,
        publishers: Set<String>,
        styles: Set<String>,
        searchText: String
    ) -> [PluginItem] {

        #if DEBUG
        AppLogger.debug("FastFilterEngine.filter() called with search: '\(searchText)'")
        #endif

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

        // STEP 4: Search filter (optimized - compute query strings once)
        // Empty string = show all, otherwise search all fields
        if !searchText.isEmpty {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryUpper = trimmed.uppercased()

            // Check if search query is a known plugin format
            let knownFormats = ["AU", "VST", "VST3", "AAX", "CLAP", "LV2", "OBSLT", "OBSOLETE"]
            let isFormatSearch = knownFormats.contains(queryUpper)

            if isFormatSearch {
                // Format search: EXACT match
                let isObsoleteSearch = (queryUpper == "OBSOLETE")
                result = result.filter { plugin in
                    isObsoleteSearch ? (plugin.type == "OBSLT" || plugin.obsolete) : plugin.type == queryUpper
                }
            } else {
                // Regular search: Pre-compute lowercase query ONCE
                let queryLower = trimmed.lowercased()
                result = result.filter { plugin in
                    let basicMatch = plugin.name.lowercased().contains(queryLower) ||
                        plugin.publisher.lowercased().contains(queryLower) ||
                        plugin.style.lowercased().contains(queryLower) ||
                        plugin.architectures.lowercased().contains(queryLower) ||
                        plugin.version.lowercased().contains(queryLower) ||
                        plugin.runtimeRequirement.lowercased().contains(queryLower)

                    #if os(macOS)
                    // License search only available on macOS
                    let licenseMatch = LicenseTypeHelper.getCachedLicenseType(for: plugin).lowercased().contains(queryLower)
                    return basicMatch || licenseMatch
                    #else
                    return basicMatch
                    #endif
                }
            }
        }

        return result
    }

    /// Sort plugins by given column
    static func sort(plugins: [PluginItem], by column: SortColumn, ascending: Bool) -> [PluginItem] {
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
