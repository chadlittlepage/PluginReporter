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

    @State private var showMetadataEditor = false
    @State private var newTagText = ""

    private let panelWidth: CGFloat = 350

    var body: some View {
        if isVisible, let plugin = plugin {
            VStack(alignment: .leading, spacing: 0) {
                // Header with plugin name
                headerSection(plugin: plugin)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Info Section
                        infoSection(plugin: plugin)

                        Divider()

                        // Tags Section
                        tagsSection(plugin: plugin)

                        Divider()

                        // Suggested Tags Section
                        suggestedTagsSection(plugin: plugin)

                        Divider()

                        // Rating Section
                        ratingSection(plugin: plugin)

                        Divider()

                        // Notes Section
                        notesSection(plugin: plugin)
                    }
                    .padding(16)
                }
            }
            .frame(width: panelWidth)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1),
                alignment: .leading
            )
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
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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

            // Edit button
            Button(action: {
                showMetadataEditor = true
            }) {
                Text("Edit Metadata")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showMetadataEditor) {
                MetadataEditorSheet(plugin: plugin)
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
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
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(.bottom, 10)
            }

            // Add tag field
            HStack(spacing: 8) {
                TextField("Add tag...", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
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
                .foregroundColor(.secondary)

            let suggestedTags = tagsManager.getSuggestedTags(for: plugin)

            if suggestedTags.isEmpty {
                Text("No suggestions available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                            .background(Color.primary.opacity(0.05))
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

            ZStack(alignment: .topLeading) {
                TextEditor(text: noteText)
                    .frame(minHeight: 80, maxHeight: 120)
                    .font(.system(size: 12))
                    .padding(8)
                    #if os(macOS)
                    .background(Color(nsColor: .textBackgroundColor))
                    #else
                    .background(Color(.systemBackground))
                    #endif
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                // Placeholder text
                if noteText.wrappedValue.isEmpty {
                    Text("NOTES")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 13)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
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
                        .foregroundColor(.secondary)
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

// MARK: - Metadata Editor Sheet (from MacPluginTable.swift)

private struct MetadataEditorSheet: View {
    let plugin: PluginItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var metadataManager = MetadataManager.shared

    @State private var publisher: String = ""
    @State private var version: String = ""
    @State private var style: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Metadata")
                .font(.title)
                .fontWeight(.bold)

            Text(plugin.name)
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Override metadata for this plugin. Leave fields empty to use original values.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Publisher")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.publisher)", text: $publisher)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.version)", text: $version)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Original: \(plugin.style)", text: $style)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer()

            HStack {
                Button("Reset to Original") {
                    metadataManager.removeOverride(for: plugin.path)
                    publisher = ""
                    version = ""
                    style = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveMetadata()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .onAppear {
            if let override = metadataManager.getOverride(for: plugin.path) {
                publisher = override.publisher ?? ""
                version = override.version ?? ""
                style = override.style ?? ""
            }
        }
    }

    private func saveMetadata() {
        let override = PluginMetadataOverride(
            publisher: publisher.isEmpty ? nil : publisher,
            version: version.isEmpty ? nil : version,
            style: style.isEmpty ? nil : style
        )

        if override.hasAnyOverride {
            metadataManager.setOverride(for: plugin.path, override: override)
        } else {
            metadataManager.removeOverride(for: plugin.path)
        }
    }
}
