//
//  PluginListViewModel.swift
//  PluginReporter (iOS)
//
//  ViewModel for plugin list - handles filtering, sorting, and business logic
//

import Combine
import SwiftUI

@MainActor
class PluginListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var searchText = ""
    @Published var selectedFormat: String?
    @Published var selectedStyle: String?
    @Published var selectedPublisher: String?
    @Published var sortOrder: SortOrder = .name

    // PAGINATION: For large plugin lists (10,000+)
    let pagination = PaginationManager<PluginItem>(threshold: 1000, defaultPageSize: 250)

    // MARK: - Input

    private(set) var plugins: [PluginItem]

    // MARK: - Enums

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case publisher = "Publisher"
        case type = "Type"
        case style = "Style"
    }

    // MARK: - Initialization

    init(plugins: [PluginItem] = []) {
        self.plugins = plugins
    }

    func updatePlugins(_ newPlugins: [PluginItem]) {
        self.plugins = newPlugins
    }

    // MARK: - Computed Properties

    var hasActiveFilters: Bool {
        sortOrder != .name || selectedFormat != nil || selectedStyle != nil || selectedPublisher != nil
    }

    var filteredPluginCount: Int {
        filteredAndSortedPlugins.count
    }

    var totalPluginCount: Int {
        plugins.count
    }

    var sortOrderBadge: String {
        sortOrder.rawValue
    }

    var uniquePublishers: [String] {
        Array(Set(plugins.map { $0.publisher })).sorted()
    }

    var uniqueFormats: [String] {
        Array(Set(plugins.map { $0.type.uppercased() })).sorted()
    }

    var uniqueStyles: [String] {
        Array(Set(plugins.map { $0.style }.filter { !$0.isEmpty })).sorted()
    }

    var formatCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for plugin in plugins {
            counts[plugin.type.uppercased(), default: 0] += 1
            if plugin.obsolete {
                counts["OBSLT", default: 0] += 1
            }
        }
        return counts
    }

    var styleCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for plugin in plugins {
            if !plugin.style.isEmpty {
                counts[plugin.style, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Filtering & Sorting

    var filteredAndSortedPlugins: [PluginItem] {
        var result = plugins

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.publisher.localizedCaseInsensitiveContains(searchText) ||
                plugin.style.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply format filter
        if let format = selectedFormat {
            if format == "OBSLT" {
                result = result.filter { $0.obsolete }
            } else {
                result = result.filter { $0.type.uppercased() == format }
            }
        }

        // Apply style filter
        if let style = selectedStyle {
            result = result.filter { $0.style == style }
        }

        // Apply publisher filter
        if let publisher = selectedPublisher {
            result = result.filter { $0.publisher == publisher }
        }

        // Apply sorting
        switch sortOrder {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .publisher:
            result.sort { $0.publisher.localizedCaseInsensitiveCompare($1.publisher) == .orderedAscending }
        case .type:
            result.sort { $0.type.localizedCaseInsensitiveCompare($1.type) == .orderedAscending }
        case .style:
            result.sort { $0.style.localizedCaseInsensitiveCompare($1.style) == .orderedAscending }
        }

        // Update pagination with filtered/sorted results
        pagination.updateItems(result)

        // Return paginated results if enabled, otherwise full results
        return pagination.isEnabled ? pagination.getCurrentPage() : result
    }

    var consolidatedPlugins: [ConsolidatedPlugin] {
        // Group plugins by name and publisher
        let grouped = Dictionary(grouping: filteredAndSortedPlugins) { plugin in
            "\(plugin.name)|\(plugin.publisher)"
        }

        return grouped.map { _, plugins in
            let first = plugins[0]
            let types = Array(Set(plugins.map { $0.type.uppercased() }))
                .sorted { ColorUtilities.formatSortOrder($0) < ColorUtilities.formatSortOrder($1) }
            let isObsolete = plugins.contains { $0.obsolete }

            return ConsolidatedPlugin(
                name: first.name,
                publisher: first.publisher,
                style: first.style,
                types: types,
                isObsolete: isObsolete,
                originalPlugins: plugins
            )
        }.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .publisher:
                return lhs.publisher.localizedCaseInsensitiveCompare(rhs.publisher) == .orderedAscending
            case .type:
                return (lhs.types.first ?? "") < (rhs.types.first ?? "")
            case .style:
                return lhs.style.localizedCaseInsensitiveCompare(rhs.style) == .orderedAscending
            }
        }
    }

    var dynamicFormatCounts: [(format: String, count: Int)] {
        let pluginsToCount = hasActiveFilters ? filteredAndSortedPlugins : plugins

        var counts: [String: Int] = [
            "AU": 0,
            "VST": 0,
            "VST3": 0,
            "AAX": 0,
            "CLAP": 0,
            "OBSLT": 0
        ]

        for plugin in pluginsToCount {
            let format = plugin.type.uppercased()
            if counts.keys.contains(format) {
                counts[format, default: 0] += 1
            } else if format == "LV2" {
                counts["LV2", default: 0] += 1
            }

            if plugin.obsolete {
                counts["OBSLT", default: 0] += 1
            }
        }

        return counts.map { (format: $0.key, count: $0.value) }
    }

    // MARK: - Actions

    func clearAllFilters() {
        sortOrder = .name
        selectedFormat = nil
        selectedStyle = nil
        selectedPublisher = nil
        searchText = ""
    }

    func toggleFormatFilter(_ format: String) {
        selectedFormat = selectedFormat == format ? nil : format
    }

    func toggleStyleFilter(_ style: String) {
        selectedStyle = selectedStyle == style ? nil : style
    }

    func togglePublisherFilter(_ publisher: String) {
        selectedPublisher = selectedPublisher == publisher ? nil : publisher
    }

    func resetSortOrder() {
        sortOrder = .name
    }
}

// MARK: - ConsolidatedPlugin Model

struct ConsolidatedPlugin: Identifiable {
    let id = UUID()
    let name: String
    let publisher: String
    let style: String
    let types: [String]
    let isObsolete: Bool
    let originalPlugins: [PluginItem]
}
