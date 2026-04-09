//
//  PluginDetailPanel.swift
//  PluginReporter
//
//  Collapsible right-hand detail panel for viewing and editing plugin info
//

import SwiftUI

// MARK: - Specs Tab View (prevents redraw on keyboard navigation)
struct SpecsTabView: View {
    let plugin: PluginItem
    @State private var currentPluginID: UUID?
    @State private var cachedContent: AnyView?
    @State private var enrichedPlugin: PluginItem
    @State private var isLoadingExtendedData = false
    @StateObject private var enrichmentService = PluginEnrichmentService.shared

    init(plugin: PluginItem) {
        self.plugin = plugin
        self._enrichedPlugin = State(initialValue: plugin)
    }

    var body: some View {
        Group {
            if let cachedContent = cachedContent {
                cachedContent
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SpecsSectionRenderer(plugin: enrichedPlugin)

                        // Loading indicator for extended data
                        if isLoadingExtendedData {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading presets and chains...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            loadExtendedDataIfNeeded()
            renderContent()
        }
        .onChange(of: plugin.id) { newID in
            if currentPluginID != newID {
                currentPluginID = newID
                enrichedPlugin = plugin
                loadExtendedDataIfNeeded()
                renderContent()
            }
        }
    }

    private func loadExtendedDataIfNeeded() {
        // Only load if we don't have presets/chains yet
        guard enrichedPlugin.enrichedPresets == nil else {
            print("✅ Extended data already loaded")
            return
        }

        isLoadingExtendedData = true
        Task {
            // Create a mutable copy to pass to the async function
            var pluginCopy = enrichedPlugin
            await enrichmentService.lazyLoadExtendedData(for: &pluginCopy)

            await MainActor.run {
                enrichedPlugin = pluginCopy
                isLoadingExtendedData = false
                renderContent()
            }
        }
    }

    private func renderContent() {
        let content = ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SpecsSectionRenderer(plugin: enrichedPlugin)
            }
            .padding(16)
        }
        cachedContent = AnyView(content)
    }
}

struct SpecsSectionRenderer: View {
    let plugin: PluginItem
    @EnvironmentObject private var metadataManager: MetadataManager

    var body: some View {
        // Inline the specs content directly to avoid type erasure issues
        Group {
            specsContent
        }
    }

    private var specsContent: some View {
        Group {
            // DESCRIPTION section (from Firebase enrichment)
            if let description = plugin.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                divider
            }

            // TECHNICAL SPECIFICATIONS section (specs text only)
            if let specs = plugin.specs, !specs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TECHNICAL SPECIFICATIONS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(specs)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                divider
            }

            // Feature Tags (from Firebase)
            if let tags = plugin.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                divider
            }

            // GUI COLORS section
            if let colorScheme = plugin.colorScheme, !colorScheme.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GUI COLORS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        ForEach(colorScheme.components(separatedBy: " ").filter { !$0.isEmpty }, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorFromName(color))
                                    .frame(width: 12, height: 12)
                                Text(color.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                divider
            }

            // PRESETS section (lazy-loaded)
            if let presets = plugin.enrichedPresets, !presets.isEmpty {
                let uniquePresets = removeDuplicatePresets(presets)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PRESETS")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(uniquePresets.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(uniquePresets) { preset in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name ?? "Untitled Preset")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)

                                if let description = preset.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 6) {
                                    if let genre = preset.genre, !genre.isEmpty {
                                        Text(genre)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                    if let category = preset.category, !category.isEmpty {
                                        Text(category)
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                        }

                        if uniquePresets.count > 10 {
                            Text("+ \(uniquePresets.count - 10) more presets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.top, 4)
                        }
                    }
                }
                divider
            }

            // FAMOUS USES section (lazy-loaded)
            if let famousUses = plugin.famousUses, !famousUses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("FAMOUS USES")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(famousUses.prefix(5), id: \.id) { use in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(use.song)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    if let year = use.year {
                                        Text("(\(year))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text("by \(use.artist)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let engineer = use.engineer {
                                    Text("Engineer: \(engineer)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(8)
                        }

                        if famousUses.count > 5 {
                            Text("+ \(famousUses.count - 5) more uses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.top, 4)
                        }
                    }
                }
                divider
            }

            // PLUGIN CHAINS section (lazy-loaded)
            if let chains = plugin.chains, !chains.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PLUGIN CHAINS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chains.prefix(3), id: \.id) { chain in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chain.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)

                                if let description = chain.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                if let genre = chain.genre {
                                    Text(genre)
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(8)
                        }

                        if chains.count > 3 {
                            Text("+ \(chains.count - 3) more chains")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.top, 4)
                        }
                    }
                }
                divider
            }

            // Placeholder
            if plugin.tags?.isEmpty != false && plugin.description == nil && plugin.enrichedPresets == nil {
                VStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Specifications will appear here once this plugin is enriched from Firebase")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 1)
    }

    private func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "brown": return .brown
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }

    /// Remove duplicate presets based on name (case-insensitive)
    private func removeDuplicatePresets(_ presets: [EnrichedPreset]) -> [EnrichedPreset] {
        var seen = Set<String>()
        var unique: [EnrichedPreset] = []

        for preset in presets {
            let presetName = (preset.name ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            if !presetName.isEmpty && !seen.contains(presetName) {
                seen.insert(presetName)
                unique.append(preset)
            }
        }

        return unique
    }
}

