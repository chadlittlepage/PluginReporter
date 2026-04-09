import Foundation
import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers

// MARK: - Extracted Components
// PluginDragData moved to: Models/PluginDragData.swift
// NotesCell moved to: Components/TableCells/NotesCell.swift
// RatingCell moved to: Components/TableCells/RatingCell.swift
// FadingScrollbarConfigurator moved to: Components/FadingScrollbar.swift
// MetadataEditorSheet moved to: Views/Sheets/MetadataEditorSheet.swift
// TagsEditorSheet moved to: Views/Sheets/TagsEditorSheet.swift
// View extension moved to: Extensions/ViewExtensions+Table.swift

// MARK: - Custom Resizable Window
// Moved to: Helpers/ResizableWindow.swift

// Global cache to survive view recreation when .id() changes
@MainActor
private class TableCache {
    static let shared = TableCache()
    private var cachedRows: [PluginItem] = []
    private var cacheKey: String = ""

    func getCached(for key: String) -> [PluginItem]? {
        guard key == cacheKey, !cachedRows.isEmpty else { return nil }
        return cachedRows
    }

    func store(_ rows: [PluginItem], for key: String) {
        self.cachedRows = rows
        self.cacheKey = key
    }
}

@MainActor struct MacPluginTable: View {
    let rows: [PluginItem]
    let allPlugins: [PluginItem]  // ALL plugins for AI Suggestions
    @Binding var selection: [PluginItem]
    @Binding var sortStatus: String
    @Binding var showDetailPanel: Bool
    @Binding var detailPanelTab: DetailTab
    var onPluginsDeleted: (() -> Void)?

    @State private var macSelection = Set<UUID>()
    @FocusState private var isTableFocused: Bool
    @State private var lastAnchorIndex: Int?
    @State private var lastEdgeIndex: Int?  // Track the moving edge separately
    @State private var lastScrollTime: Date = .distantPast

    // MARK: Uninstall state
    @State private var showUninstallConfirmation = false
    @State private var pluginsToUninstall: [PluginItem] = []

    // SPEED: Cache sorted rows to avoid re-sorting on every render
    @State private var cachedDisplayedRows: [PluginItem] = []
    @State private var lastManualSortKey: SortKey?
    @State private var lastManualAscending: Bool = true
    @State private var lastRowsCount: Int = 0

    // PAGINATION: Disabled - show all plugins instantly
    @StateObject private var pagination = PaginationManager<PluginItem>(threshold: Int.max) // Disabled

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var enrichmentService: PluginEnrichmentService
    @EnvironmentObject private var pluginDataMerger: PluginDataMerger

    // MARK: Resizable column widths - Set to match user's preferred layout
    @State private var wRating: CGFloat = 90       // For 5-star rating (first column)
    @State private var wName: CGFloat = 160        // Wider for plugin names
    @State private var wPublisher: CGFloat = 140   // Good for most publisher names
    @State private var wType: CGFloat = 60         // Narrower since types are short
    @State private var wStyle: CGFloat = 90        // For plugin category/style
    @State private var wVersion: CGFloat = 90      // Adequate for version numbers
    @State private var wLicense: CGFloat = 80      // For license type (Serial/iLok)
    @State private var wDate: CGFloat = 110        // Sufficient for dates
    @State private var wSize: CGFloat = 80         // Narrower for file sizes
    @State private var wRequirement: CGFloat = 110 // Good for "Universal" etc
    @State private var wObsolete: CGFloat = 90     // Narrow for Yes/No
    @State private var wMissing: CGFloat = 90      // Narrow for Yes/No
    @State private var wTrack: CGFloat = 120       // For DAW track names
    @State private var wNotes: CGFloat = 80        // For user notes
    @State private var wPath: CGFloat = 300        // Narrower so vertical scrollbar sits near regular columns
    private let dividerWidth: CGFloat = 1
    private let minColWidth: CGFloat = 30          // Allow columns to squeeze much narrower

    // MARK: Header background color to match search field
    private var headerBackgroundColor: Color {
        // Space mode: RGB(18, 18, 18)
        if prefs.appearance == .space {
            return Color(red: 18/255, green: 18/255, blue: 18/255)
        }
        // Regular dark mode: system background
        else if colorScheme == .dark {
            return Color(NSColor.windowBackgroundColor)
        }
        // Light mode: darker grey
        else {
            return Color(red: 0.82, green: 0.82, blue: 0.84)
        }
    }

    // MARK: Row/Header metrics
    private let headerHeight: CGFloat = 28
    private let rowDividerHeight: CGFloat = 16

    // MARK: Manual sorting (reliable across macOS versions)
    enum SortKey: String, CaseIterable, Identifiable { case rating, name, publisher, type, style, version, license, date, size, requirement, obsolete, missing, track, notes, path; var id: String { rawValue } }
    @State private var manualSortKey: SortKey = .name
    @State private var manualAscending: Bool = true

