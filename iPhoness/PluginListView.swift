//
//  PluginListView.swift
//  PluginReporter (iOS)
//
//  Main plugin list view with filtering, sorting, and search
//

import SwiftUI

struct PluginListView: View {
    let plugins: [PluginItem]
    @Binding var filteredPluginsForExport: [PluginItem]
    @State private var searchText = ""
    @State private var selectedFormats: Set<String> = []
    @State private var selectedStyle: String? = nil
    @State private var selectedPublisher: String? = nil
    @State private var sortOrder: SortOrder = .name
    @State private var showFilterSheet = false

    // SPEED: Cached computed values to avoid recalculation
    @State private var cachedConsolidated: [ConsolidatedPlugin] = []
    @State private var cachedSectioned: [(key: String, plugins: [ConsolidatedPlugin])] = []
    @State private var cachedFilteredSorted: [PluginItem] = []
    @State private var cachedUniquePublishers: [String] = []
    @State private var cachedUniqueFormats: [String] = []
    @State private var cachedUniqueStyles: [String] = []
    @State private var cachedFormatCounts: [String: Int] = [:]
    @State private var cachedStyleCounts: [String: Int] = [:]

    enum SortOrder {
        case name, publisher, type, style
    }

    // Consolidated plugin structure
    struct ConsolidatedPlugin: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let publisher: String
        let style: String
        let types: [String]
        let isObsolete: Bool
        let originalPlugins: [PluginItem]