enum DetailTab: String, CaseIterable {
    case metadata = "Metadata"
    case specs = "Specs"
    case license = "License"

    var icon: String {
        switch self {
        case .metadata: return "slider.horizontal.3"
        case .specs: return "gauge.with.dots.needle.67percent"
        case .license: return "key.fill"
        }
    }
}

struct PluginDetailPanel: View {
    let plugin: PluginItem?
    @Binding var isVisible: Bool
    @Binding var selectedTab: DetailTab

    @StateObject private var metadataManager = MetadataManager.shared
    @StateObject private var tagsManager = TagsManager.shared
    @StateObject private var ratingsManager = RatingsManager.shared
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var enrichmentService = PluginEnrichmentService.shared
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    @State private var newTagText = ""

    // Editable metadata fields
    @State private var editedName = ""
    @State private var editedPublisher = ""
    @State private var editedVersion = ""
    @State private var editedStyle = ""
    @State private var editedType = ""
    @State private var editedArchitecture = ""
    @State private var editedTrack = ""

    // Flag to prevent saving during initialization
    @State private var isInitializing = false

    // Track the current plugin to prevent unnecessary re-initialization
    @State private var currentPluginID: UUID?

    // Reset confirmation dialog
    @State private var showResetConfirmation = false

    // Tab selection for Metadata vs License (now controlled externally via binding)

    private let panelWidth: CGFloat = 350

    private var backgroundColor: Color {
        #if os(macOS)
        return prefs.appearance == .space ? Color.black : Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }

    private var secondaryTextColor: Color {
        colorScheme == .light ? Color.black.opacity(0.55) : .secondary
    }

    @ViewBuilder
    private var divider: some View {
        #if os(macOS)
        if prefs.appearance == .space {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        } else if colorScheme == .light {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(height: 1)
        } else {
            Divider()
        }
        #else
        Divider()
        #endif
    }