    // MARK: - Persistence Helpers
    private func loadTableState() {
        // Load sort preferences
        if let sortKeyRaw = UserDefaults.standard.string(forKey: "tableSortKey"),
           let sortKey = SortKey(rawValue: sortKeyRaw) {
            manualSortKey = sortKey
        }
        manualAscending = UserDefaults.standard.object(forKey: "tableSortAscending") as? Bool ?? true

        // Load column widths
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_rating") as? Double, savedWidth > 0 { wRating = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_name") as? Double, savedWidth > 0 { wName = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_publisher") as? Double, savedWidth > 0 { wPublisher = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_type") as? Double, savedWidth > 0 { wType = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_style") as? Double, savedWidth > 0 { wStyle = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_version") as? Double, savedWidth > 0 { wVersion = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_license") as? Double, savedWidth > 0 { wLicense = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_date") as? Double, savedWidth > 0 { wDate = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_size") as? Double, savedWidth > 0 { wSize = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_requirement") as? Double, savedWidth > 0 { wRequirement = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_obsolete") as? Double, savedWidth > 0 { wObsolete = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_missing") as? Double, savedWidth > 0 { wMissing = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_track") as? Double, savedWidth > 0 { wTrack = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_notes") as? Double, savedWidth > 0 { wNotes = CGFloat(savedWidth) }
        if let savedWidth = UserDefaults.standard.object(forKey: "colWidth_path") as? Double, savedWidth > 0 { wPath = CGFloat(savedWidth) }
    }

    private func saveTableState() {
        // Save sort preferences
        UserDefaults.standard.set(manualSortKey.rawValue, forKey: "tableSortKey")
        UserDefaults.standard.set(manualAscending, forKey: "tableSortAscending")

        // Save column widths
        UserDefaults.standard.set(Double(wRating), forKey: "colWidth_rating")
        UserDefaults.standard.set(Double(wName), forKey: "colWidth_name")
        UserDefaults.standard.set(Double(wPublisher), forKey: "colWidth_publisher")
        UserDefaults.standard.set(Double(wType), forKey: "colWidth_type")
        UserDefaults.standard.set(Double(wStyle), forKey: "colWidth_style")
        UserDefaults.standard.set(Double(wVersion), forKey: "colWidth_version")
        UserDefaults.standard.set(Double(wLicense), forKey: "colWidth_license")
        UserDefaults.standard.set(Double(wDate), forKey: "colWidth_date")
        UserDefaults.standard.set(Double(wSize), forKey: "colWidth_size")
        UserDefaults.standard.set(Double(wRequirement), forKey: "colWidth_requirement")
        UserDefaults.standard.set(Double(wObsolete), forKey: "colWidth_obsolete")
        UserDefaults.standard.set(Double(wMissing), forKey: "colWidth_missing")
        UserDefaults.standard.set(Double(wTrack), forKey: "colWidth_track")
        UserDefaults.standard.set(Double(wNotes), forKey: "colWidth_notes")
        UserDefaults.standard.set(Double(wPath), forKey: "colWidth_path")
    }

    private func handleRowClick(_ row: PluginItem) {
        #if os(macOS)
        let flags = NSEvent.modifierFlags
        guard let clickedIndex = displayedRows.firstIndex(where: { $0.id == row.id }) else {
            // Fallback to single select if index not found
            macSelection = [row.id]
            selection = [row]
            lastAnchorIndex = nil
            lastEdgeIndex = nil
            return
        }

        if flags.contains(.shift) {
            let anchor = lastAnchorIndex ?? clickedIndex
            let lower = min(anchor, clickedIndex)
            let upper = max(anchor, clickedIndex)
            let slice = displayedRows[lower...upper]
            macSelection = Set(slice.map { $0.id })
            selection = Array(slice)
            lastAnchorIndex = anchor
            lastEdgeIndex = clickedIndex
        } else if flags.contains(.command) {
            // Toggle membership
            if macSelection.contains(row.id) {
                macSelection.remove(row.id)
            } else {
                macSelection.insert(row.id)
            }
            let selectedSet = macSelection
            selection = displayedRows.filter { selectedSet.contains($0.id) }
            lastAnchorIndex = clickedIndex
            lastEdgeIndex = clickedIndex
        } else {
            macSelection = [row.id]
            selection = [row]
            lastAnchorIndex = clickedIndex
            lastEdgeIndex = clickedIndex
        }
        #else
        selection = [row]
        #endif
    }

    private func revealInFinder(ids: Set<UUID>) {
        #if os(macOS)
        let urls = rows.filter { ids.contains($0.id) }.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        #endif
    }

    // MARK: Bulk editing operations
    private func applyBulkRating(_ rating: Int, to plugins: [PluginItem]) {
        let ratingsManager = RatingsManager.shared
        for plugin in plugins {
            ratingsManager.setRating(forName: plugin.name, rating: rating)
        }
        print("⭐ Set rating \(rating) for \(plugins.count) plugins")
    }

    private func applyBulkTag(_ tag: String, to plugins: [PluginItem]) {
        let tagsManager = TagsManager.shared
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTag.isEmpty else { return }

        for plugin in plugins {
            tagsManager.addTag(normalizedTag, to: plugin.path)
        }
        print("🏷️ Added tag '\(normalizedTag)' to \(plugins.count) plugins")
    }

    private func showBulkTagPrompt(for plugins: [PluginItem]) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Add Tag to \(plugins.count) Plugins"
        alert.informativeText = "Enter a tag to add to all selected plugins:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Enter tag name..."
        alert.accessoryView = input

        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let tag = input.stringValue
            applyBulkTag(tag, to: plugins)
        }
        #endif
    }

    private func showBulkPublisherPrompt(for plugins: [PluginItem]) {
        #if os(macOS)
        let metadataManager = MetadataManager.shared

        // Get current publishers from selected plugins
        let currentPublishers = Set(plugins.map { metadataManager.getDisplayPublisher(for: $0) })
        let placeholderText: String
        if currentPublishers.count == 1, let publisher = currentPublishers.first {
            placeholderText = "Current: \(publisher)"
        } else {
            placeholderText = "Multiple values: \(currentPublishers.prefix(3).joined(separator: ", "))\(currentPublishers.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Publisher for \(plugins.count) Plugins"
        alert.informativeText = "Enter publisher name to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input

        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let publisher = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !publisher.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.publisher = publisher
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set publisher '\(publisher)' for \(plugins.count) plugins")
        }
        #endif
    }

    private func showBulkVersionPrompt(for plugins: [PluginItem]) {
        #if os(macOS)
        let metadataManager = MetadataManager.shared

        // Get current versions from selected plugins
        let currentVersions = Set(plugins.map { metadataManager.getDisplayVersion(for: $0) })
        let placeholderText: String
        if currentVersions.count == 1, let version = currentVersions.first {
            placeholderText = "Current: \(version)"
        } else {
            placeholderText = "Multiple values: \(currentVersions.prefix(3).joined(separator: ", "))\(currentVersions.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Version for \(plugins.count) Plugins"
        alert.informativeText = "Enter version to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input

        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let version = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !version.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.version = version
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set version '\(version)' for \(plugins.count) plugins")
        }
        #endif
    }

    private func showBulkStylePrompt(for plugins: [PluginItem]) {
        #if os(macOS)
        let metadataManager = MetadataManager.shared

        // Get current styles from selected plugins
        let currentStyles = Set(plugins.map { metadataManager.getDisplayStyle(for: $0) })
        let placeholderText: String
        if currentStyles.count == 1, let style = currentStyles.first {
            placeholderText = "Current: \(style)"
        } else {
            placeholderText = "Multiple values: \(currentStyles.prefix(3).joined(separator: ", "))\(currentStyles.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Style for \(plugins.count) Plugins"
        alert.informativeText = "Enter style/category to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input

        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let style = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !style.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.style = style
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set style '\(style)' for \(plugins.count) plugins")
        }
        #endif
    }

    private func showBulkNotesPrompt(for plugins: [PluginItem]) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Add Notes to \(plugins.count) Plugins"
        alert.informativeText = "Enter notes to add to all selected plugins:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        input.isEditable = true
        input.isSelectable = true
        input.font = NSFont.systemFont(ofSize: 13)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        scrollView.documentView = input
        scrollView.hasVerticalScroller = true

        alert.accessoryView = scrollView
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let notes = input.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !notes.isEmpty else { return }

            let notesManager = NotesManager.shared
            for plugin in plugins {
                notesManager.setNote(for: plugin.path, note: notes)
            }
            print("📝 Added notes to \(plugins.count) plugins")
        }
        #endif
    }

    private func clearBulkMetadata(for plugins: [PluginItem]) {
        let metadataManager = MetadataManager.shared
        for plugin in plugins {
            metadataManager.removeOverride(for: plugin.path)
        }
        print("🗑️ Cleared metadata for \(plugins.count) plugins")
    }
    
    private func makeSortStatus() -> String {
        let column: String
        switch manualSortKey {
        case .rating: column = "Rating"
        case .name: column = "Name"
        case .publisher: column = "Publisher"
        case .type: column = "Type"
        case .style: column = "Style"
        case .version: column = "Version"
        case .license: column = "License"
        case .date: column = "Date"
        case .size: column = "Size"
        case .requirement: column = "Requirement"
        case .obsolete: column = "Obsolete"
        case .missing: column = "Missing"
        case .track: column = "Track"
        case .notes: column = "Notes"
        case .path: column = "Path"
        }
        let dir = manualAscending ? "ascending" : "descending"
        return "Sorted by: \(column) (\(dir))"
    }

    // MARK: Fast sorting helpers (compute keys once)
    private func sortByVersionFast(_ input: [PluginItem], ascending: Bool) -> [PluginItem] {
        var pairs = input.map { (item: $0, key: $0.versionSortKey) }
        pairs.sort { ascending ? ($0.key < $1.key) : ($0.key > $1.key) }
        return pairs.map { $0.item }
    }
    private func sortByDateFast(_ input: [PluginItem], ascending: Bool) -> [PluginItem] {
        var pairs = input.map { (item: $0, key: $0.tableDateSortKey) }
        pairs.sort { ascending ? ($0.key < $1.key) : ($0.key > $1.key) }
        return pairs.map { $0.item }
    }
    private func sortBySizeFast(_ input: [PluginItem], ascending: Bool) -> [PluginItem] {
        var pairs = input.map { (item: $0, key: $0.sizeBytesSortKey) }
        pairs.sort { ascending ? ($0.key < $1.key) : ($0.key > $1.key) }
        return pairs.map { $0.item }
    }
    
    // SPEED: Return cached value directly (with pagination support)
    private var displayedRows: [PluginItem] {
        // CRITICAL: Always sort on access if data changed
        if rows.count != lastRowsCount || cachedDisplayedRows.isEmpty {
            AppLogger.info("🔄 displayedRows: Data changed (rows: \(rows.count), cached: \(cachedDisplayedRows.count)), sorting now...")

            // Sort immediately before returning (using natural/numeric sort order)
            let sorted: [PluginItem]
            switch manualSortKey {
            case .name:
                sorted = rows.sorted { a, b in
                    if a.name == b.name {
                        return a.type < b.type
                    }
                    let comparison = a.name.localizedStandardCompare(b.name)
                    return manualAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
                }
            default:
                // For now, always sort by name with natural sort order
                sorted = rows.sorted { a, b in
                    if a.name == b.name {
                        return a.type < b.type
                    }
                    let comparison = a.name.localizedStandardCompare(b.name)
                    return manualAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
                }
            }

            // Update cache inline
            DispatchQueue.main.async {
                self.cachedDisplayedRows = sorted
                self.lastRowsCount = self.rows.count
                self.lastManualSortKey = self.manualSortKey
                self.lastManualAscending = self.manualAscending
                self.pagination.updateItems(sorted)
            }

            AppLogger.info("✅ Returning \(sorted.count) SORTED rows (first 3: \(sorted.prefix(3).map { $0.name }.joined(separator: ", ")))")

            if pagination.isEnabled {
                return deduplicateByID(Array(sorted.prefix(pagination.pageSize)))
            }
            return deduplicateByID(sorted)
        }

        // Use cached rows
        if !cachedDisplayedRows.isEmpty {
            if pagination.isEnabled {
                return deduplicateByID(pagination.getCurrentPage())
            }
            return deduplicateByID(cachedDisplayedRows)
        }

        // No data at all
        return []
    }

    // BUGFIX: Remove duplicate UUIDs from array to prevent ForEach warnings
    private func deduplicateByID(_ items: [PluginItem]) -> [PluginItem] {
        var seen = Set<UUID>()
        return items.filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }

    // SPEED: Compute sorted rows only when sort key or data changes
    private func computeDisplayedRows() {
        AppLogger.debug("computeDisplayedRows(): Called with \(rows.count) rows (last: \(lastRowsCount))")

        // BUGFIX: Global cache disabled - was returning stale data after search
        // The cache key didn't include enough context to differentiate searches
        // let cacheKey = "\(rows.count)-\(manualSortKey.rawValue)-\(manualAscending)"
        // if let cached = TableCache.shared.getCached(for: cacheKey) {
        //     AppLogger.debug("computeDisplayedRows(): Using global cache (\(cached.count) rows)")
        //     cachedDisplayedRows = cached
        //     lastRowsCount = rows.count
        //     lastManualSortKey = manualSortKey
        //     lastManualAscending = manualAscending
        //     pagination.updateItems(cached)
        //     return
        // }

        let sorted: [PluginItem]
        let ratingsManager = RatingsManager.shared
        switch manualSortKey {
        case .rating:
            sorted = rows.sorted { a, b in
                let ratingA = ratingsManager.getRating(forName: a.name)
                let ratingB = ratingsManager.getRating(forName: b.name)
                return manualAscending ? (ratingA < ratingB) : (ratingA > ratingB)
            }
        case .name:
            // Sort by name first, then by type as secondary sort for consistent ordering
            sorted = rows.sorted { a, b in
                if a.name == b.name {
                    return a.type < b.type  // Secondary sort: AAX < AU < CLAP < LV2 < VST < VST3
                }
                let comparison = a.name.localizedStandardCompare(b.name)
                return manualAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
            }
        case .publisher:
            sorted = rows.sorted { manualAscending ? ($0.publisher < $1.publisher) : ($0.publisher > $1.publisher) }
        case .type:
            sorted = rows.sorted { manualAscending ? ($0.type < $1.type) : ($0.type > $1.type) }
        case .style:
            sorted = rows.sorted { manualAscending ? ($0.style < $1.style) : ($0.style > $1.style) }
        case .version:
            sorted = sortByVersionFast(rows, ascending: manualAscending)
        case .license:
            // BUGFIX: License sorting removed to prevent sync queue blocking
            // Fallback to name sorting with natural sort order
            sorted = rows.sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return manualAscending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
            }
        case .date:
            sorted = sortByDateFast(rows, ascending: manualAscending)
        case .size:
            sorted = sortBySizeFast(rows, ascending: manualAscending)
        case .requirement:
            sorted = rows.sorted { manualAscending ? ($0.runtimeRequirement < $1.runtimeRequirement) : ($0.runtimeRequirement > $1.runtimeRequirement) }
        case .obsolete:
            sorted = rows.sorted { manualAscending ? ($0.obsoleteText < $1.obsoleteText) : ($0.obsoleteText > $1.obsoleteText) }
        case .missing:
            sorted = rows.sorted { manualAscending ? ($0.missingText < $1.missingText) : ($0.missingText > $1.missingText) }
        case .track:
            sorted = rows.sorted { manualAscending ? (($0.trackName ?? "") < ($1.trackName ?? "")) : (($0.trackName ?? "") > ($1.trackName ?? "")) }
        case .notes:
            let notesManager = NotesManager.shared
            sorted = rows.sorted { a, b in
                let noteA = notesManager.getNote(for: a.path)
                let noteB = notesManager.getNote(for: b.path)
                return manualAscending ? (noteA < noteB) : (noteA > noteB)
            }
        case .path:
            sorted = rows.sorted { manualAscending ? ($0.path < $1.path) : ($0.path > $1.path) }
        }

        AppLogger.debug("computeDisplayedRows(): Updating with \(sorted.count) rows (was \(lastRowsCount))")

        // CRITICAL: Update cache and tracking variables
        cachedDisplayedRows = sorted
        lastManualSortKey = manualSortKey
        lastManualAscending = manualAscending
        lastRowsCount = rows.count

        AppLogger.info("✅ Cache updated: cachedDisplayedRows now has \(cachedDisplayedRows.count) sorted rows")

        // Log first 5 plugin names to verify sort
        if sorted.count > 0 {
            let first5 = sorted.prefix(5).map { $0.name }.joined(separator: ", ")
            AppLogger.info("📋 First 5 plugins: \(first5)")
        }

        // BUGFIX: Global cache disabled - was returning stale data after search
        // TableCache.shared.store(sorted, for: cacheKey)

        // Update pagination with sorted data
        pagination.updateItems(sorted)

        AppLogger.logTableUpdate(
            source: "computeDisplayedRows",
            totalRows: sorted.count,
            displayedRows: displayedRows.count,
            sortKey: manualSortKey.rawValue,
            ascending: manualAscending
        )
        AppLogger.info("Pagination enabled: \(pagination.isEnabled), page size: \(pagination.pageSize)")

        // Preload adjacent pages for smooth scrolling
        if PaginationConfig.preloadAdjacentPages {
            pagination.preloadAdjacentPages()
        }
    }

    private func updatePathWidth() {
        let baseWidth: CGFloat = 600
        // Scale more aggressively - add 20pt for each font size point
        let additionalWidth = prefs.uiFontSizeOffset * 20
        wPath = baseWidth + additionalWidth
    }

    private func moveSelection(delta: Int, extendingSelection: Bool = false, scrollProxy: ScrollViewProxy? = nil) {
        // Ensure we have rows to select
        guard !displayedRows.isEmpty else { return }

        if extendingSelection {
            // SHIFT+ARROW: Extend/contract selection from anchor point
            // Find or establish the anchor point (this stays fixed)
            let anchor: Int
            if let existing = lastAnchorIndex, existing >= 0, existing < displayedRows.count {
                anchor = existing
            } else {
                // No anchor set - establish one from current selection
                if !macSelection.isEmpty {
                    let selectedIndices = displayedRows.enumerated()
                        .filter { macSelection.contains($0.element.id) }
                        .map { $0.offset }
                    // Use first selected item as anchor
                    anchor = selectedIndices.min() ?? 0
                } else {
                    // No selection at all - start from top or bottom
                    anchor = delta > 0 ? 0 : displayedRows.count - 1
                }
                lastAnchorIndex = anchor
                lastEdgeIndex = anchor
            }

            // Find the current edge (the moving end of selection)
            let currentEdge: Int
            if let existing = lastEdgeIndex, existing >= 0, existing < displayedRows.count {
                // Use the tracked edge
                currentEdge = existing
            } else if !macSelection.isEmpty {
                // Fallback: find edge from selection
                let selectedIndices = displayedRows.enumerated()
                    .filter { macSelection.contains($0.element.id) }
                    .map { $0.offset }
                // Edge is the item furthest from anchor
                if anchor <= (selectedIndices.max() ?? anchor) {
                    currentEdge = selectedIndices.max() ?? anchor
                } else {
                    currentEdge = selectedIndices.min() ?? anchor
                }
            } else {
                currentEdge = anchor
            }

            // Move the edge by delta
            let newEdge = min(max(currentEdge + delta, 0), displayedRows.count - 1)

            // Store the new edge position
            lastEdgeIndex = newEdge

            // Select range from anchor to new edge
            let lower = min(anchor, newEdge)
            let upper = max(anchor, newEdge)
            let slice = displayedRows[lower...upper]
            macSelection = Set(slice.map { $0.id })
            selection = Array(slice)

            // Auto-scroll ONLY when new edge moves beyond visible area - SMOOTH CENTER ANCHOR
            if let proxy = scrollProxy {
                let edgeItem = displayedRows[newEdge]
                let now = Date()
                let timeSinceLastScroll = now.timeIntervalSince(lastScrollTime)
                lastScrollTime = now

                // Only scroll if we moved to a new position (edge changed)
                if newEdge != currentEdge {
                    // Use faster animation for rapid scrolling (< 100ms between keypresses)
                    if timeSinceLastScroll < 0.1 {
                        // Ultra-fast for rapid key repeats - keep selection centered
                        AnimationHelper.withAnimation(reduceMotion, .interpolatingSpring(stiffness: 500, damping: 50)) {
                            proxy.scrollTo(edgeItem.id, anchor: .center)
                        }
                    } else {
                        // Smooth spring for normal pace - keep selection centered
                        AnimationHelper.withSpringAnimation(reduceMotion) {
                            proxy.scrollTo(edgeItem.id, anchor: .center)
                        }
                    }
                }
            }

        } else {
            // REGULAR ARROW: Move single selection
            let currentIndex: Int
            if !macSelection.isEmpty {
                let selectedIndices = displayedRows.enumerated()
                    .filter { macSelection.contains($0.element.id) }
                    .map { $0.offset }
                // Use the edge in the direction we're moving
                if delta > 0 {
                    currentIndex = selectedIndices.max() ?? -1
                } else {
                    currentIndex = selectedIndices.min() ?? displayedRows.count
                }
            } else {
                // No selection: start from edge
                currentIndex = delta > 0 ? -1 : displayedRows.count
            }

            let newIndex = min(max(currentIndex + delta, 0), displayedRows.count - 1)

            // Prevent moving if already at boundary
            if (delta < 0 && currentIndex <= 0) || (delta > 0 && currentIndex >= displayedRows.count - 1) {
                return
            }

            let newItem = displayedRows[newIndex]
            macSelection = [newItem.id]
            selection = [newItem]
            // Set anchor and edge for future shift-selection
            lastAnchorIndex = newIndex
            lastEdgeIndex = newIndex

            // Auto-scroll ONLY when selection moves - SMOOTH CENTER ANCHOR
            if let proxy = scrollProxy, newIndex != currentIndex {
                let now = Date()
                let timeSinceLastScroll = now.timeIntervalSince(lastScrollTime)
                lastScrollTime = now

                // Use faster animation for rapid scrolling (< 100ms between keypresses)
                if timeSinceLastScroll < 0.1 {
                    // Ultra-fast for rapid key repeats - keep selection centered
                    AnimationHelper.withAnimation(reduceMotion, .interpolatingSpring(stiffness: 500, damping: 50)) {
                        proxy.scrollTo(newItem.id, anchor: .center)
                    }
                } else {
                    // Smooth spring for normal pace - keep selection centered
                    AnimationHelper.withSpringAnimation(reduceMotion) {
                        proxy.scrollTo(newItem.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: Header row (extracted to fix type-checking timeout)
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Rating header
            if prefs.showColumnRating {
                MacSortHeaderButton(title: "Rating", active: manualSortKey == .rating, ascending: manualSortKey == .rating ? manualAscending : false, width: wRating, height: headerHeight) {
                    if manualSortKey == .rating { manualAscending.toggle() } else { manualSortKey = .rating; manualAscending = false }
                    sortStatus = makeSortStatus()
                }
            }

            // Name header
            if prefs.showColumnName {
                MacColumnDivider(leftWidth: $wRating, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Name", active: manualSortKey == .name, ascending: manualAscending, width: wName, height: headerHeight) {
                    if manualSortKey == .name { manualAscending.toggle() } else { manualSortKey = .name; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Publisher header
            if prefs.showColumnPublisher {
                MacColumnDivider(leftWidth: $wName, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Publisher", active: manualSortKey == .publisher, ascending: manualAscending, width: wPublisher, height: headerHeight) {
                    if manualSortKey == .publisher { manualAscending.toggle() } else { manualSortKey = .publisher; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Type header
            if prefs.showColumnType {
                MacColumnDivider(leftWidth: $wPublisher, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Type", active: manualSortKey == .type, ascending: manualAscending, width: wType, height: headerHeight) {
                    if manualSortKey == .type { manualAscending.toggle() } else { manualSortKey = .type; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Style header
            if prefs.showColumnStyle {
                MacColumnDivider(leftWidth: $wType, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Style", active: manualSortKey == .style, ascending: manualAscending, width: wStyle, height: headerHeight) {
                    if manualSortKey == .style { manualAscending.toggle() } else { manualSortKey = .style; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Version header
            if prefs.showColumnVersion {
                MacColumnDivider(leftWidth: $wStyle, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Version", active: manualSortKey == .version, ascending: manualSortKey == .version ? manualAscending : true, width: wVersion, height: headerHeight) {
                    if manualSortKey == .version { manualAscending.toggle() } else { manualSortKey = .version; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // License header
            if prefs.showColumnLicense {
                MacColumnDivider(leftWidth: $wVersion, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "License", active: manualSortKey == .license, ascending: manualSortKey == .license ? manualAscending : true, width: wLicense, height: headerHeight) {
                    if manualSortKey == .license { manualAscending.toggle() } else { manualSortKey = .license; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Date header
            if prefs.showColumnDate {
                MacColumnDivider(leftWidth: $wLicense, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Date", active: manualSortKey == .date, ascending: manualSortKey == .date ? manualAscending : true, width: wDate, height: headerHeight) {
                    if manualSortKey == .date { manualAscending.toggle() } else { manualSortKey = .date; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Size header
            if prefs.showColumnSize {
                MacColumnDivider(leftWidth: $wDate, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Size", active: manualSortKey == .size, ascending: manualSortKey == .size ? manualAscending : true, width: wSize, height: headerHeight) {
                    if manualSortKey == .size { manualAscending.toggle() } else { manualSortKey = .size; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Requirement header
            if prefs.showColumnRequirement {
                MacColumnDivider(leftWidth: $wSize, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Requirement", active: manualSortKey == .requirement, ascending: manualSortKey == .requirement ? manualAscending : true, width: wRequirement, height: headerHeight) {
                    if manualSortKey == .requirement { manualAscending.toggle() } else { manualSortKey = .requirement; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Obsolete header
            if prefs.showColumnObsolete {
                MacColumnDivider(leftWidth: $wRequirement, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Obsolete", active: manualSortKey == .obsolete, ascending: manualSortKey == .obsolete ? manualAscending : true, width: wObsolete, height: headerHeight) {
                    if manualSortKey == .obsolete { manualAscending.toggle() } else { manualSortKey = .obsolete; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Missing header
            if prefs.showColumnMissing {
                MacColumnDivider(leftWidth: $wObsolete, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Missing", active: manualSortKey == .missing, ascending: manualSortKey == .missing ? manualAscending : true, width: wMissing, height: headerHeight) {
                    if manualSortKey == .missing { manualAscending.toggle() } else { manualSortKey = .missing; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Track header
            if prefs.showColumnTrack {
                MacColumnDivider(leftWidth: $wMissing, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Track", active: manualSortKey == .track, ascending: manualSortKey == .track ? manualAscending : true, width: wTrack, height: headerHeight) {
                    if manualSortKey == .track { manualAscending.toggle() } else { manualSortKey = .track; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Notes header
            if prefs.showColumnNotes {
                MacColumnDivider(leftWidth: $wTrack, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Notes", active: manualSortKey == .notes, ascending: manualSortKey == .notes ? manualAscending : true, width: wNotes, height: headerHeight) {
                    if manualSortKey == .notes { manualAscending.toggle() } else { manualSortKey = .notes; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // Path header
            if prefs.showColumnPath {
                MacColumnDivider(leftWidth: $wNotes, minWidth: minColWidth, height: rowDividerHeight)
                MacSortHeaderButton(title: "Path", active: manualSortKey == .path, ascending: manualSortKey == .path ? manualAscending : true, width: wPath, height: headerHeight) {
                    if manualSortKey == .path { manualAscending.toggle() } else { manualSortKey = .path; manualAscending = true }
                    sortStatus = makeSortStatus()
                }
            }

            // No divider after last column
            Spacer(minLength: 0)
        }
        .frame(height: headerHeight)
        .background(headerBackgroundColor)
    }

    // MARK: Table content (extracted to fix type-checking timeout)
    private var tableContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(displayedRows.enumerated()), id: \.element.id) { idx, row in
                                let zebra = idx % 2 == 0  // Enable zebra for both light and dark mode
                                OptimizedTableRow(
                                    row: row,
                                    columnWidths: ColumnWidths(
                                        wRating: wRating, wName: wName, wPublisher: wPublisher, wType: wType,
                                        wStyle: wStyle, wVersion: wVersion, wLicense: wLicense,
                                        wDate: wDate, wSize: wSize, wRequirement: wRequirement,
                                        wObsolete: wObsolete, wMissing: wMissing, wTrack: wTrack, wNotes: wNotes, wPath: wPath
                                    ),
                                    isSelected: macSelection.contains(row.id),
                                    zebra: zebra,
                                    onTap: {
                                        handleRowClick(row)
                                    },
                                    ownedPlugins: allPlugins,  // Pass ALL plugins for AI Suggestions
                                    prefs: prefs,
                                    onUninstall: {
                                        pluginsToUninstall = [row]
                                        showUninstallConfirmation = true
                                    },
                                    selectedPlugins: selection,  // Pass current selection
                                    showDetailPanel: $showDetailPanel,
                                    detailPanelTab: $detailPanelTab
                                )
                            }
                        }
                    .focusable(true)
                    .focused($isTableFocused)
                    .applyIfAvailableMac14FocusDisabled()
                    .onMoveCommand { direction in
                        #if os(macOS)
                        let shiftPressed = NSEvent.modifierFlags.contains(.shift)
                        #else
                        let shiftPressed = false
                        #endif

                        switch direction {
                        case .down: moveSelection(delta: 1, extendingSelection: shiftPressed, scrollProxy: proxy)
                        case .up:   moveSelection(delta: -1, extendingSelection: shiftPressed, scrollProxy: proxy)
                        default:    break
                        }
                    }
                }
            }
        }

    // MARK: Base scroll view
    private var baseScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                headerRow
                Divider()
                tableContent
            }
        }
    }

    // MARK: Scroll view with selection handlers
    private var scrollViewWithSelection: some View {
        baseScrollView
            .onChange(of: macSelection) { (ids: Set<UUID>) in
                selection = rows.filter { ids.contains($0.id) }
            }
            .onChange(of: selection) { (sel: [PluginItem]) in
                macSelection = Set(sel.map(\.id))
                // Auto-focus table when selection is made programmatically
                if !sel.isEmpty && !isTableFocused {
                    isTableFocused = true
                }
            }
    }

    // MARK: Scroll view with sort handlers
    private var scrollViewWithSorting: some View {
        scrollViewWithSelection
            .onChange(of: manualSortKey) { _ in
                computeDisplayedRows()
            }
            .onChange(of: manualAscending) { _ in
                computeDisplayedRows()
            }
            .onChange(of: rows.count) { newCount in
                // CRITICAL: Defer to next run loop to ensure rows array is updated
                AppLogger.debug("onChange(rows.count): \(newCount) rows detected")

                DispatchQueue.main.async {
                    AppLogger.debug("Computing sort with rows.count = \(self.rows.count)")
                    self.computeDisplayedRows()
                    AppLogger.debug("✅ Sort completed, cached: \(self.cachedDisplayedRows.count) rows")
                }
            }
    }

    // MARK: Scroll view with appearance handlers
    private var scrollViewWithAppearance: some View {
        scrollViewWithSorting
            .onAppear {
                loadTableState()  // Load saved column widths and sort preferences

                // Don't compute sort here - let onChange(of: rows.count) handle it
                // when data actually arrives
                sortStatus = makeSortStatus()
                updatePathWidth()
            }
            .onDisappear {
                saveTableState()  // Save column widths and sort preferences on exit
            }
            .onChange(of: prefs.uiFontSizeOffset) { _ in
                updatePathWidth()
            }
            .onChange(of: manualSortKey) { _ in
                saveTableState()  // Save when sort column changes
            }
            .onChange(of: manualAscending) { _ in
                saveTableState()  // Save when sort direction changes
            }
            // Save column widths when they change
            .onChange(of: wRating) { _ in saveTableState() }
            .onChange(of: wName) { _ in saveTableState() }
            .onChange(of: wPublisher) { _ in saveTableState() }
            .onChange(of: wType) { _ in saveTableState() }
            .onChange(of: wStyle) { _ in saveTableState() }
            .onChange(of: wVersion) { _ in saveTableState() }
            .onChange(of: wLicense) { _ in saveTableState() }
            .onChange(of: wDate) { _ in saveTableState() }
            .onChange(of: wSize) { _ in saveTableState() }
            .onChange(of: wRequirement) { _ in saveTableState() }
            .onChange(of: wObsolete) { _ in saveTableState() }
            .onChange(of: wMissing) { _ in saveTableState() }
            .onChange(of: wTrack) { _ in saveTableState() }
            .onChange(of: wNotes) { _ in saveTableState() }
            .onChange(of: wPath) { _ in saveTableState() }
            .scrollContentBackground(.hidden)
            .background(colorScheme == .light ? Color.white : Color.clear)
    }

    // MARK: Main content view with context menu and sheet
    private var mainContentView: some View {
        scrollViewWithAppearance
            .contextMenu(forSelectionType: UUID.self) { (selection: Set<UUID>) in
                let ids = selection.isEmpty ? macSelection : selection
                let selectedPlugins = rows.filter { ids.contains($0.id) }
                let isMultiSelect = selectedPlugins.count > 1

                if isMultiSelect {
                    // Bulk editing menu for multiple selections
                    Menu("Set Rating") {
                        ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                            Button("\(rating) Star\(rating == 1 ? "" : "s")") {
                                applyBulkRating(rating, to: selectedPlugins)
                            }
                        }
                        Divider()
                        Button("Clear Ratings") {
                            applyBulkRating(0, to: selectedPlugins)
                        }
                    }

                    Menu("Add Tag") {
                        Button("Add Custom Tag...") {
                            showBulkTagPrompt(for: selectedPlugins)
                        }
                        Divider()
                        let commonTags = ["favorite", "mixing", "mastering", "vocal", "guitar", "effects", "dynamics", "eq", "reverb", "delay"]
                        ForEach(commonTags, id: \.self) { tag in
                            Button(tag.capitalized) {
                                applyBulkTag(tag, to: selectedPlugins)
                            }
                        }
                    }

                    Menu("Edit Metadata") {
                        Button("Set Publisher...") {
                            showBulkPublisherPrompt(for: selectedPlugins)
                        }
                        Button("Set Version...") {
                            showBulkVersionPrompt(for: selectedPlugins)
                        }
                        Button("Set Style...") {
                            showBulkStylePrompt(for: selectedPlugins)
                        }
                        Divider()
                        Button("Clear All Metadata") {
                            clearBulkMetadata(for: selectedPlugins)
                        }
                    }

                    Button("Add Notes...") {
                        showBulkNotesPrompt(for: selectedPlugins)
                    }

                    Divider()
                }

                Button("Uninstall\(isMultiSelect ? " All (\(selectedPlugins.count))..." : "...")") {
                    pluginsToUninstall = selectedPlugins
                    showUninstallConfirmation = true
                }
                .disabled(selectedPlugins.isEmpty)

                Divider()

                Button("Show in Finder") {
                    revealInFinder(ids: ids)
                }
            }
            .background(FadingScrollbarConfigurator())
            .sheet(isPresented: $showUninstallConfirmation) {
                UninstallConfirmationView(
                    plugins: pluginsToUninstall,
                    onComplete: { _ in
                        // Refresh the plugin list after uninstall
                        onPluginsDeleted?()

                        // Clear selection
                        macSelection.removeAll()
                        selection.removeAll()
                    }
                )
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            mainContentView

            // Pagination controls (only shown when enabled)
            if pagination.isEnabled {
                MacPaginationControls(pagination: pagination)
            }
        }
    }

    private struct MacSortHeaderButton: View {
        let title: String
        let active: Bool
        let ascending: Bool
        let width: CGFloat
        let height: CGFloat
        let action: () -> Void

        @EnvironmentObject private var prefs: Preferences
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Button(action: action) {
                HStack(spacing: 0) {
                    HStack(spacing: 4) {  // Inner HStack with controlled spacing
                        Text(title)
                            .font(.system(size: prefs.scaledSize(13)))
                            .fontWeight(active ? .bold : (prefs.highContrastMode ? .semibold : .regular))
                        if active {
                            Image(systemName: ascending ? "arrow.up" : "arrow.down")
                                .font(.system(size: prefs.scaledSize(10)))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .frame(width: width - 20, alignment: .leading)  // Leave more room on the right
                    .padding(.leading, 6)

                    Spacer()  // Push everything left, away from the divider
                }
                .frame(width: width)
                .frame(height: height)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private struct MacNonSortableHeader: View {
        let title: String
        let width: CGFloat
        let height: CGFloat

        @EnvironmentObject private var prefs: Preferences

        var body: some View {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: prefs.scaledSize(13)))
                    .fontWeight(prefs.highContrastMode ? .semibold : .regular)
                    .frame(width: width - 20, alignment: .leading)
                    .padding(.leading, 6)

                Spacer()
            }
            .frame(width: width)
            .frame(height: height)
        }
    }

    private struct MacColumnDivider: View {
        @Binding var leftWidth: CGFloat
        let minWidth: CGFloat
        let height: CGFloat
        let hitWidth: CGFloat = 8
        @State private var hovering: Bool = false

        var body: some View {
            ZStack {
                // Visible divider - matches TableDivider exactly
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 4, height: height)
                    .padding(.horizontal, 2)
                
                // Invisible drag area
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8, height: height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newWidth = max(minWidth, leftWidth + value.translation.width)
                                leftWidth = newWidth
                            }
                    )
                    #if os(macOS)
                    .onHover { isHovering in
                        hovering = isHovering
                        if isHovering {
                            NSCursor.resizeLeftRight.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    #endif
            }
        }
    }
}

// MARK: - Optimized Table Components

// Helper function to get color for plugin type (matching bar graph colors)
private func colorForPluginType(_ type: String) -> Color {
    switch type.uppercased() {
    case "AU":   return .blue
    case "VST":  return .green
    case "VST3": return .teal
    case "AAX":  return .purple
    case "CLAP": return .orange
    case "LV2":  return .gray
    case "OBSLT", "OBSOLETE": return .red
    default:     return .secondary
    }
}

private struct ColumnWidths {
    let wRating: CGFloat
    let wName: CGFloat
    let wPublisher: CGFloat
    let wType: CGFloat
    let wStyle: CGFloat
    let wVersion: CGFloat
    let wLicense: CGFloat
    let wDate: CGFloat
    let wSize: CGFloat
    let wRequirement: CGFloat
    let wObsolete: CGFloat
    let wMissing: CGFloat
    let wTrack: CGFloat
    let wNotes: CGFloat
    let wPath: CGFloat
}

private struct OptimizedTableRow: View {
    let row: PluginItem
    let columnWidths: ColumnWidths
    let isSelected: Bool
    let zebra: Bool
    let onTap: () -> Void
    let ownedPlugins: [PluginItem]
    let prefs: Preferences
    let onUninstall: () -> Void
    let selectedPlugins: [PluginItem]  // Add selection info
    @Binding var showDetailPanel: Bool
    @Binding var detailPanelTab: DetailTab

    @Environment(\.colorScheme) private var colorScheme
    @State private var showTagsEditor = false
    @State private var heritageWindow: NSWindow?
    // PERFORMANCE: Use direct references instead of @StateObject for singletons
    // This eliminates 10,572 unnecessary allocations (4 per row × 2,643 rows)
    private let notesManager = NotesManager.shared
    private let ratingsManager = RatingsManager.shared
    private let metadataManager = MetadataManager.shared
    private let tagsManager = TagsManager.shared
    private let enrichmentService = PluginEnrichmentService.shared

    private var zebraColor: Color {
        if prefs.appearance == .space {
            return Color.white.opacity(0.08)  // 8% grey for Space mode only
        } else if colorScheme == .dark {
            return Color.white.opacity(0.03)  // Very subtle white for dark mode
        } else {
            return Color.black.opacity(0.05)  // Existing light mode color
        }
    }

    private func checkForUpdate(plugin: PluginItem) {
        let publisher = plugin.publisher.lowercased()
        let pluginName = plugin.name

        // Try to construct direct developer URLs for known publishers
        var directURL: URL?

        // Common developer website patterns
        if publisher.contains("eventide") {
            directURL = URL(string: "https://www.eventideaudio.com/downloads")
        } else if publisher.contains("avid") {
            directURL = URL(string: "https://www.avid.com/plugins")
        } else if publisher.contains("waves") {
            directURL = URL(string: "https://www.waves.com/downloads")
        } else if publisher.contains("fabfilter") {
            directURL = URL(string: "https://www.fabfilter.com/download")
        } else if publisher.contains("native instruments") {
            directURL = URL(string: "https://www.native-instruments.com/en/products")
        } else if publisher.contains("izotope") {
            directURL = URL(string: "https://www.izotope.com/en/products.html")
        } else if publisher.contains("slate digital") {
            directURL = URL(string: "https://slatedigital.com/")
        } else if publisher.contains("universal audio") || publisher.contains("ua") {
            directURL = URL(string: "https://www.uaudio.com/uad-plugins.html")
        } else if publisher.contains("softube") {
            directURL = URL(string: "https://www.softube.com/products")
        } else if publisher.contains("plugin alliance") {
            directURL = URL(string: "https://www.plugin-alliance.com/en/products.html")
        } else if publisher.contains("soundtoys") {
            directURL = URL(string: "https://www.soundtoys.com/")
        } else if publisher.contains("valhalla") {
            directURL = URL(string: "https://valhalladsp.com/")
        }

        // If we found a direct URL, use it; otherwise fall back to web search
        if let url = directURL {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: Regular Google search (not "I'm Feeling Lucky")
            let searchQuery = "\(plugin.publisher) \(pluginName) plugin download"
            guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") else {
                return
            }
            NSWorkspace.shared.open(searchURL)
        }
    }

    // MARK: Bulk editing operations (for context menu)
    private func applyBulkRating(_ rating: Int, to plugins: [PluginItem]) {
        for plugin in plugins {
            ratingsManager.setRating(forName: plugin.name, rating: rating)
        }
        print("⭐ Set rating \(rating) for \(plugins.count) plugins")
    }

    private func applyBulkTag(_ tag: String, to plugins: [PluginItem]) {
        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTag.isEmpty else { return }

        for plugin in plugins {
            tagsManager.addTag(normalizedTag, to: plugin.path)
        }
        print("🏷️ Added tag '\(normalizedTag)' to \(plugins.count) plugins")
    }

    private func showBulkTagPrompt(for plugins: [PluginItem]) {
        let alert = NSAlert()
        alert.messageText = "Add Tag to \(plugins.count) Plugins"
        alert.informativeText = "Enter a tag to add to all selected plugins:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Enter tag name..."
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            applyBulkTag(input.stringValue, to: plugins)
        }
    }

    private func showBulkPublisherPrompt(for plugins: [PluginItem]) {
        // Get current publishers from selected plugins
        let currentPublishers = Set(plugins.map { metadataManager.getDisplayPublisher(for: $0) })
        let placeholderText: String
        if currentPublishers.count == 1, let publisher = currentPublishers.first {
            placeholderText = "Current: \(publisher)"
        } else {
            placeholderText = "Multiple values: \(currentPublishers.prefix(3).joined(separator: ", "))\(currentPublishers.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Publisher for \(plugins.count) Plugins"
        alert.informativeText = "Enter publisher name to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let publisher = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !publisher.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.publisher = publisher
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set publisher '\(publisher)' for \(plugins.count) plugins")
        }
    }

    private func showBulkVersionPrompt(for plugins: [PluginItem]) {
        // Get current versions from selected plugins
        let currentVersions = Set(plugins.map { metadataManager.getDisplayVersion(for: $0) })
        let placeholderText: String
        if currentVersions.count == 1, let version = currentVersions.first {
            placeholderText = "Current: \(version)"
        } else {
            placeholderText = "Multiple values: \(currentVersions.prefix(3).joined(separator: ", "))\(currentVersions.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Version for \(plugins.count) Plugins"
        alert.informativeText = "Enter version to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let version = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !version.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.version = version
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set version '\(version)' for \(plugins.count) plugins")
        }
    }

    private func showBulkStylePrompt(for plugins: [PluginItem]) {
        // Get current styles from selected plugins
        let currentStyles = Set(plugins.map { metadataManager.getDisplayStyle(for: $0) })
        let placeholderText: String
        if currentStyles.count == 1, let style = currentStyles.first {
            placeholderText = "Current: \(style)"
        } else {
            placeholderText = "Multiple values: \(currentStyles.prefix(3).joined(separator: ", "))\(currentStyles.count > 3 ? "..." : "")"
        }

        let alert = NSAlert()
        alert.messageText = "Set Style for \(plugins.count) Plugins"
        alert.informativeText = "Enter style/category to apply to all selected plugins:"
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = placeholderText
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let style = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !style.isEmpty else { return }

            for plugin in plugins {
                let override = metadataManager.getOverride(for: plugin.path) ?? PluginMetadataOverride()
                var updated = override
                updated.style = style
                metadataManager.setOverride(for: plugin.path, override: updated)
            }
            print("✏️ Set style '\(style)' for \(plugins.count) plugins")
        }
    }

    private func showBulkNotesPrompt(for plugins: [PluginItem]) {
        let alert = NSAlert()
        alert.messageText = "Add Notes to \(plugins.count) Plugins"
        alert.informativeText = "Enter notes to add to all selected plugins:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        input.isEditable = true
        input.isSelectable = true
        input.font = NSFont.systemFont(ofSize: 13)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        scrollView.documentView = input
        scrollView.hasVerticalScroller = true

        alert.accessoryView = scrollView
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let notes = input.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !notes.isEmpty else { return }

            for plugin in plugins {
                notesManager.setNote(for: plugin.path, note: notes)
            }
            print("📝 Added notes to \(plugins.count) plugins")
        }
    }

    private func clearBulkMetadata(for plugins: [PluginItem]) {
        for plugin in plugins {
            metadataManager.removeOverride(for: plugin.path)
        }
        print("🗑️ Cleared metadata for \(plugins.count) plugins")
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background layer - completely separate from content
            Rectangle()
                .fill(
                    isSelected
                    ? (prefs.appearance == .space
                        ? Color.accentColor.opacity(0.25)  // 10% brighter for Space mode
                        : Color.accentColor.opacity(0.15))
                    : (zebra
                        ? zebraColor
                        : (prefs.appearance == .space ? Color.black : Color.clear))
                )
                .frame(height: 32)

            // Content layer
            HStack(spacing: 0) {
                // Rating column
                if prefs.showColumnRating {
                    RatingCell(
                        pluginName: row.name,
                        pluginPublisher: row.publisher,
                        pluginPath: row.path,
                        allRows: ownedPlugins,
                        width: columnWidths.wRating,
                        ratingsManager: ratingsManager,
                        fontSize: prefs.scaledSize(13)
                    )
                }

                // Name column
                if prefs.showColumnName {
                    TableDivider()
                    NameCellWithBadge(
                        plugin: row,
                        width: columnWidths.wName
                    )
                }

                // Publisher column
                if prefs.showColumnPublisher {
                    TableDivider()
                    TableCell(text: metadataManager.getDisplayPublisher(for: row), width: columnWidths.wPublisher)
                        .id("\(row.path)-publisher-\(metadataManager.getDisplayPublisher(for: row))")
                }

                // Type column
                if prefs.showColumnType {
                    TableDivider()
                    ColoredTypeCell(type: row.type, width: columnWidths.wType)
                }

                // Style column
                if prefs.showColumnStyle {
                    TableDivider()
                    TableCell(text: metadataManager.getDisplayStyle(for: row), width: columnWidths.wStyle)
                        .id("\(row.path)-style-\(metadataManager.getDisplayStyle(for: row))")
                }

                // Version column
                if prefs.showColumnVersion {
                    TableDivider()
                    TableCell(text: metadataManager.getDisplayVersion(for: row), width: columnWidths.wVersion)
                        .id("\(row.path)-version-\(metadataManager.getDisplayVersion(for: row))")
                }

                // License column
                if prefs.showColumnLicense {
                    TableDivider()
                    TableCell(text: LicenseTypeHelper.getCachedLicenseType(for: row), width: columnWidths.wLicense)
                        .id("\(row.path)-license")
                }

                // Date column
                if prefs.showColumnDate {
                    TableDivider()
                    TableCell(text: row.dateString, width: columnWidths.wDate)
                }

                // Size column
                if prefs.showColumnSize {
                    TableDivider()
                    TableCell(text: row.sizeString, width: columnWidths.wSize)
                }

                // Requirement column
                if prefs.showColumnRequirement {
                    TableDivider()
                    TableCell(text: row.runtimeRequirement, width: columnWidths.wRequirement)
                }

                // Obsolete column
                if prefs.showColumnObsolete {
                    TableDivider()
                    TableCell(text: row.obsoleteText, width: columnWidths.wObsolete)
                }

                // Missing column
                if prefs.showColumnMissing {
                    TableDivider()
                    TableCell(text: row.missingText, width: columnWidths.wMissing)
                }

                // Track column
                if prefs.showColumnTrack {
                    TableDivider()
                    TableCell(text: row.trackName ?? "", width: columnWidths.wTrack)
                }

                // Notes column
                if prefs.showColumnNotes {
                    TableDivider()
                    NotesCell(
                        pluginPath: row.path,
                        width: columnWidths.wNotes,
                        notesManager: notesManager,
                        fontSize: prefs.scaledSize(13)
                    )
                }

                // Path column
                if prefs.showColumnPath {
                    TableDivider()
                    Text(row.path)
                        .font(.system(size: prefs.scaledSize(13)))
                        .padding(.leading, 6)
                        .frame(width: columnWidths.wPath, height: 32, alignment: .leading)
                        .help(row.path)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 32)
            .foregroundColor((row.missing || row.obsolete) ? Color.red : nil)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .font(.callout)
        .contentShape(Rectangle())
        .overlay(
            // High contrast row border
            Rectangle()
                .stroke(
                    prefs.highContrastMode
                        ? (colorScheme == .dark
                            ? Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3)
                            : Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.3))
                        : Color.clear,
                    lineWidth: prefs.highContrastMode ? 1 : 0
                )
        )
        .onTapGesture(perform: onTap)
        #if os(macOS)
        .contextMenu {
            let isMultiSelect = selectedPlugins.count > 1

            if isMultiSelect {
                // Multi-selection bulk editing menu
                Menu("Set Rating") {
                    ForEach([5, 4, 3, 2, 1], id: \.self) { rating in
                        Button("\(rating) Star\(rating == 1 ? "" : "s")") {
                            applyBulkRating(rating, to: selectedPlugins)
                        }
                    }
                    Divider()
                    Button("Clear Ratings") {
                        applyBulkRating(0, to: selectedPlugins)
                    }
                }

                Menu("Add Tag") {
                    Button("Add Custom Tag...") {
                        showBulkTagPrompt(for: selectedPlugins)
                    }
                    Divider()
                    let commonTags = ["favorite", "mixing", "mastering", "vocal", "guitar", "effects", "dynamics", "eq", "reverb", "delay"]
                    ForEach(commonTags, id: \.self) { tag in
                        Button(tag.capitalized) {
                            applyBulkTag(tag, to: selectedPlugins)
                        }
                    }
                }

                Menu("Edit Metadata") {
                    Button("Set Publisher...") {
                        showBulkPublisherPrompt(for: selectedPlugins)
                    }
                    Button("Set Version...") {
                        showBulkVersionPrompt(for: selectedPlugins)
                    }
                    Button("Set Style...") {
                        showBulkStylePrompt(for: selectedPlugins)
                    }
                    Divider()
                    Button("Clear All Metadata") {
                        clearBulkMetadata(for: selectedPlugins)
                    }
                }

                Button("Add Notes...") {
                    showBulkNotesPrompt(for: selectedPlugins)
                }

                Divider()

                Button("Uninstall All (\(selectedPlugins.count))...") {
                    onUninstall()
                }

                Divider()

                Button("Show in Finder") {
                    let urls = selectedPlugins.map { URL(fileURLWithPath: $0.path) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
            } else {
                // Single selection menu
                Button("AI Suggestions") {
                    // Open window directly - no dialog
                    openAISuggestionsWindow(ownershipFilter: .owned)
                }
                Divider()
                Button("Edit Metadata") {
                    onTap()  // Select the row first
                    detailPanelTab = .metadata
                    showDetailPanel = true
                }
                Button("License") {
                    onTap()  // Select the row first
                    detailPanelTab = .license
                    showDetailPanel = true
                }
                Button("Manage Tags...") {
                    showTagsEditor = true
                }
                Divider()
                Button("Show in Finder") {
                    let url = URL(fileURLWithPath: row.path)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Divider()
                Button("Check for Update") {
                    checkForUpdate(plugin: row)
                }
                Divider()
                Button("Uninstall") {
                    onUninstall()
                }
            }
        }
        .sheet(isPresented: $showTagsEditor) {
            TagsEditorSheet(plugin: row)
        }
        .onDrag {
            // If dragging a selected plugin, drag all selected plugins
            // Otherwise, just drag this one plugin
            let pluginsToDrag = isSelected ? selectedPlugins : [row]

            print("🚀 Starting drag of \(pluginsToDrag.count) plugin(s)")

            // Convert to drag data
            let pluginInfos = pluginsToDrag.map { plugin in
                PluginDragData.PluginInfo(
                    name: plugin.name,
                    publisher: plugin.publisher,
                    type: plugin.type,
                    path: plugin.path
                )
            }

            let pluginData = PluginDragData(plugins: pluginInfos)

            guard let encoded = try? JSONEncoder().encode(pluginData) else {
                print("❌ Failed to encode plugin data")
                return NSItemProvider()
            }

            print("✅ Encoded \(encoded.count) bytes of plugin data")

            let itemProvider = NSItemProvider()

            // Set suggested name to show count
            if pluginsToDrag.count > 1 {
                itemProvider.suggestedName = "\(pluginsToDrag.count) plugins"
            } else {
                itemProvider.suggestedName = pluginsToDrag[0].name
            }

            itemProvider.registerDataRepresentation(
                forTypeIdentifier: "com.vibeaudio.pluginreporter.plugin",
                visibility: .all
            ) { completion in
                print("📦 Provider asked to provide data")
                completion(encoded, nil)
                return nil
            }

            print("✅ Created NSItemProvider with identifier: com.vibeaudio.pluginreporter.plugin")

            return itemProvider
        }
        #endif
    }

    // MARK: - AI Suggestions Window

    private func showAISuggestionsModeChoice() {
        let hasHeritage = PluginHeritageDatabase.getHeritage(for: row.name) != nil

        let alert = NSAlert()
        alert.messageText = "What would you like to see?"

        if hasHeritage {
            alert.informativeText = "Explore '\(row.name)' - you own this plugin"
            alert.addButton(withTitle: "View Hit Songs Using This Plugin")
            alert.addButton(withTitle: "Discover Similar Plugins to Buy")
            alert.addButton(withTitle: "Find Similar Plugins I Already Own")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.informativeText = "Find plugins similar to '\(row.name)'"
            alert.addButton(withTitle: "Discover Similar Plugins to Buy")
            alert.addButton(withTitle: "Find Similar Plugins I Already Own")
            alert.addButton(withTitle: "Cancel")
        }

        alert.alertStyle = .informational

        let response = alert.runModal()

        if hasHeritage {
            switch response {
            case .alertFirstButtonReturn:
                print("👤 [User Choice] Selected: View Hit Songs (Heritage exists)")
                openHeritageOnlyWindow()
            case .alertSecondButtonReturn:
                print("👤 [User Choice] Selected: Discover Similar Plugins (Don't Own)")
                openAISuggestionsWindow(ownershipFilter: .notOwned)
            case .alertThirdButtonReturn:
                print("👤 [User Choice] Selected: Find Owned Alternatives")
                openAISuggestionsWindow(ownershipFilter: .owned)
                default:
                print("👤 [User Choice] Cancelled")
            }
        } else {
            switch response {
            case .alertFirstButtonReturn:
                print("👤 [User Choice] Selected: Discover Similar Plugins (No heritage)")
                openAISuggestionsWindow(ownershipFilter: .notOwned)
            case .alertSecondButtonReturn:
                print("👤 [User Choice] Selected: Find Owned Alternatives (No heritage)")
                openAISuggestionsWindow(ownershipFilter: .owned)
                default:
                print("👤 [User Choice] Cancelled")
            }
        }
    }

    private func openAISuggestionsWindow(ownershipFilter: OwnershipFilter = .owned) {
        print("📊 [MacPluginTable Row] Opening AI Suggestions with \(ownedPlugins.count) owned plugins")
        print("   Plugin: '\(row.name)', Style: '\(row.style)', Publisher: '\(row.publisher)'")
        AISuggestionsWindowManager.shared.openOrUpdateWindow(
            plugin: row,
            ownedPlugins: ownedPlugins,
            ownershipFilter: ownershipFilter
        )
    }

    private func openHeritageOnlyWindow() {
        // Close existing window if any
        heritageWindow?.close()

        if let heritage = PluginHeritageDatabase.getHeritage(for: row.name) {
            let hostingView = NSHostingView(
                rootView: NavigationStack {
                    HeritageDetailView(heritage: heritage, pluginName: row.name)
                }
            )

            hostingView.autoresizingMask = [.width, .height]
            hostingView.translatesAutoresizingMaskIntoConstraints = true

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )

            window.contentView = hostingView
            window.title = "Heritage - \(row.name)"
            window.minSize = NSSize(width: 600, height: 500)
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true

            heritageWindow = window

            window.center()
            window.makeKeyAndOrderFront(nil)
        } else {
            // Show "No Heritage Data" window
            let hostingView = NSHostingView(
                rootView: NavigationStack {
                    VStack(spacing: 20) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Heritage Data")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("'\(row.name)' doesn't have heritage information yet.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Heritage data includes famous recordings, hit songs, and the engineers who used this plugin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Close") {
                            heritageWindow?.close()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Heritage")
                }
            )

            hostingView.autoresizingMask = [.width, .height]
            hostingView.translatesAutoresizingMaskIntoConstraints = true

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.contentView = hostingView
            window.title = "Heritage - \(row.name)"
            window.minSize = NSSize(width: 400, height: 300)
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true

            heritageWindow = window

            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

private struct TableCell: View {
    let text: String
    let width: CGFloat
    var truncationMode: Text.TruncationMode = .tail
    var lineLimit: Int? = 1

    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: prefs.scaledSize(13)))
            .fontWeight(prefs.highContrastMode ? .semibold : .regular)
            .lineLimit(lineLimit)
            .truncationMode(truncationMode)
            .padding(.leading, 6)
            .frame(width: width, height: 32, alignment: .leading)
    }
}

private struct NameCellWithBadge: View {
    let plugin: PluginItem
    let width: CGFloat

    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text(plugin.name)
                .font(.system(size: prefs.scaledSize(13)))
                .fontWeight(prefs.highContrastMode ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .frame(width: width, height: 32, alignment: .leading)
    }
}

private struct ColoredTypeCell: View {
    let type: String
    let width: CGFloat

    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    // Fixed badge width to match CLAP (the widest plugin type)
    private let badgeWidth: CGFloat = 52

    var body: some View {
        HStack(spacing: 4) {
            Text(type)
                .font(.system(size: prefs.scaledSize(12), weight: .semibold))
                .foregroundColor(prefs.highContrastMode ? colorForPluginType(type) : colorForPluginType(type))
                .frame(width: badgeWidth, height: 20)  // Fixed uniform size
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colorForPluginType(type).opacity(prefs.highContrastMode ? 0.3 : 0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(colorForPluginType(type), lineWidth: prefs.highContrastMode ? 2 : 0)
                )
        }
        .padding(.leading, 6)
        .frame(width: width, height: 32, alignment: .leading)
    }
}

private struct TableDivider: View {
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dividerColor = prefs.highContrastMode
            ? (colorScheme == .dark ? Color(red: 0.4, green: 0.4, blue: 0.4) : Color(red: 0.6, green: 0.6, blue: 0.6))
            : Color(NSColor.separatorColor)

        Rectangle()
            .fill(dividerColor)
            .frame(width: prefs.highContrastMode ? 2 : 4, height: 32)
            .padding(.horizontal, prefs.highContrastMode ? 1 : 2)
    }
}

// MARK: - Plugin Image Cell

private struct PluginImageCell: View {
    let thumbnailUrl: String?
    let screenshotUrl: String?
    let pluginName: String
    let width: CGFloat

    var body: some View {
        Group {
            if let urlString = thumbnailUrl ?? screenshotUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 28, height: 28)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 28)
                    case .failure:
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .frame(width: width, height: 32, alignment: .center)
        .help(pluginName)
    }
}

// MARK: - Extracted Components
// View extension moved to: Extensions/ViewExtensions+Table.swift
// FadingScrollbarConfigurator moved to: Components/FadingScrollbar.swift
// NotesCell moved to: Components/TableCells/NotesCell.swift
// RatingCell moved to: Components/TableCells/RatingCell.swift
// MetadataEditorSheet moved to: Views/Sheets/MetadataEditorSheet.swift
// TagsEditorSheet moved to: Views/Sheets/TagsEditorSheet.swift

#endif
