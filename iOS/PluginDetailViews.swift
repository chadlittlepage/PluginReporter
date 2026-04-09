//
//  PluginDetailViews.swift
//  PluginReporter (iOS)
//

import SwiftUI

// MARK: - Consolidated Plugin Detail View

struct ConsolidatedPluginDetailView: View {
    let consolidated: PluginListView.ConsolidatedPlugin
    @State private var showShareSheet = false
    @State private var showPluginImage = true  // Toggle between chart and screenshot (default to image)
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var ratingsManager = RatingsManager.shared
    @StateObject private var tagsManager = TagsManager.shared
    @StateObject private var metadataManager = MetadataManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(consolidated.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("by \(consolidated.publisher)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // Screenshot/Chart Toggle Section
                screenshotSection

                Divider()

                // AI Suggestions Button - Top Center
                HStack {
                    Spacer()
                    AISuggestionsButton(
                        plugin: consolidated.originalPlugins.first ?? PluginItem(
                            name: consolidated.name,
                            publisher: consolidated.publisher,
                            version: "",
                            type: consolidated.types.first ?? "",
                            style: consolidated.style,
                            architectures: "",
                            date: nil,
                            sizeBytes: 0,
                            path: "",
                            runtimeRequirement: "",
                            obsolete: false
                        ),
                        ownedPlugins: [] // Don't pass all plugins - AI service doesn't need them all
                    )
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Rating Section (syncs across all formats)
                if let firstPlugin = consolidated.originalPlugins.first {
                    PluginRatingSection(
                        pluginPath: firstPlugin.path,
                        allFormatPaths: consolidated.originalPlugins.map { $0.path },
                        ratingsManager: ratingsManager
                    )
                    .padding(.horizontal)
                }

                Divider()

                // Tags Section (syncs across all formats)
                if let firstPlugin = consolidated.originalPlugins.first {
                    PluginTagsSection(
                        plugin: firstPlugin,
                        tagsManager: tagsManager
                    )
                    .padding(.horizontal)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // Available formats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Formats")
                            .font(.headline)

                        HStack(spacing: 8) {
                            ForEach(consolidated.types, id: \.self) { type in
                                Text(type)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 48, height: 18)  // Fixed uniform size (matches listing view)
                                    .background(ColorUtilities.colorForFormat(type).opacity(0.2))
                                    .foregroundColor(ColorUtilities.colorForFormat(type))
                                    .cornerRadius(Constants.Layout.badgeCornerRadius)
                            }
                        }
                    }

                    if let firstPlugin = consolidated.originalPlugins.first {
                        DetailInfoRow(label: "Publisher", value: metadataManager.getDisplayPublisher(for: firstPlugin))
                    }

                    if let firstPlugin = consolidated.originalPlugins.first {
                        let displayStyle = metadataManager.getDisplayStyle(for: firstPlugin)
                        if !displayStyle.isEmpty {
                            DetailInfoRow(label: "Style", value: displayStyle)
                        }
                    }

                    // Show details for each format - LAZY loading for speed
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(consolidated.originalPlugins) { plugin in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(plugin.type) Details")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(ColorUtilities.colorForFormat(plugin.type))

                                DetailInfoRow(label: "Version", value: metadataManager.getDisplayVersion(for: plugin))
                                DetailInfoRow(label: "Architecture", value: plugin.architectures.isEmpty ? "Unknown" : plugin.architectures)
                                DetailInfoRow(label: "Size", value: plugin.displaySize)

                                if !plugin.path.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Path")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(plugin.path)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(10)
                                            .background(Color(.systemGray6).opacity(0.5))
                                            .cornerRadius(8)
                                            .lineLimit(2)
                                    }
                                }

                                // Notes Section for this format
                                PluginNotesSection(pluginPath: plugin.path, notesManager: notesManager)

                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    // Screenshot Section with Toggle
    @ViewBuilder
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle button
            HStack {
                Button(action: {
                    withAnimation {
                        showPluginImage.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showPluginImage ? "chart.bar" : "photo")
                            .font(.subheadline)
                        Text(showPluginImage ? "Show Chart" : "Show Image")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Content area
            if showPluginImage {
                // Show screenshot
                if let firstPlugin = consolidated.originalPlugins.first {
                    let imageUrlString = firstPlugin.screenshotUrl ?? firstPlugin.thumbnailUrl

                    if let imageUrlString = imageUrlString,
                       let imageURL = URL(string: imageUrlString) {
                        let pluginKey = "\(consolidated.name)|\(consolidated.publisher)"
                        CachedAsyncImage(url: imageURL, pluginKey: pluginKey) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                        .padding(.horizontal)
                    } else {
                        // No screenshot available
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No screenshot available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Show chart placeholder
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Chart view not implemented")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }
        }
    }

    var shareText: String {
        var text = "\(consolidated.name)\n"
        text += "Publisher: \(consolidated.publisher)\n"
        text += "Formats: \(consolidated.types.joined(separator: ", "))\n"
        if !consolidated.style.isEmpty {
            text += "Style: \(consolidated.style)\n"
        }
        return text
    }
}

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    let plugin: PluginItem
    @State private var showShareSheet = false
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var ratingsManager = RatingsManager.shared
    @StateObject private var tagsManager = TagsManager.shared
    @StateObject private var metadataManager = MetadataManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plugin.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("by \(plugin.publisher)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // AI Suggestions Button - Top Center
                HStack {
                    Spacer()
                    AISuggestionsButton(
                        plugin: plugin,
                        ownedPlugins: [plugin]
                    )
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Rating Section
                PluginRatingSection(
                    pluginPath: plugin.path,
                    allFormatPaths: [plugin.path],
                    ratingsManager: ratingsManager
                )
                .padding(.horizontal)

                Divider()

                // Tags Section
                PluginTagsSection(
                    plugin: plugin,
                    tagsManager: tagsManager
                )
                .padding(.horizontal)

                Divider()

                VStack(spacing: 12) {
                    DetailInfoRow(label: "Publisher", value: metadataManager.getDisplayPublisher(for: plugin))
                    DetailInfoRow(label: "Type", value: plugin.type, color: ColorUtilities.colorForFormat(plugin.type))
                    DetailInfoRow(label: "Style", value: metadataManager.getDisplayStyle(for: plugin))
                    DetailInfoRow(label: "Version", value: metadataManager.getDisplayVersion(for: plugin))
                    DetailInfoRow(label: "Architecture", value: plugin.architectures.isEmpty ? "Unknown" : plugin.architectures)
                    DetailInfoRow(label: "Date", value: plugin.displayDate)
                    DetailInfoRow(label: "Size", value: plugin.displaySize)

                    if !plugin.path.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Path")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(plugin.path)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(10)
                                .background(Color(.systemGray6).opacity(0.5))
                                .cornerRadius(8)
                                .lineLimit(2)
                        }
                    }

                    // Notes Section
                    PluginNotesSection(pluginPath: plugin.path, notesManager: notesManager)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    var shareText: String {
        var text = "\(plugin.name)\n"
        text += "Publisher: \(plugin.publisher)\n"
        text += "Type: \(plugin.type)\n"
        if !plugin.style.isEmpty {
            text += "Style: \(plugin.style)\n"
        }
        if !plugin.version.isEmpty {
            text += "Version: \(plugin.version)\n"
        }
        return text
    }
}

// MARK: - Detail Info Row

struct DetailInfoRow: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            if let color = color {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .cornerRadius(6)
            } else {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Plugin Notes Section

struct PluginNotesSection: View {
    let pluginPath: String
    @ObservedObject var notesManager: NotesManager
    @State private var noteText: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if !noteText.isEmpty && !isEditing {
                    Button(action: {
                        isEditing = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            if isEditing || !noteText.isEmpty {
                TextEditor(text: $noteText)
                    .frame(minHeight: 80, maxHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEditing ? Color.blue : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: noteText) { newValue in
                        notesManager.setNote(for: pluginPath, note: newValue)
                    }
                    .onTapGesture {
                        isEditing = true
                    }

                if isEditing {
                    Button("Done") {
                        isEditing = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button(action: {
                    isEditing = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add notes")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Text("Keep track of your favorite presets, techniques, tricks, etc.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.top, 8)
        .onAppear {
            noteText = notesManager.getNote(for: pluginPath)
        }
    }
}

// MARK: - Plugin Rating Section

struct PluginRatingSection: View {
    let pluginPath: String
    let allFormatPaths: [String]
    @ObservedObject var ratingsManager: RatingsManager

    var body: some View {
        let currentRating = ratingsManager.getRating(for: pluginPath)

        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        // Get the current rating
                        let current = ratingsManager.getRating(for: pluginPath)
                        let newRating = (current == star) ? 0 : star

                        // Set rating for all formats
                        for path in allFormatPaths {
                            ratingsManager.setRating(for: path, rating: newRating)
                        }
                    }) {
                        Image(systemName: star <= currentRating ? "star.fill" : "star")
                            .font(.system(size: 21))
                            .foregroundColor(star <= currentRating ? .yellow : .gray.opacity(0.3))
                    }
                }
            }

            if currentRating > 0 {
                Text("\(currentRating) star\(currentRating == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap to rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Plugin Tags Section

struct PluginTagsSection: View {
    let plugin: PluginItem
    @ObservedObject var tagsManager: TagsManager
    @State private var newTagText = ""
    @State private var showAddTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tags", systemImage: "tag.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showAddTag.toggle()
                }) {
                    Image(systemName: showAddTag ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }

            let currentTags = tagsManager.getTags(for: plugin.path)

            // Current tags
            if !currentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(currentTags).sorted(), id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Button(action: {
                                    tagsManager.removeTag(tag, from: plugin.path)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No tags yet. Tap + to add tags.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }

            // Add tag field
            if showAddTag {
                VStack(spacing: 8) {
                    TextField("Enter tag name", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .onSubmit {
                            addTag()
                        }

                    HStack(spacing: 12) {
                        Button("Add") {
                            addTag()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("Cancel") {
                            newTagText = ""
                            showAddTag = false
                        }
                        .buttonStyle(.bordered)
                    }

                    // Suggested tags
                    let suggestions = tagsManager.getSuggestedTags(for: plugin)
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions.prefix(10), id: \.self) { suggestion in
                                        Button(action: {
                                            tagsManager.addTag(suggestion, to: plugin.path)
                                        }) {
                                            Text(suggestion.uppercased())
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color(.systemGray5))
                                                .foregroundColor(.primary)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tagsManager.addTag(trimmed, to: plugin.path)
            newTagText = ""
            showAddTag = false
        }
    }
}
