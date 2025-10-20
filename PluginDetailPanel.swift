//
//  PluginDetailPanel.swift
//  PluginReporter
//
//  Collapsible right-hand detail panel for viewing and editing plugin info
//

import SwiftUI

struct PluginDetailPanel: View {
    let plugin: PluginItem?
    @Binding var isVisible: Bool

    @StateObject private var metadataManager = MetadataManager.shared
    @StateObject private var tagsManager = TagsManager.shared
    @StateObject private var ratingsManager = RatingsManager.shared
    @StateObject private var notesManager = NotesManager.shared
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
                // Title (matching DAW Playlists sidebar style)
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text("Metadata")
                        .font(.headline)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 17)

                divider

                // Header with plugin name
                headerSection(plugin: plugin)

                divider

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
                    initializeFields(for: plugin)
                }
                .onChange(of: plugin.id) { _ in
                    // Refresh fields when plugin selection changes
                    initializeFields(for: plugin)
                }
            }
            .frame(width: panelWidth)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1),
                alignment: .leading
            )
            #if os(macOS)
            .overlay(
                Rectangle()
                    .fill(prefs.appearance == .space ? Color.white.opacity(0.15) : (colorScheme == .light ? Color.black.opacity(0.5) : Color.clear))
                    .frame(height: 1),
                alignment: .top
            )
            #endif
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
                label: "NAME",
                text: $editedName,
                placeholder: "Plugin name"
            ) {
                // Save name (Note: plugin name is typically read-only from scan)
                print("Name edited to: \(editedName)")
            }

            // Publisher
            editableField(
                label: "PUBLISHER",
                text: $editedPublisher,
                placeholder: "Publisher/Developer name"
            ) {
                savePublisher(for: plugin)
            }

            // Version
            editableField(
                label: "VERSION",
                text: $editedVersion,
                placeholder: "Version number"
            ) {
                saveVersion(for: plugin)
            }

            // Style
            editableField(
                label: "STYLE/CATEGORY",
                text: $editedStyle,
                placeholder: "e.g., EQ, Compressor, Reverb"
            ) {
                saveStyle(for: plugin)
            }

            // Type (read-only, showing badge)
            VStack(alignment: .leading, spacing: 4) {
                Text("TYPE")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)

                Text(plugin.type)
                    .font(.subheadline)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor).opacity(0.5))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }

            // Architecture (read-only)
            VStack(alignment: .leading, spacing: 4) {
                Text("ARCHITECTURE")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)

                Text(plugin.architectures)
                    .font(.subheadline)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor).opacity(0.5))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }

            // Track Name (for playlist plugins)
            if plugin.trackName != nil {
                editableField(
                    label: "TRACK NAME",
                    text: $editedTrack,
                    placeholder: "Track name from DAW"
                ) {
                    // Track name editing (display only, no persistence yet)
                    print("Track edited to: \(editedTrack)")
                }
            }

            // Date (read-only)
            VStack(alignment: .leading, spacing: 4) {
                Text("DATE MODIFIED")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)

                Text(plugin.dateString)
                    .font(.subheadline)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor).opacity(0.5))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }

            // Size (read-only)
            VStack(alignment: .leading, spacing: 4) {
                Text("SIZE")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)

                Text(plugin.sizeString)
                    .font(.subheadline)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor).opacity(0.5))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }

            // Path (read-only)
            VStack(alignment: .leading, spacing: 4) {
                Text("PATH")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)

                Text(plugin.path)
                    .font(.caption)
                    .lineLimit(3)
                    .padding(8)
                    #if os(macOS)
                    .background(prefs.appearance == .space ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(NSColor.textBackgroundColor).opacity(0.5))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .foregroundColor(.secondary)
            }
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
                        colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.headline)
                    .lineLimit(2)

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

            // Types
            HStack(alignment: .top, spacing: 8) {
                Text("TYPES:")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
                    .frame(width: 100, alignment: .leading)

                Text(plugin.type)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()
            }

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
                get: { notesManager.getNote(for: plugin.path) },
                set: { notesManager.setNote(for: plugin.path, note: $0) }
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

    // MARK: - Helper Functions

    private func addTag(to plugin: PluginItem) {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        tagsManager.addTag(trimmed, to: plugin.path)
        newTagText = ""
    }

    private func generateWebsiteURL(for publisher: String) -> String {
        let clean = publisher.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "inc", with: "")
            .replacingOccurrences(of: "llc", with: "")
            .replacingOccurrences(of: "gmbh", with: "")

        return "\(clean).com"
    }

    private func openPublisherWebsite(plugin: PluginItem) {
        let urlString = "https://\(generateWebsiteURL(for: plugin.publisher))"
        if let url = URL(string: urlString) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

    // MARK: - Helper Functions

    private func initializeFields(for plugin: PluginItem) {
        isInitializing = true
        editedName = plugin.name
        editedPublisher = metadataManager.getDisplayPublisher(for: plugin)
        editedVersion = metadataManager.getDisplayVersion(for: plugin)
        editedStyle = metadataManager.getDisplayStyle(for: plugin)
        editedType = plugin.type
        editedArchitecture = plugin.architectures
        editedTrack = plugin.trackName ?? ""
        // Delay resetting the flag to ensure all onChange handlers have fired
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInitializing = false
        }
    }

    // MARK: - Save Functions

    private func savePublisher(for plugin: PluginItem) {
        let trimmed = editedPublisher.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.publisher = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
    }

    private func saveVersion(for plugin: PluginItem) {
        let trimmed = editedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.version = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
    }

    private func saveStyle(for plugin: PluginItem) {
        let trimmed = editedStyle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
        override.style = trimmed
        metadataManager.setOverride(for: plugin.path, override: override)
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