    var body: some View {
        if isVisible, let plugin = plugin {
            VStack(alignment: .leading, spacing: 0) {
                // Tab Buttons
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12))
                                    Text(tab.rawValue)
                                        .font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
                                #if os(macOS)
                                .background(selectedTab == tab ? Color(red: 16/255, green: 73/255, blue: 135/255) : Color(nsColor: .controlBackgroundColor))
                                #else
                                .background(selectedTab == tab ? Color(red: 16/255, green: 73/255, blue: 135/255) : Color(.systemGray6))
                                #endif
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 17)
                    .padding(.bottom, 12)
                }

                divider

                // Header with plugin name
                headerSection(plugin: plugin)

                divider

                // Content based on selected tab
                Group {
                    if selectedTab == .metadata {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Editable Metadata Section
                                editableMetadataSection(plugin: plugin)

                                divider

                                // Info Section (Read-Only)
                                infoSection(plugin: plugin)

                                divider

                                // Tags Section
                                tagsSection(plugin: plugin)

                                divider

                                // Suggested Tags Section
                                suggestedTagsSection(plugin: plugin)

                                divider

                                // Rating Section
                                ratingSection(plugin: plugin)

                                divider

                                // Notes Section
                                notesSection(plugin: plugin)
                            }
                            .padding(16)
                        }
                        .onAppear {
                            // Initialize editable fields when panel appears
                            if currentPluginID != plugin.id {
                                currentPluginID = plugin.id
                                initializeFields(for: plugin)
                            }
                        }
                        .onChange(of: plugin.id) { newID in
                            // Only refresh fields when plugin selection actually changes
                            if currentPluginID != newID {
                                currentPluginID = newID
                                initializeFields(for: plugin)
                            }
                        }
                    } else if selectedTab == .specs {
                        // Specs tab - Full technical specifications
                        SpecsTabView(plugin: plugin)
                    } else {
                        // License tab (macOS only)
                        #if os(macOS)
                        PluginLicensePanel(plugin: plugin)
                        #else
                        Text("License management not available on iOS")
                            .foregroundColor(.secondary)
                            .padding()
                        #endif
                    }
                }
            }
            .frame(width: panelWidth)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1), alignment: .leading
            )
            #if os(macOS)
            .overlay(
                Rectangle()
                    .fill(prefs.appearance == .space ? Color.white.opacity(0.15) : (colorScheme == .light ? Color.black.opacity(0.5) : Color.clear))
                    .frame(height: 1), alignment: .top
            )
            #endif
            .alert("Reset to Original Metadata?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    metadataManager.removeOverride(for: plugin.path)
                    print("✅ Reset metadata to original for: \(plugin.name)")
                }
            } message: {
                Text("This will restore the original metadata (Publisher, Version, Style) for this plugin. You can undo this action using the Undo button.")
            }
        }
    }

    // MARK: - Editable Metadata Section

    @ViewBuilder
    private func editableMetadataSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EDIT METADATA")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Edit plugin information below. Changes are saved automatically.")
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            // Name
            editableField(
                label: "NAME", text: $editedName, placeholder: "Plugin name"
            ) {
                // Save name (Note: plugin name is typically read-only from scan)
                print("Name edited to: \(editedName)")
            }

            // Publisher
            editableMetadataField(
                label: "PUBLISHER", plugin: plugin, field: .publisher, placeholder: "Publisher/Developer name"
            )

            // Version
            editableMetadataField(
                label: "VERSION", plugin: plugin, field: .version, placeholder: "Version number"
            )

            // Style
            editableMetadataField(
                label: "STYLE/CATEGORY", plugin: plugin, field: .style, placeholder: "e.g., EQ, Compressor, Reverb"
            )

            // Reset and Undo buttons
            HStack(spacing: 12) {
                // Reset to Original button
                Button(action: {
                    showResetConfirmation = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Original")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!metadataManager.hasOverride(for: plugin.path))
                .opacity(metadataManager.hasOverride(for: plugin.path) ? 1.0 : 0.5)

                // Undo button
                Button(action: {
                    metadataManager.undoRemoveOverride(for: plugin.path)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!metadataManager.canUndo(for: plugin.path))
                .opacity(metadataManager.canUndo(for: plugin.path) ? 1.0 : 0.5)
            }
            .padding(.top, 8)

            // Track Name (for playlist plugins)
            if plugin.trackName != nil {
                editableField(
                    label: "TRACK NAME", text: $editedTrack, placeholder: "Track name from DAW"
                ) {
                    // Track name editing (display only, no persistence yet)
                    print("Track edited to: \(editedTrack)")
                }
            }
        }
    }

    enum MetadataFieldType {
        case publisher, version, style
    }

    @ViewBuilder
    private func editableMetadataField(label: String, plugin: PluginItem, field: MetadataFieldType, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            // Create a binding that directly reads/writes to MetadataManager
            let binding = Binding<String>(
                get: {
                    switch field {
                    case .publisher: 
                        return metadataManager.getDisplayPublisher(for: plugin)
                    case .version: 
                        return metadataManager.getDisplayVersion(for: plugin)
                    case .style: 
                        return metadataManager.getDisplayStyle(for: plugin)
                    }
                }, set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()

                    switch field {
                    case .publisher: 
                        override.publisher = trimmed
                    case .version: 
                        override.version = trimmed
                    case .style: 
                        override.style = trimmed
                    }

                    metadataManager.setOverride(for: plugin.path, override: override)
                    print("✅ Saved \(field): '\(trimmed)' for \(plugin.name)")
                }
            )

            TextField(placeholder, text: binding)
                .textFieldStyle(.plain)
                .padding(8)
                #if os(macOS)
                .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor))
                #else
                .background(Color(.systemBackground))
                #endif
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func editableField(label: String, text: Binding<String>, placeholder: String, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(8)
                #if os(macOS)
                .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor))
                #else
                .background(Color(.systemBackground))
                #endif
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onSubmit {
                    if !isInitializing {
                        onCommit()
                    }
                }
                .onChange(of: text.wrappedValue) { _ in
                    // Auto-save on change (but not during initialization)
                    if !isInitializing {
                        onCommit()
                    }
                }
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(plugin: PluginItem) -> some View {
        HStack(spacing: 12) {
            // Plugin icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing
                    ))

                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(.headline)
                        .lineLimit(2)

                    // Show green checkmark ONLY if fully enriched (has image AND specs)
                    let hasImage = plugin.screenshotUrl != nil || plugin.thumbnailUrl != nil
                    let hasSpecs = plugin.specs != nil && !plugin.specs!.isEmpty
                    let isFullyEnriched = hasImage && hasSpecs

                    if isFullyEnriched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .help("Fully enriched: Has image and specs data from Firebase")
                    }
                }

                Text(metadataManager.getDisplayPublisher(for: plugin))
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()
        }
        .padding(16)
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INFO")
                .font(.headline)
                .foregroundColor(.primary)

            infoRow(label: "DEVELOPER:", value: metadataManager.getDisplayPublisher(for: plugin))
            infoRow(label: "VERSION:", value: metadataManager.getDisplayVersion(for: plugin))
            infoRow(label: "TYPE:", value: plugin.type)
            #if os(macOS)
            infoRow(label: "LICENSE:", value: LicenseTypeHelper.getCachedLicenseType(for: plugin))
            #endif
            infoRow(label: "ARCHITECTURE:", value: plugin.architectures)
            infoRow(label: "DATE MODIFIED:", value: plugin.dateString)
            infoRow(label: "SIZE:", value: plugin.sizeString)
            infoRow(label: "PATH:", value: plugin.path)
            infoRow(label: "LAST BACKUP:", value: plugin.displayDate)

            // Website link
            if !plugin.publisher.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("WEBSITE:")
                        .font(.subheadline)
                        .foregroundColor(secondaryTextColor)
                        .frame(width: 100, alignment: .leading)

                    Button(action: {
                        openPublisherWebsite(plugin: plugin)
                    }) {
                        Text(generateWebsiteURL(for: plugin.publisher))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .frame(width: 100, alignment: .leading)

            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    // MARK: - Tags Section

    @ViewBuilder
    private func tagsSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS")
                .font(.headline)
                .foregroundColor(.primary)

            let currentTags = tagsManager.getTags(for: plugin.path)

            if currentTags.isEmpty {
                Text("No tags yet")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
            } else {
                // Tag chips with remove buttons - auto-expanding
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 150))], alignment: .leading, spacing: 8) {
                    ForEach(Array(currentTags).sorted(), id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag.uppercased())
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Button(action: {
                                tagsManager.removeTag(tag, from: plugin.path)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        #if os(macOS)
                        .background(prefs.appearance == .space ? Color(red: 25/255, green: 25/255, blue: 25/255) : Color.primary.opacity(0.1))
                        #else
                        .background(Color.primary.opacity(0.1))
                        #endif
                        .cornerRadius(4)
                    }
                }
                .padding(.bottom, 10)
            }

            // Add tag field
            HStack(spacing: 8) {
                TextField("Add tag...", text: $newTagText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        addTag(to: plugin)
                    }

                Button(action: {
                    addTag(to: plugin)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Suggested Tags Section

    @ViewBuilder
    private func suggestedTagsSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUGGESTED TAGS")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Click on one or more suggested tags to use them.")
                .font(.caption)
                .foregroundColor(secondaryTextColor)

            let suggestedTags = tagsManager.getSuggestedTags(for: plugin)

            if suggestedTags.isEmpty {
                Text("No suggestions available")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
            } else {
                SimpleFlowLayout(items: suggestedTags.prefix(10).map { $0 }) { tag in
                    Button(action: {
                        tagsManager.addTag(tag, to: plugin.path)
                    }) {
                        Text(tag.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            #if os(macOS)
                            .background(prefs.appearance == .space ? Color(red: 25/255, green: 25/255, blue: 25/255) : Color.primary.opacity(0.05))
                            #else
                            .background(Color.primary.opacity(0.05))
                            #endif
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 80)
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private func notesSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let noteText = Binding(
                get: { notesManager.getNote(for: plugin.path) }, set: { notesManager.setNote(for: plugin.path, note: $0) }
            )

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: noteText)
                        .frame(minHeight: 80, maxHeight: 120)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        #if os(macOS)
                        .background(prefs.appearance == .space ? Color.black : Color(NSColor.textBackgroundColor))
                        #else
                        .background(Color(.systemBackground))
                        #endif

                    // Placeholder text
                    if noteText.wrappedValue.isEmpty {
                        Text("NOTES")
                            .font(.system(size: 12))
                            .foregroundColor(colorScheme == .light ? Color.black.opacity(0.5) : .secondary.opacity(0.5))
                            .padding(.horizontal, 13)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(colorScheme == .light ? Color.black.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.clear))
            )
        }
    }

    // MARK: - Rating Section

    @ViewBuilder
    private func ratingSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let currentRating = ratingsManager.getRating(forName: plugin.name)

            // Header with rating descriptor
            HStack(spacing: 8) {
                Text("RATING")
                    .font(.headline)
                    .foregroundColor(.primary)

                if currentRating > 0 {
                    Text("\(currentRating) star\(currentRating == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }

            // Star buttons
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        let current = ratingsManager.getRating(forName: plugin.name)
                        let newRating = (current == star) ? 0 : star
                        ratingsManager.setRating(forName: plugin.name, rating: newRating)
                    }) {
                        Image(systemName: star <= currentRating ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(star <= currentRating ? .yellow : .gray.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Specs Section

    private func specsSection(plugin: PluginItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Feature Bullet Points (from manufacturer website via Firebase) - FIRST
            if let features = plugin.features, !features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FEATURES")
                        .font(.headline)
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(feature)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                divider
            }

            // Description (from Firebase) - SECOND
            if let description = plugin.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESCRIPTION")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                divider
            }

            // TECHNICAL SPECIFICATIONS section (specs text only)
            if let specs = plugin.specs, !specs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TECHNICAL SPECIFICATIONS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(specs)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                divider
            }

            // Feature Tags (from Firebase) - FOURTH
            if let tags = plugin.tags, !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TAGS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                divider
            }

            // GUI COLORS section (underneath TAGS)
            if let colorScheme = plugin.colorScheme, !colorScheme.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GUI COLORS")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        ForEach(colorScheme.components(separatedBy: " ").filter { !$0.isEmpty }, id: \.self) { color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorFromName(color))
                                    .frame(width: 12, height: 12)
                                Text(color.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Placeholder for future structured specs from Firebase
            if let tags = plugin.tags, tags.isEmpty, plugin.description == nil {
                VStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No specifications available")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Specifications will appear here once this plugin is enriched from Firebase")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }

    private func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        case "dark gray", "dark grey": return Color.gray.opacity(0.6)
        case "light gray", "light grey": return Color.gray.opacity(0.3)
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }

    // MARK: - Helper Functions

    private func addTag(to plugin: PluginItem) {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        tagsManager.addTag(trimmed, to: plugin.path)
        newTagText = ""
    }

    private func generateWebsiteURL(for publisher: String) -> String {
        // Try vendor database first for accurate URLs
        if let vendorURL = VendorURLs.getWebsiteURL(for: publisher) {
            return vendorURL
        }

        // Fallback to simple generation
        return VendorURLs.generateFallbackURL(for: publisher)
    }

    private func openPublisherWebsite(plugin: PluginItem) {
        let urlString = generateWebsiteURL(for: plugin.publisher)
        if let url = URL(string: urlString) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

    /// Strip HTML tags and decode entities from text
    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove <style> tags and their contents
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)

        // Remove <script> tags and their contents
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)

        // Remove HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")

        // Remove extra whitespace and newlines
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if text looks like CSS/HTML/code rather than human-readable content
    private func looksLikeCode(_ text: String) -> Bool {
        // Check for CSS-like patterns
        if text.contains("{") && text.contains("}") && text.contains(":") {
            return true
        }

        // Check for WordPress/HTML class patterns
        if text.contains(".wp-") || text.contains("#wp-") || text.contains("display:grid") {
            return true
        }

        // Check if mostly punctuation/symbols (CSS indicators)
        let alphanumericCount = text.filter { $0.isLetter || $0.isNumber }.count
        let totalCount = text.count
        if totalCount > 0 && Double(alphanumericCount) / Double(totalCount) < 0.5 {
            return true
        }

        return false
    }

    // MARK: - Helper Functions

    private func initializeFields(for plugin: PluginItem) {
        print("🔄 Initializing fields for: \(plugin.name)")
        isInitializing = true
        editedName = plugin.name
        editedPublisher = metadataManager.getDisplayPublisher(for: plugin)
        editedVersion = metadataManager.getDisplayVersion(for: plugin)
        editedStyle = metadataManager.getDisplayStyle(for: plugin)
        editedType = plugin.type
        editedArchitecture = plugin.architectures
        editedTrack = plugin.trackName ?? ""
        print("   Publisher: '\(editedPublisher)'")
        print("   Version: '\(editedVersion)'")
        print("   Style: '\(editedStyle)'")
        // Delay resetting the flag to ensure all onChange handlers have fired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInitializing = false
            print("✅ Initialization complete for: \(plugin.name)")
        }
    }

    // MARK: - Save Functions

    private func savePublisher(for plugin: PluginItem) {
        let trimmed = editedPublisher.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Only save if different from current value
        let currentValue = metadataManager.getDisplayPublisher(for: plugin)
        guard trimmed != currentValue else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.publisher = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
        print("✅ Saved publisher: '\(trimmed)' for \(plugin.name)")
    }

    private func saveVersion(for plugin: PluginItem) {
        let trimmed = editedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Only save if different from current value
        let currentValue = metadataManager.getDisplayVersion(for: plugin)
        guard trimmed != currentValue else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.version = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
        print("✅ Saved version: '\(trimmed)' for \(plugin.name)")
    }

    private func saveStyle(for plugin: PluginItem) {
        let trimmed = editedStyle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Only save if different from current value
        let currentValue = metadataManager.getDisplayStyle(for: plugin)
        guard trimmed != currentValue else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.style = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
        print("✅ Saved style: '\(trimmed)' for \(plugin.name)")
    }
}

// MARK: - Simple Flow Layout for Detail Panel

private struct SimpleFlowLayout<T: Hashable>: View {
    let items: [T]
    let content: (T) -> AnyView

    init(items: [T], @ViewBuilder content: @escaping (T) -> some View) {
        self.items = items
        self.content = { AnyView(content($0)) }
    }

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    content(item)
                        .alignmentGuide(.leading) { dimension in
                            if abs(width - dimension.width) > geometry.size.width {
                                width = 0
                                height -= dimension.height + 4
                            }
                            let result = width
                            if index == items.count - 1 {
                                width = 0
                            } else {
                                width -= dimension.width + 4
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if index == items.count - 1 {
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
    }
}
