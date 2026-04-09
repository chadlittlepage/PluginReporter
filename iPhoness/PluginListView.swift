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
    @State private var selectedStarRatings: Set<Int> = []
    @State private var selectedStyle: String?
    @State private var selectedPublisher: String?
    @State private var sortOrder: SortOrder = .name
    @State private var showFilterSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Screenshot Viewer (matches macOS design)
    @State private var selectedPluginForViewer: PluginItem?
    @State private var showPluginImage = false  // Toggle between chart and screenshot

    // SPEED: Cached computed values to avoid recalculation
    @State private var cachedConsolidated: [ConsolidatedPlugin] = []
    @State private var cachedSectioned: [(key: String, plugins: [ConsolidatedPlugin])] = []
    @State private var cachedFilteredSorted: [PluginItem] = []
    @State private var cachedUniquePublishers: [String] = []
    @State private var cachedUniqueFormats: [String] = []
    @State private var cachedUniqueStyles: [String] = []
    @State private var cachedFormatCounts: [String: Int] = [:]
    @State private var cachedStyleCounts: [String: Int] = [:]

    // PAGINATION: For large plugin lists (10,000+)
    @StateObject private var pagination = PaginationManager<ConsolidatedPlugin>(threshold: 1000, defaultPageSize: 250)

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

        // Apply star rating filter
        if !selectedStarRatings.isEmpty {
            let ratingsManager = RatingsManager.shared
            result = result.filter { plugin in
                let rating = ratingsManager.getRating(for: plugin.path)
                return selectedStarRatings.contains(rating)
            }
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

        // Update pagination with consolidated results
        pagination.updateItems(consolidated)

        // Get paginated or full results
        cachedConsolidated = pagination.isEnabled ? pagination.getCurrentPage() : consolidated
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
        // Break up complex ternary to help compiler
        if appearance == "space" {
            // Space appearance: 3% more grey than normal spaceDarker
            return Color(red: 18/255, green: 18/255, blue: 18/255)
        } else if appearance == "dark" {
            return darkDarker
        } else if appearance == "light" {
            return lightDarker
        } else {
            return Color(UIColor.systemGray6)
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Stats Card OR Screenshot Viewer (toggle between them - matches macOS)
            if showPluginImage {
                screenshotViewWithToggle
            } else {
                statsCard
                    .padding(.top, 0)
                    .padding(.bottom, 0)
            }

            // Active Sort and Filters
            if sortOrder != .name || hasActiveFilters {
                activeFiltersView
            }

            // Plugin List
            pluginListContent
        }
    }

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort badge with X to reset to Name
                if sortOrder != .name {
                    SortBadge(title: sortOrderBadge, onRemove: { sortOrder = .name })
                }

                ForEach(Array(selectedFormats).sorted(by: { ColorUtilities.formatSortOrder($0) < ColorUtilities.formatSortOrder($1) }), id: \.self) { format in
                    FilterChip(title: format, onRemove: { selectedFormats.remove(format) }, color: ColorUtilities.colorForFormat(format))
                }
                ForEach(Array(selectedStarRatings).sorted(by: >), id: \.self) { rating in
                    FilterChip(title: "\(rating)★", onRemove: { selectedStarRatings.remove(rating) }, color: .yellow)
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

    @ViewBuilder
    private var pluginListContent: some View {
        if plugins.isEmpty {
            emptyStateView
        } else {
            pluginListView
        }
    }

    private var emptyStateView: some View {
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
    }

    private var pluginListView: some View {
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
                                .onTapGesture {
                                    // Populate viewer with first plugin when row is tapped
                                    if let firstPlugin = consolidated.originalPlugins.first {
                                        selectedPluginForViewer = firstPlugin
                                    }
                                }
                            }
                        }
                        .id(section.key)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToSection"))) { notification in
                    if let section = notification.object as? String {
                        AnimationHelper.withAnimation(reduceMotion) {
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

    private var bottomSafeAreaContent: some View {
        Group {
            if pagination.isEnabled {
                iOSPaginationControls(pagination: pagination)
            }
        }
    }

    private var topSafeAreaContent: some View {
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
            searchBarView
        }
    }

    private var searchBarView: some View {
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

    var body: some View {
        NavigationStack {
            contentWithModifiers
        }
    }

    private var contentWithModifiers: some View {
        mainContent
            .background(customBackgroundColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomSafeAreaContent
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                topSafeAreaContent
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
                                    HStack(spacing: 12) {
                                        Text(format)
                                            .font(.system(size: 15))

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
                                Text("Filter by Stars")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !selectedStarRatings.isEmpty {
                                    Button(action: { selectedStarRatings.removeAll() }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        ) {
                            Button(action: {
                                if selectedStarRatings.contains(5) {
                                    selectedStarRatings.remove(5)
                                } else {
                                    selectedStarRatings.insert(5)
                                }
                            }) {
                                HStack {
                                    Text("⭐️⭐️⭐️⭐️⭐️")
                                        .scaleEffect(0.8)
                                    Spacer()
                                    if selectedStarRatings.contains(5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }

                            Button(action: {
                                if selectedStarRatings.contains(4) {
                                    selectedStarRatings.remove(4)
                                } else {
                                    selectedStarRatings.insert(4)
                                }
                            }) {
                                HStack {
                                    Text("⭐️⭐️⭐️⭐️")
                                        .scaleEffect(0.8)
                                    Spacer()
                                    if selectedStarRatings.contains(4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }

                            Button(action: {
                                if selectedStarRatings.contains(3) {
                                    selectedStarRatings.remove(3)
                                } else {
                                    selectedStarRatings.insert(3)
                                }
                            }) {
                                HStack {
                                    Text("⭐️⭐️⭐️")
                                        .scaleEffect(0.8)
                                    Spacer()
                                    if selectedStarRatings.contains(3) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }

                            Button(action: {
                                if selectedStarRatings.contains(2) {
                                    selectedStarRatings.remove(2)
                                } else {
                                    selectedStarRatings.insert(2)
                                }
                            }) {
                                HStack {
                                    Text("⭐️⭐️")
                                        .scaleEffect(0.8)
                                    Spacer()
                                    if selectedStarRatings.contains(2) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }

                            Button(action: {
                                if selectedStarRatings.contains(1) {
                                    selectedStarRatings.remove(1)
                                } else {
                                    selectedStarRatings.insert(1)
                                }
                            }) {
                                HStack {
                                    Text("⭐️")
                                        .scaleEffect(0.8)
                                    Spacer()
                                    if selectedStarRatings.contains(1) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yellow)
                                    }
                                }
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
                                selectedStarRatings.removeAll()
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
            .onChange(of: selectedStarRatings) { _ in computeFilteredAndSorted() }
            .onChange(of: selectedStyle) { _ in computeFilteredAndSorted() }
            .onChange(of: selectedPublisher) { _ in computeFilteredAndSorted() }
            .onChange(of: sortOrder) { _ in computeFilteredAndSorted() }
            .task(id: plugins.count) {
                // Recompute when plugins change (much faster than .id() view recreation)
                computeMetadata()
                computeFilteredAndSorted()
                filteredPluginsForExport = filteredAndSortedPlugins
            }
            .transaction { transaction in
                transaction.animation = nil // Disable all List/Form animations
            }
    }

    private var hasActiveFilters: Bool {
        !selectedFormats.isEmpty || !selectedStarRatings.isEmpty || selectedStyle != nil || selectedPublisher != nil
    }

    @ViewBuilder
    private var screenshotViewWithToggle: some View {
        VStack(spacing: 0) {
            // Header with toggle button (matches macOS design)
            HStack {
                // Toggle button on the left
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        withAnimation {
                            showPluginImage.toggle()
                        }
                    }) {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    Text("Chart")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 14)

                Spacer()

                // Plugin name in center
                if let plugin = selectedPluginForViewer {
                    VStack(alignment: .center, spacing: 4) {
                        Text(plugin.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(plugin.publisher)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Select a plugin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // Screenshot content
            if let plugin = selectedPluginForViewer {
                let imageUrlString = plugin.screenshotUrl ?? plugin.thumbnailUrl

                if let imageUrlString = imageUrlString,
                   let imageURL = URL(string: imageUrlString) {
                    let pluginKey = "\(plugin.name)|\(plugin.publisher)"
                    ScrollView {
                        CachedAsyncImage(url: imageURL, pluginKey: pluginKey) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(minHeight: 200, maxHeight: 400)
                    .onAppear {
                        print("📸 [iOS VIEWER] Plugin: \(plugin.name)")
                        print("📸 [iOS VIEWER] screenshotUrl: \(plugin.screenshotUrl ?? "nil")")
                        print("📸 [iOS VIEWER] thumbnailUrl: \(plugin.thumbnailUrl ?? "nil")")
                        print("📸 [iOS VIEWER] Valid URL found: \(imageURL.absoluteString)")
                    }
                } else {
                    // No screenshot URL available
                    VStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No screenshot available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        print("❌ [iOS VIEWER] Plugin: \(plugin.name)")
                        print("❌ [iOS VIEWER] screenshotUrl: \(plugin.screenshotUrl ?? "nil")")
                        print("❌ [iOS VIEWER] thumbnailUrl: \(plugin.thumbnailUrl ?? "nil")")
                        print("❌ [iOS VIEWER] No valid URL found!")
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Tap a plugin to view screenshot")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .background(statsCardBackgroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statsCard: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                // Toggle button at top left (matches macOS design)
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: {
                        withAnimation {
                            showPluginImage.toggle()
                        }
                    }) {
                        Image(systemName: "photo")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    Text("Image")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 4)

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
//
//  ImageCacheManager.swift
//  Plugin Reporter (Shared)
//
//  Persistent disk-based image cache for plugin screenshots
//

import Foundation
import SwiftUI

/// Thread-safe persistent image cache manager
/// Saves downloaded images to disk and serves from cache on subsequent loads
@MainActor
class ImageCacheManager {
    static let shared = ImageCacheManager()

    // MARK: - Properties

    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private var memoryCache = NSCache<NSString, UIImage>()  // Fast memory cache

    // MARK: - Initialization

    private init() {
        // Create cache directory in app's cache folder
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("PluginScreenshots", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache (50 MB limit)
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        memoryCache.countLimit = 100  // Max 100 images in memory

        print("📦 ImageCache initialized at: \(cacheDirectory.path)")
    }

    // MARK: - Public API

    /// Get image from cache or download if needed
    func getImage(from url: URL, pluginKey: String) async throws -> PlatformImage {
        // 1. Check memory cache first (fastest)
        let cacheKey = NSString(string: pluginKey)
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            print("🎯 Memory cache hit: \(pluginKey)")
            return cachedImage
        }

        // 2. Check disk cache (persistent)
        if let diskImage = loadFromDisk(pluginKey: pluginKey) {
            print("💾 Disk cache hit: \(pluginKey)")
            // Store in memory cache for faster access next time
            memoryCache.setObject(diskImage, forKey: cacheKey)
            return diskImage
        }

        // 3. Download from network
        print("⬇️ Downloading image: \(pluginKey) from \(url.absoluteString)")
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = PlatformImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        // 4. Save to both caches
        saveToDisk(image: image, pluginKey: pluginKey)
        memoryCache.setObject(image, forKey: cacheKey)

        print("✅ Downloaded and cached: \(pluginKey)")
        return image
    }

    /// Clear all cached images (memory + disk)
    func clearCache() {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        print("🗑️ Image cache cleared")
    }

    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    // MARK: - Private Helpers

    private func loadFromDisk(pluginKey: String) -> PlatformImage? {
        let fileURL = cacheDirectory.appendingPathComponent(sanitizedFilename(from: pluginKey))

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return PlatformImage(data: data)
    }

    private func saveToDisk(image: PlatformImage, pluginKey: String) {
        let fileURL = cacheDirectory.appendingPathComponent(sanitizedFilename(from: pluginKey))

        #if os(macOS)
        guard let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }
        #else
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        #endif

        try? jpegData.write(to: fileURL, options: .atomic)
    }

    private func sanitizedFilename(from pluginKey: String) -> String {
        // Convert plugin key to safe filename
        let sanitized = pluginKey
            .replacingOccurrences(of: "|", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(sanitized).jpg"
    }
}

// MARK: - Platform Compatibility

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif
//
//  CachedAsyncImage.swift
//  Plugin Reporter (Shared)
//
//  Custom AsyncImage that uses persistent disk cache
//

import SwiftUI

/// Drop-in replacement for AsyncImage with persistent caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let pluginKey: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: PlatformImage?
    @State private var isLoading = false
    @State private var loadError: Error?

    var body: some View {
        Group {
            if let image = image {
                #if os(macOS)
                content(Image(nsImage: image))
                #else
                content(Image(uiImage: image))
                #endif
            } else if isLoading {
                placeholder()
            } else if loadError != nil {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else { return }

        isLoading = true
        loadError = nil

        do {
            let loadedImage = try await ImageCacheManager.shared.getImage(from: url, pluginKey: pluginKey)
            self.image = loadedImage
            self.isLoading = false
        } catch {
            print("❌ Failed to load image: \(error.localizedDescription)")
            self.loadError = error
            self.isLoading = false
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Simple initializer with default placeholder
    init(url: URL?, pluginKey: String) {
        self.url = url
        self.pluginKey = pluginKey
        self.content = { $0 }
        self.placeholder = { ProgressView() }
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Initializer with custom content transform
    init(url: URL?, pluginKey: String, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.pluginKey = pluginKey
        self.content = content
        self.placeholder = { ProgressView() }
    }
}

extension CachedAsyncImage where Content == Image {
    /// Initializer with custom placeholder
    init(url: URL?, pluginKey: String, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.pluginKey = pluginKey
        self.content = { $0 }
        self.placeholder = placeholder
    }
}
