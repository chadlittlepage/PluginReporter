//
//  BulkEditPanel.swift
//  PluginReporter
//
//  Bulk editing panel for multiple selected plugins
//

import SwiftUI

struct BulkEditPanel: View {
    let plugins: [PluginItem]
    @Binding var isVisible: Bool

    @StateObject private var tagsManager = TagsManager.shared
    @StateObject private var ratingsManager = RatingsManager.shared
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var metadataManager = MetadataManager.shared

    @State private var newTagText = ""
    @State private var bulkRating: Int = 0
    @State private var showAddTag = false
    @State private var showMetadataEditor = false
    @State private var bulkPublisher = ""
    @State private var bulkVersion = ""
    @State private var bulkStyle = ""
    @State private var showNotesEditor = false
    @State private var bulkNotes = ""
    @State private var showResetConfirmation = false

    private let panelWidth: CGFloat = 350

    var body: some View {
        if isVisible && !plugins.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerSection

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Selection summary
                        summarySection

                        Divider()

                        // Bulk rating
                        bulkRatingSection

                        Divider()

                        // Bulk tags
                        bulkTagsSection

                        Divider()

                        // Bulk metadata
                        bulkMetadataSection

                        Divider()

                        // Bulk notes
                        bulkNotesSection

                        Divider()

                        // Clear all metadata
                        clearAllSection
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
                    .frame(width: 1), alignment: .leading
            )
            .alert("Reset to Original Metadata?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllToOriginal()
                }
            } message: {
                Text("This will restore the original metadata (Publisher, Version, Style) for all \(plugins.count) selected plugins. You can undo this action using the Undo button.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing
                    ))

                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bulk Edit")
                    .font(.headline)

                Text("\(plugins.count) plugins selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { isVisible = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECTED PLUGINS")
                .font(.headline)
                .foregroundColor(.primary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plugins.prefix(10)) { plugin in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)

                            Text(plugin.name)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(plugin.type)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ColorUtilities.colorForFormat(plugin.type).opacity(0.2))
                                .foregroundColor(ColorUtilities.colorForFormat(plugin.type))
                                .cornerRadius(4)
                        }
                    }

                    if plugins.count > 10 {
                        Text("... and \(plugins.count - 10) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    // MARK: - Bulk Rating Section

    private var bulkRatingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SET RATING FOR ALL")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                ForEach(0...5, id: \.self) { rating in
                    Button(action: {
                        bulkRating = rating
                        applyBulkRating(rating)
                    }) {
                        if rating == 0 {
                            Image(systemName: "xmark.circle")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundColor(rating <= bulkRating ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if bulkRating > 0 {
                Text("Setting \(bulkRating) star\(bulkRating == 1 ? "" : "s") for all \(plugins.count) plugins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Click ✕ to clear ratings, or click stars to rate all")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Bulk Tags Section

    private var bulkTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ADD TAGS TO ALL")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { showAddTag.toggle() }) {
                    Image(systemName: showAddTag ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            if showAddTag {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Tag name", text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addBulkTag()
                            }

                        Button("Add") {
                            addBulkTag()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Show common tag suggestions
                    if let firstPlugin = plugins.first {
                        let suggestions = tagsManager.getSuggestedTags(for: firstPlugin)
                        if !suggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions.prefix(8), id: \.self) { tag in
                                        Button(action: {
                                            addBulkTag(tag)
                                        }) {
                                            Text(tag.uppercased())
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(.systemGray).opacity(0.2))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray).opacity(0.1))
                .cornerRadius(8)
            }

            Text("Tags will be added to all \(plugins.count) selected plugins")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    // MARK: - Bulk Metadata Section

    private var bulkMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OVERRIDE METADATA")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { showMetadataEditor.toggle() }) {
                    Image(systemName: showMetadataEditor ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            if showMetadataEditor {
                VStack(spacing: 12) {
                    // Publisher override
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Publisher Name")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("e.g., Native Instruments", text: $bulkPublisher)
                                .textFieldStyle(.roundedBorder)

                            Button("Set") {
                                applyBulkPublisher()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(bulkPublisher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    // Version override
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("e.g., 1.5.0", text: $bulkVersion)
                                .textFieldStyle(.roundedBorder)

                            Button("Set") {
                                applyBulkVersion()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(bulkVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    // Style override
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Style/Category")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("e.g., Reverb", text: $bulkStyle)
                                .textFieldStyle(.roundedBorder)

                            Button("Set") {
                                applyBulkStyle()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(bulkStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    Divider()

                    // Apply all button
                    Button(action: applyAllMetadata) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Apply All Fields to \(plugins.count) Plugins")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bulkPublisher.isEmpty && bulkVersion.isEmpty && bulkStyle.isEmpty)
                }
                .padding(8)
                .background(Color(.systemGray).opacity(0.1))
                .cornerRadius(8)
            }

            Text("Set custom publisher names, versions, or styles for all selected plugins")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    // MARK: - Bulk Notes Section

    private var bulkNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("COPY NOTES TO ALL")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { showNotesEditor.toggle() }) {
                    Image(systemName: showNotesEditor ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            if showNotesEditor {
                VStack(spacing: 12) {
                    // Notes text editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes Content")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $bulkNotes)
                            .frame(height: 100)
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
                    }

                    // Quick action buttons
                    HStack(spacing: 8) {
                        // Copy from first plugin
                        if let firstPlugin = plugins.first {
                            Button(action: {
                                bulkNotes = notesManager.getNote(for: firstPlugin.path)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy from first")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(action: {
                            bulkNotes = ""
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Clear")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    // Apply button
                    Button(action: applyBulkNotes) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Copy This Note to All \(plugins.count) Plugins")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bulkNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(8)
                .background(Color(.systemGray).opacity(0.1))
                .cornerRadius(8)
            }

            Text("Write a note and copy it to all selected plugins")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    // MARK: - Clear All Section

    private var clearAllSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLEAR METADATA")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                // Reset to Original and Undo buttons (horizontal layout)
                HStack(spacing: 8) {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Original")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!hasAnyOverrides())

                    Button(action: undoAllResets) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .disabled(!canUndoAny())
                }

                Divider()

                Button(action: clearAllRatings) {
                    HStack {
                        Image(systemName: "star.slash")
                        Text("Clear All Ratings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: clearAllTags) {
                    HStack {
                        Image(systemName: "tag.slash")
                        Text("Clear All Tags")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: clearAllNotes) {
                    HStack {
                        Image(systemName: "note.text.badge.plus")
                        Text("Clear All Notes")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button(action: clearAllMetadataOverrides) {
                    HStack {
                        Image(systemName: "pencil.slash")
                        Text("Clear All Metadata Overrides")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }

            Text("This will remove metadata from all \(plugins.count) selected plugins")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
    }

    // MARK: - Actions

    private func applyBulkRating(_ rating: Int) {
        for plugin in plugins {
            ratingsManager.setRating(for: plugin.path, rating: rating)
        }
        print("⭐ Applied rating \(rating) to \(plugins.count) plugins")
    }

    private func addBulkTag(_ tag: String? = nil) {
        let tagToAdd = tag ?? newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagToAdd.isEmpty else { return }

        for plugin in plugins {
            tagsManager.addTag(tagToAdd, to: plugin.path)
        }

        newTagText = ""
        showAddTag = false
        print("🏷️ Added tag '\(tagToAdd)' to \(plugins.count) plugins")
    }

    private func clearAllRatings() {
        for plugin in plugins {
            ratingsManager.setRating(for: plugin.path, rating: 0)
        }
        bulkRating = 0
        print("⭐ Cleared ratings for \(plugins.count) plugins")
    }

    private func clearAllTags() {
        for plugin in plugins {
            tagsManager.clearTags(for: plugin.path)
        }
        print("🏷️ Cleared tags for \(plugins.count) plugins")
    }

    private func clearAllNotes() {
        for plugin in plugins {
            notesManager.setNote(for: plugin.path, note: "")
        }
        bulkNotes = ""
        print("📝 Cleared notes for \(plugins.count) plugins")
    }

    private func applyBulkNotes() {
        let notes = bulkNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return }

        for plugin in plugins {
            notesManager.setNote(for: plugin.path, note: notes)
        }

        print("📝 Copied notes to \(plugins.count) plugins")
    }

    private func clearAllMetadataOverrides() {
        for plugin in plugins {
            metadataManager.removeOverride(for: plugin.path)
        }
        print("✏️ Cleared metadata overrides for \(plugins.count) plugins")
    }

    // MARK: - Metadata Actions

    private func applyBulkPublisher() {
        let publisher = bulkPublisher.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !publisher.isEmpty else { return }

        for plugin in plugins {
            let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
            var updated = override
            updated.publisher = publisher
            metadataManager.setOverride(for: plugin.path, override: updated)
        }

        bulkPublisher = ""
        print("✏️ Set publisher '\(publisher)' for \(plugins.count) plugins")
    }

    private func applyBulkVersion() {
        let version = bulkVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { return }

        for plugin in plugins {
            let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
            var updated = override
            updated.version = version
            metadataManager.setOverride(for: plugin.path, override: updated)
        }

        bulkVersion = ""
        print("✏️ Set version '\(version)' for \(plugins.count) plugins")
    }

    private func applyBulkStyle() {
        let style = bulkStyle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !style.isEmpty else { return }

        for plugin in plugins {
            let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
            var updated = override
            updated.style = style
            metadataManager.setOverride(for: plugin.path, override: updated)
        }

        bulkStyle = ""
        print("✏️ Set style '\(style)' for \(plugins.count) plugins")
    }

    private func applyAllMetadata() {
        let publisher = bulkPublisher.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = bulkVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let style = bulkStyle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !publisher.isEmpty || !version.isEmpty || !style.isEmpty else { return }

        for plugin in plugins {
            let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
            var updated = override

            if !publisher.isEmpty {
                updated.publisher = publisher
            }
            if !version.isEmpty {
                updated.version = version
            }
            if !style.isEmpty {
                updated.style = style
            }

            metadataManager.setOverride(for: plugin.path, override: updated)
        }

        bulkPublisher = ""
        bulkVersion = ""
        bulkStyle = ""
        print("✏️ Applied bulk metadata to \(plugins.count) plugins")
    }

    // MARK: - Reset and Undo Actions

    private func hasAnyOverrides() -> Bool {
        return plugins.contains { plugin in
            metadataManager.hasOverride(for: plugin.path)
        }
    }

    private func canUndoAny() -> Bool {
        return plugins.contains { plugin in
            metadataManager.canUndo(for: plugin.path)
        }
    }

    private func resetAllToOriginal() {
        for plugin in plugins {
            metadataManager.removeOverride(for: plugin.path)
        }
        print("↺ Reset metadata to original for \(plugins.count) plugins")
    }

    private func undoAllResets() {
        var undoneCount = 0
        for plugin in plugins {
            if metadataManager.canUndo(for: plugin.path) {
                metadataManager.undoRemoveOverride(for: plugin.path)
                undoneCount += 1
            }
        }
        print("↶ Undone reset for \(undoneCount) of \(plugins.count) plugins")
    }
}