        // Hashable conformance
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: ConsolidatedPlugin, rhs: ConsolidatedPlugin) -> Bool {
            lhs.id == rhs.id
        }
    }

    // SPEED: Return cached value directly
    var consolidatedPlugins: [ConsolidatedPlugin] {
        cachedConsolidated
    }

    // SPEED: Return cached value directly
    var sectionedPlugins: [(key: String, plugins: [ConsolidatedPlugin])] {
        cachedSectioned
    }

    // SPEED: Return cached value directly
    var filteredAndSortedPlugins: [PluginItem] {
        cachedFilteredSorted
    }

    // SPEED: Compute filter/sort in one pass
    private func computeFilteredAndSorted() {
        var result = plugins

        // Apply search filter - search all fields
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { plugin in
                plugin.name.lowercased().contains(searchLower) ||
                plugin.publisher.lowercased().contains(searchLower) ||
                plugin.style.lowercased().contains(searchLower) ||
                plugin.architectures.lowercased().contains(searchLower) ||
                plugin.version.lowercased().contains(searchLower) ||
                plugin.runtimeRequirement.lowercased().contains(searchLower) ||
                plugin.type.lowercased() == searchLower  // Exact match for type to avoid VST matching VST3
            }
        }

        // Apply format filter - multi-select with OR logic
        if !selectedFormats.isEmpty {
            result = result.filter { plugin in
                for format in selectedFormats {
                    if format == "OBSLT" {
                        if plugin.obsolete { return true }
                    } else {
                        if plugin.type.uppercased() == format { return true }
                    }
                }
                return false
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

        cachedFilteredSorted = result
        computeConsolidated()
    }

    // SPEED: Compute consolidated plugins
    private func computeConsolidated() {
        let grouped = Dictionary(grouping: cachedFilteredSorted) { plugin in
            "\(plugin.name)|\(plugin.publisher)"
        }

        let consolidated = grouped.map { _, plugins in
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

        cachedConsolidated = consolidated
        computeSectioned()
    }

    // SPEED: Compute sectioned plugins
    private func computeSectioned() {
        let grouped = Dictionary(grouping: cachedConsolidated) { plugin -> String in
            let firstChar = plugin.name.prefix(1).uppercased()
            if firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil {
                return firstChar
            } else {
                return "#"
            }
        }

        cachedSectioned = grouped.map { (key: $0.key, plugins: $0.value) }
            .sorted { $0.key < $1.key }
    }

    // SPEED: Return cached values instantly
    var uniquePublishers: [String] {
        cachedUniquePublishers
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
        cachedUniqueFormats
    }

    var uniqueStyles: [String] {
        cachedUniqueStyles
    }

    var formatCounts: [String: Int] {
        cachedFormatCounts
    }

    var styleCounts: [String: Int] {
        cachedStyleCounts
    }

    // SPEED: Compute all metadata once when plugins change
    private func computeMetadata() {
        // Publishers
        cachedUniquePublishers = Array(Set(plugins.map { $0.publisher })).sorted()

        // Formats
        var types = Set(plugins.map { $0.type.uppercased() })
        types.insert("OBSLT")
        let order = ["AU", "VST", "VST3", "AAX", "CLAP", "LV2", "OBSLT"]
        cachedUniqueFormats = Array(types).sorted { format1, format2 in
            let index1 = order.firstIndex(of: format1) ?? Int.max
            let index2 = order.firstIndex(of: format2) ?? Int.max
            return index1 < index2
        }

        // Styles
        cachedUniqueStyles = Array(Set(plugins.map { $0.style }.filter { !$0.isEmpty })).sorted()

        // Format counts
        var fCounts: [String: Int] = [:]
        for plugin in plugins {
            fCounts[plugin.type.uppercased(), default: 0] += 1
            if plugin.obsolete {
                fCounts["OBSLT", default: 0] += 1
            }
        }
        cachedFormatCounts = fCounts

        // Style counts
        var sCounts: [String: Int] = [:]
        for plugin in plugins {
            if !plugin.style.isEmpty {
                sCounts[plugin.style, default: 0] += 1
            }
        }
        cachedStyleCounts = sCounts
    }

    @AppStorage("appearance") private var appearance: String = "space"

    // Pre-computed color constants for instant switching
    private let spaceBackground = Color.black
    private let spaceDarker = Color(red: 13/255, green: 13/255, blue: 13/255)
    private let darkBackground = Color(red: 28/255, green: 28/255, blue: 30/255)
    private let darkDarker = Color(red: 24/255, green: 24/255, blue: 26/255)
    private let lightBackground = Color(red: 242/255, green: 242/255, blue: 247/255)
    private let lightDarker = Color(red: 230/255, green: 230/255, blue: 235/255)

    var customBackgroundColor: Color {
        appearance == "space" ? spaceBackground : appearance == "dark" ? darkBackground : appearance == "light" ? lightBackground : Color(UIColor.systemBackground)
    }

    var statsCardBackgroundColor: Color {
        customBackgroundColor
    }

    var searchBarBackgroundColor: Color {
        appearance == "space" ? spaceDarker : appearance == "dark" ? darkDarker : appearance == "light" ? lightDarker : Color(UIColor.systemGray6)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Card
                statsCard
                    .padding(.top, 0)
                    .padding(.bottom, 0)

                // Active Sort and Filters
                if sortOrder != .name || hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Sort badge with X to reset to Name
                            if sortOrder != .name {
                                SortBadge(title: sortOrderBadge, onRemove: { sortOrder = .name })
                            }

                            ForEach(Array(selectedFormats), id: \.self) { format in
                                FilterChip(title: format, onRemove: { selectedFormats.remove(format) })
                            }
                            if let style = selectedStyle {
                                FilterChip(title: style, onRemove: { selectedStyle = nil })
                            }
                            if let publisher = selectedPublisher {
                                FilterChip(title: publisher, onRemove: { selectedPublisher = nil })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                // Plugin List
                if plugins.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Plugins Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Export plugins from your Mac app\nand import them here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ZStack(alignment: .trailing) {
                        ScrollViewReader { proxy in
                            List {
                                ForEach(sectionedPlugins, id: \.key) { section in
                                    Section(header: EmptyView()) {
                                        ForEach(section.plugins) { consolidated in
                                            NavigationLink(value: consolidated) {
                                                ConsolidatedPluginRow(consolidated: consolidated)
                                                    .equatable()
                                            }
                                            .listRowBackground(Color.clear)
                                        }
                                    }
                                    .id(section.key)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToSection"))) { notification in
                                if let section = notification.object as? String {
                                    withAnimation {
                                        proxy.scrollTo(section, anchor: .top)
                                    }
                                }
                            }
                        }

                        // Custom section index
                        SectionIndexView(sections: sectionedPlugins.map { $0.key })
                            .padding(.trailing, 4)
                    }
                }
            }
            .background(customBackgroundColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 10) {
                    // Title - level with navigation bar
                    HStack {
                        Text("Plugin Reporter")
                            .font(.system(size: Constants.Typography.titleSize, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, Constants.Layout.standardPadding)
                    .padding(.top, -45)

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search", text: $searchText)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(10)
                    .background(searchBarBackgroundColor)
                    .cornerRadius(10)
                    .padding(.horizontal, Constants.Layout.standardPadding)
                    .padding(.bottom, 2)
                }
            }
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
                                if !selectedFormats.isEmpty {
                                    Button(action: { selectedFormats.removeAll() }) {
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
                                    if selectedFormats.contains(format) {
                                        selectedFormats.remove(format)
                                    } else {
                                        selectedFormats.insert(format)
                                    }
                                }) {
                                    HStack {
                                        Text(format)
                                        Spacer()
                                        if let count = formatCounts[format] {
                                            Text("\(count)")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        if selectedFormats.contains(format) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(ColorUtilities.colorForFormat(format))
                                        }
                                    }
                                    .frame(width: Constants.Layout.menuMinWidth, alignment: .leading)
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
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                        Spacer(minLength: 20)
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
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                        Spacer(minLength: 20)
                                        if selectedPublisher == publisher {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive, action: {
                                sortOrder = .name
                                selectedFormats.removeAll()
                                selectedStyle = nil
                                selectedPublisher = nil
                            }) {
                                Label("Clear All", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .imageScale(.large)
                            .accessibilityLabel("Filter and sort options")
                    }
                }
            }
            .navigationDestination(for: ConsolidatedPlugin.self) { consolidated in
                ConsolidatedPluginDetailView(consolidated: consolidated)
            }
            .onChange(of: filteredAndSortedPlugins) { newValue in
                filteredPluginsForExport = newValue
            }
            .onChange(of: searchText) { _ in computeFilteredAndSorted() }
            .onChange(of: selectedFormats) { _ in computeFilteredAndSorted() }
            .onChange(of: selectedStyle) { _ in computeFilteredAndSorted() }
            .onChange(of: selectedPublisher) { _ in computeFilteredAndSorted() }
            .onChange(of: sortOrder) { _ in computeFilteredAndSorted() }
            .task(id: plugins.count) {
                // Recompute when plugins change (much faster than .id() view recreation)
                computeMetadata()
                computeFilteredAndSorted()
                filteredPluginsForExport = filteredAndSortedPlugins
            }
        }
    }

    private var hasActiveFilters: Bool {
        !selectedFormats.isEmpty || selectedStyle != nil || selectedPublisher != nil
    }

    private var statsCard: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(hasActiveFilters ? "Filtered Plugins" : "Plugins")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(filteredAndSortedPlugins.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        if hasActiveFilters {
                            Text("of \(plugins.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "checkmark.icloud.fill")
                        .foregroundColor(hasActiveFilters ? .orange : .green)
                        .font(.title3)
                        .padding(.top, 2)
                    Text(hasActiveFilters ? "Filtered" : "Ready")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(spacing: 5) {
                let counts = dynamicFormatCounts
                ForEach(counts.sorted(by: { ColorUtilities.formatSortOrder($0.format) < ColorUtilities.formatSortOrder($1.format) }), id: \.format) { item in
                    MiniBarRow(
                        label: item.format,
                        count: item.count,
                        maxCount: counts.max(by: { $0.count < $1.count })?.count ?? 1,
                        color: ColorUtilities.colorForFormat(item.format),
                        isSelected: selectedFormats.contains(item.format)
                    )
                    .onTapGesture {
                        if selectedFormats.contains(item.format) {
                            selectedFormats.remove(item.format)
                        } else {
                            selectedFormats.insert(item.format)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(statsCardBackgroundColor)
        .edgesIgnoringSafeArea(.horizontal)
    }

    private var dynamicFormatCounts: [(format: String, count: Int)] {
        let pluginsToCount = hasActiveFilters ? filteredAndSortedPlugins : plugins

        // Initialize required formats with 0
        var counts: [String: Int] = [
            "AU": 0,
            "VST": 0,
            "VST3": 0,
            "AAX": 0,
            "CLAP": 0,
            "OBSLT": 0
        ]

        for plugin in pluginsToCount {
            // Count by actual type, not obsolete status
            let format = plugin.type.uppercased()
            if counts.keys.contains(format) {
                counts[format, default: 0] += 1
            } else if format == "LV2" {
                // Only add LV2 if it exists
                counts["LV2", default: 0] += 1
            }

            // Also count obsolete separately
            if plugin.obsolete {
                counts["OBSLT", default: 0] += 1
            }
        }

        return counts.map { (format: $0.key, count: $0.value) }
    }

}

// MARK: - Section Index View

struct SectionIndexView: View {
    let sections: [String]
    @State private var selectedSection: String?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(sections, id: \.self) { section in
                Text(section)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        scrollToSection(section)
                    }
            }
        }
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    private func scrollToSection(_ section: String) {
        // This requires using ScrollViewReader or UITableView
        // For now, we'll use a notification approach
        NotificationCenter.default.post(name: NSNotification.Name("ScrollToSection"), object: section)
    }
}

