//
//  PluginListView.swift
//  PluginReporter (iPad)
//
//  iPad-optimized plugin list with larger screen layout
//

import SwiftUI

struct PluginListView: View {
    let plugins: [PluginItem]
    @State private var searchText = ""
    @State private var selectedFormat: String? = nil
    @State private var selectedStyle: String? = nil
    @State private var selectedPublisher: String? = nil
    @State private var sortOrder: SortOrder = .name
    @State private var showFilterSheet = false

    enum SortOrder {
        case name, publisher, type, style
    }

    // Consolidated plugin structure
    struct ConsolidatedPlugin: Identifiable {
        let id = UUID()
        let name: String
        let publisher: String
        let style: String
        let types: [String]
        let isObsolete: Bool
        let originalPlugins: [PluginItem]
    }

    var consolidatedPlugins: [ConsolidatedPlugin] {
        let grouped = Dictionary(grouping: filteredAndSortedPlugins) { plugin in
            "\(plugin.name)|\(plugin.publisher)"
        }

        return grouped.map { _, plugins in
            let first = plugins[0]
            let types = Array(Set(plugins.map { $0.type.uppercased() })).sorted { ColorUtilities.formatSortOrder($0) < ColorUtilities.formatSortOrder($1) }
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
                return lhs.types.first ?? "" < rhs.types.first ?? ""
            case .style:
                return lhs.style.localizedCaseInsensitiveCompare(rhs.style) == .orderedAscending
            }
        }
    }

    var filteredAndSortedPlugins: [PluginItem] {
        var result = plugins

        if !searchText.isEmpty {
            result = result.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.publisher.localizedCaseInsensitiveContains(searchText) ||
                plugin.style.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let format = selectedFormat {
            if format == "OBSLT" {
                result = result.filter { $0.obsolete }
            } else {
                result = result.filter { $0.type.uppercased() == format }
            }
        }

        if let style = selectedStyle {
            result = result.filter { $0.style == style }
        }

        if let publisher = selectedPublisher {
            result = result.filter { $0.publisher == publisher }
        }

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

        return result
    }

    var uniquePublishers: [String] {
        Array(Set(plugins.map { $0.publisher })).sorted()
    }

    var sortOrderBadge: String {
        switch sortOrder {
        case .name: return "Name"
        case .publisher: return "Publisher"
        case .type: return "Type"
        case .style: return "Style"
        }
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

    var body: some View {
        NavigationView {
            // iPad: Show sidebar with stats, main content with list
            HStack(spacing: 0) {
                // Left sidebar with stats
                VStack(spacing: 20) {
                    statsCard
                        .padding()

                    Spacer()
                }
                .frame(width: 350)
                .background(Color(.systemGroupedBackground))

                Divider()

                // Main content area
                VStack(spacing: 0) {
                    // Search and filters
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search", text: $searchText)

                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        // Active filters
                        if sortOrder != .name || selectedFormat != nil || selectedStyle != nil || selectedPublisher != nil {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if sortOrder != .name {
                                        SortBadge(title: sortOrderBadge, onRemove: { sortOrder = .name })
                                    }
                                    if let format = selectedFormat {
                                        FilterChip(title: format, onRemove: { selectedFormat = nil })
                                    }
                                    if let style = selectedStyle {
                                        FilterChip(title: style, onRemove: { selectedStyle = nil })
                                    }
                                    if let publisher = selectedPublisher {
                                        FilterChip(title: publisher, onRemove: { selectedPublisher = nil })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)

                    // Plugin List
                    if plugins.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "music.note.list")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                            Text("No Plugins Yet")
                                .font(.title)
                                .fontWeight(.semibold)
                            Text("Export plugins from your Mac app\nand import them here")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(consolidatedPlugins) { consolidated in
                                NavigationLink(destination: ConsolidatedPluginDetailView(consolidated: consolidated)) {
                                    ConsolidatedPluginRow(consolidated: consolidated)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Plugin Reporter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section(header:
                            HStack {
                                Text("Sort By")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if sortOrder != .name {
                                    Button(action: { sortOrder = .name }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        ) {
                            Button(action: { sortOrder = .name }) {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    if sortOrder == .name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            Button(action: { sortOrder = .publisher }) {
                                HStack {
                                    Text("Publisher")
                                    Spacer()
                                    if sortOrder == .publisher {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            Button(action: { sortOrder = .type }) {
                                HStack {
                                    Text("Type")
                                    Spacer()
                                    if sortOrder == .type {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            Button(action: { sortOrder = .style }) {
                                HStack {
                                    Text("Style")
                                    Spacer()
                                    if sortOrder == .style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        Section(header:
                            HStack {
                                Text("Filter by Type")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if selectedFormat != nil {
                                    Button(action: { selectedFormat = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        ) {
                            ForEach(uniqueFormats, id: \.self) { format in
                                Button(action: {
                                    selectedFormat = selectedFormat == format ? nil : format
                                }) {
                                    HStack {
                                        Text(format)
                                        Spacer()
                                        if let count = formatCounts[format] {
                                            Text("\(count)")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        if selectedFormat == format {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(ColorUtilities.colorForFormat(format))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Section(header:
                            HStack {
                                Text("Filter by Style")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if selectedStyle != nil {
                                    Button(action: { selectedStyle = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        ) {
                            ForEach(uniqueStyles, id: \.self) { style in
                                Button(action: {
                                    selectedStyle = selectedStyle == style ? nil : style
                                }) {
                                    HStack(spacing: 12) {
                                        Text(style)
                                        Spacer()
                                        if let count = styleCounts[style] {
                                            Text("\(count)")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        if selectedStyle == style {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }

                        Section(header:
                            HStack {
                                Text("Filter by Publisher")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if selectedPublisher != nil {
                                    Button(action: { selectedPublisher = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        ) {
                            ForEach(uniquePublishers, id: \.self) { publisher in
                                Button(action: {
                                    selectedPublisher = selectedPublisher == publisher ? nil : publisher
                                }) {
                                    HStack(spacing: 12) {
                                        Text(publisher)
                                        Spacer()
                                        if selectedPublisher == publisher {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive, action: {
                                sortOrder = .name
                                selectedFormat = nil
                                selectedStyle = nil
                                selectedPublisher = nil
                            }) {
                                Label("Clear All", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .imageScale(.large)
                    }
                }
            }
        }
        .navigationViewStyle(.columns)
    }

    private var hasActiveFilters: Bool {
        selectedFormat != nil || selectedStyle != nil || selectedPublisher != nil
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(hasActiveFilters ? "Filtered Plugins" : "Your Plugins")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("\(filteredAndSortedPlugins.count)")
                            .font(.headline)
                            .fontWeight(.bold)
                        if hasActiveFilters {
                            Text("of \(plugins.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "checkmark.icloud.fill")
                        .foregroundColor(hasActiveFilters ? .orange : .green)
                        .font(.title3)
                    Text(hasActiveFilters ? "Filtered" : "Ready")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(spacing: 8) {
                let counts = dynamicFormatCounts
                ForEach(counts.sorted(by: { ColorUtilities.formatSortOrder($0.format) < ColorUtilities.formatSortOrder($1.format) }), id: \.format) { item in
                    MiniBarRow(
                        label: item.format,
                        count: item.count,
                        maxCount: counts.max(by: { $0.count < $1.count })?.count ?? 1,
                        color: ColorUtilities.colorForFormat(item.format),
                        isSelected: selectedFormat == item.format
                    )
                    .onTapGesture {
                        selectedFormat = selectedFormat == item.format ? nil : item.format
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private var dynamicFormatCounts: [(format: String, count: Int)] {
        let pluginsToCount = selectedFormat != nil || selectedStyle != nil || selectedPublisher != nil ? filteredAndSortedPlugins : plugins

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
}
