import SwiftUI
import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers

// MARK: - Plugin Drag Data

/// Data structure for dragging plugins to playlists
struct PluginDragData: Codable {
    let plugins: [PluginInfo]

    struct PluginInfo: Codable {
        let name: String
        let publisher: String
        let type: String
        let path: String
    }
}

@MainActor struct MacPluginTable: View {
    let rows: [PluginItem]
    @Binding var selection: [PluginItem]
    @Binding var sortStatus: String
    @Binding var showDetailPanel: Bool
    @Binding var detailPanelTab: DetailTab
    var onPluginsDeleted: (() -> Void)? = nil

    @State private var macSelection = Set<UUID>()
    @FocusState private var isTableFocused: Bool
    @State private var lastAnchorIndex: Int? = nil
    @State private var lastEdgeIndex: Int? = nil  // Track the moving edge separately
    @State private var lastScrollTime: Date = .distantPast

    // MARK: Uninstall state
    @State private var showUninstallConfirmation = false
    @State private var pluginsToUninstall: [PluginItem] = []

    // SPEED: Cache sorted rows to avoid re-sorting on every render
    @State private var cachedDisplayedRows: [PluginItem] = []
    @State private var lastManualSortKey: SortKey? = nil
    @State private var lastManualAscending: Bool = true
    @State private var lastRowsCount: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var prefs: Preferences

    // MARK: Resizable column widths - Set to match user's preferred layout
    @State private var wRating: CGFloat = 90       // For 5-star rating (first column)
    @State private var wName: CGFloat = 160        // Wider for plugin names
    @State private var wPublisher: CGFloat = 140   // Good for most publisher names
    @State private var wType: CGFloat = 60         // Narrower since types are short
    @State private var wStyle: CGFloat = 90        // For plugin category/style
    @State private var wVersion: CGFloat = 90      // Adequate for version numbers
    @State private var wLicense: CGFloat = 80      // For license type (Serial/iLok)
    @State private var wArch: CGFloat = 120        // Good for "Apple, Intel 64" etc
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
    enum SortKey: String, CaseIterable, Identifiable { case rating, name, publisher, type, style, version, license, arch, date, size, requirement, obsolete, missing, track, notes, path; var id: String { rawValue } }
    @State private var manualSortKey: SortKey = .name
    @State private var manualAscending: Bool = true

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
        case .arch: column = "Arch"
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
    
    // SPEED: Return cached value directly
    private var displayedRows: [PluginItem] {
        cachedDisplayedRows
    }

    // SPEED: Compute sorted rows only when sort key or data changes
    private func computeDisplayedRows() {
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
            sorted = rows.sorted { manualAscending ? ($0.name < $1.name) : ($0.name > $1.name) }
        case .publisher:
            sorted = rows.sorted { manualAscending ? ($0.publisher < $1.publisher) : ($0.publisher > $1.publisher) }
        case .type:
            sorted = rows.sorted { manualAscending ? ($0.type < $1.type) : ($0.type > $1.type) }
        case .style:
            sorted = rows.sorted { manualAscending ? ($0.style < $1.style) : ($0.style > $1.style) }
        case .version:
            sorted = sortByVersionFast(rows, ascending: manualAscending)
        case .license:
            // PERFORMANCE: Use cached license type for 10x faster sorting
            sorted = rows.sorted { a, b in
                let licenseA = LicenseTypeHelper.getCachedLicenseType(for: a)
                let licenseB = LicenseTypeHelper.getCachedLicenseType(for: b)
                return manualAscending ? (licenseA < licenseB) : (licenseA > licenseB)
            }
        case .arch:
            sorted = rows.sorted { manualAscending ? ($0.architectures < $1.architectures) : ($0.architectures > $1.architectures) }
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
        cachedDisplayedRows = sorted
        lastManualSortKey = manualSortKey
        lastManualAscending = manualAscending
        lastRowsCount = rows.count
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
                        withAnimation(.interpolatingSpring(stiffness: 500, damping: 50)) {
                            proxy.scrollTo(edgeItem.id, anchor: .center)
                        }
                    } else {
                        // Smooth spring for normal pace - keep selection centered
                        withAnimation(.spring(response: 0.25, dampingFraction: 1.0)) {
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
                    withAnimation(.interpolatingSpring(stiffness: 500, damping: 50)) {
                        proxy.scrollTo(newItem.id, anchor: .center)
                    }
                } else {
                    // Smooth spring for normal pace - keep selection centered
                    withAnimation(.spring(response: 0.25, dampingFraction: 1.0)) {
                        proxy.scrollTo(newItem.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: Header row (extracted to fix type-checking timeout)
    private var headerRow: some View {
        HStack(spacing: 0) {
                        MacSortHeaderButton(title: "Rating", active: manualSortKey == .rating, ascending: manualSortKey == .rating ? manualAscending : false, width: wRating, height: headerHeight) {
                            if manualSortKey == .rating { manualAscending.toggle() } else { manualSortKey = .rating; manualAscending = false }
                            sortStatus = makeSortStatus()
                        }
                    MacColumnDivider(leftWidth: $wRating, minWidth: minColWidth, height: rowDividerHeight)

                        MacSortHeaderButton(title: "Name", active: manualSortKey == .name, ascending: manualAscending, width: wName, height: headerHeight) {
                            if manualSortKey == .name { manualAscending.toggle() } else { manualSortKey = .name; manualAscending = true }
                            sortStatus = makeSortStatus()
                        }
                    MacColumnDivider(leftWidth: $wName, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Publisher", active: manualSortKey == .publisher, ascending: manualAscending, width: wPublisher, height: headerHeight) {
                        if manualSortKey == .publisher { manualAscending.toggle() } else { manualSortKey = .publisher; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wPublisher, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Type", active: manualSortKey == .type, ascending: manualAscending, width: wType, height: headerHeight) {
                        if manualSortKey == .type { manualAscending.toggle() } else { manualSortKey = .type; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wType, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Style", active: manualSortKey == .style, ascending: manualAscending, width: wStyle, height: headerHeight) {
                        if manualSortKey == .style { manualAscending.toggle() } else { manualSortKey = .style; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wStyle, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Version", active: manualSortKey == .version, ascending: manualSortKey == .version ? manualAscending : true, width: wVersion, height: headerHeight) {
                        if manualSortKey == .version { manualAscending.toggle() } else { manualSortKey = .version; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wVersion, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "License", active: manualSortKey == .license, ascending: manualSortKey == .license ? manualAscending : true, width: wLicense, height: headerHeight) {
                        if manualSortKey == .license { manualAscending.toggle() } else { manualSortKey = .license; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wLicense, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Arch", active: manualSortKey == .arch, ascending: manualSortKey == .arch ? manualAscending : true, width: wArch, height: headerHeight) {
                        if manualSortKey == .arch { manualAscending.toggle() } else { manualSortKey = .arch; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wArch, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Date", active: manualSortKey == .date, ascending: manualSortKey == .date ? manualAscending : true, width: wDate, height: headerHeight) {
                        if manualSortKey == .date { manualAscending.toggle() } else { manualSortKey = .date; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wDate, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Size", active: manualSortKey == .size, ascending: manualSortKey == .size ? manualAscending : true, width: wSize, height: headerHeight) {
                        if manualSortKey == .size { manualAscending.toggle() } else { manualSortKey = .size; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wSize, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Requirement", active: manualSortKey == .requirement, ascending: manualSortKey == .requirement ? manualAscending : true, width: wRequirement, height: headerHeight) {
                        if manualSortKey == .requirement { manualAscending.toggle() } else { manualSortKey = .requirement; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wRequirement, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Obsolete", active: manualSortKey == .obsolete, ascending: manualSortKey == .obsolete ? manualAscending : true, width: wObsolete, height: headerHeight) {
                        if manualSortKey == .obsolete { manualAscending.toggle() } else { manualSortKey = .obsolete; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wObsolete, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Missing", active: manualSortKey == .missing, ascending: manualSortKey == .missing ? manualAscending : true, width: wMissing, height: headerHeight) {
                        if manualSortKey == .missing { manualAscending.toggle() } else { manualSortKey = .missing; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wMissing, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Track", active: manualSortKey == .track, ascending: manualSortKey == .track ? manualAscending : true, width: wTrack, height: headerHeight) {
                        if manualSortKey == .track { manualAscending.toggle() } else { manualSortKey = .track; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wTrack, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Notes", active: manualSortKey == .notes, ascending: manualSortKey == .notes ? manualAscending : true, width: wNotes, height: headerHeight) {
                        if manualSortKey == .notes { manualAscending.toggle() } else { manualSortKey = .notes; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                    MacColumnDivider(leftWidth: $wNotes, minWidth: minColWidth, height: rowDividerHeight)

                    MacSortHeaderButton(title: "Path", active: manualSortKey == .path, ascending: manualSortKey == .path ? manualAscending : true, width: wPath, height: headerHeight) {
                        if manualSortKey == .path { manualAscending.toggle() } else { manualSortKey = .path; manualAscending = true }
                        sortStatus = makeSortStatus()
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
                                        wStyle: wStyle, wVersion: wVersion, wLicense: wLicense, wArch: wArch,
                                        wDate: wDate, wSize: wSize, wRequirement: wRequirement,
                                        wObsolete: wObsolete, wMissing: wMissing, wTrack: wTrack, wNotes: wNotes, wPath: wPath
                                    ),
                                    isSelected: macSelection.contains(row.id),
                                    zebra: zebra,
                                    onTap: {
                                        handleRowClick(row)
                                    },
                                    ownedPlugins: rows,  // Pass all rows for rating sync
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
            .onChange(of: rows.count) { _ in
                computeDisplayedRows()
            }
            .onChange(of: rows) { _ in
                computeDisplayedRows()
            }
    }

    // MARK: Scroll view with appearance handlers
    private var scrollViewWithAppearance: some View {
        scrollViewWithSorting
            .onAppear {
                if cachedDisplayedRows.isEmpty { computeDisplayedRows() }
                sortStatus = makeSortStatus()
                updatePathWidth()
            }
            .onChange(of: prefs.uiFontSizeOffset) { _ in
                updatePathWidth()
            }
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
                    onComplete: { result in
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

        var body: some View {
            Button(action: action) {
                HStack(spacing: 0) {
                    HStack(spacing: 4) {  // Inner HStack with controlled spacing
                        Text(title)
                            .font(.system(size: prefs.scaledSize(13)))
                            .fontWeight(active ? .bold : .regular)
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
    let wArch: CGFloat
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
    @State private var showAISuggestions = false
    @State private var showTagsEditor = false
    // PERFORMANCE: Use direct references instead of @StateObject for singletons
    // This eliminates 10,572 unnecessary allocations (4 per row × 2,643 rows)
    private let notesManager = NotesManager.shared
    private let ratingsManager = RatingsManager.shared
    private let metadataManager = MetadataManager.shared
    private let tagsManager = TagsManager.shared

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
                RatingCell(
                    pluginName: row.name,
                    pluginPublisher: row.publisher,
                    pluginPath: row.path,
                    allRows: ownedPlugins,
                    width: columnWidths.wRating,
                    ratingsManager: ratingsManager,
                    fontSize: prefs.scaledSize(13)
                )
                TableDivider()
                TableCell(text: row.name, width: columnWidths.wName)
                TableDivider()
                TableCell(text: metadataManager.getDisplayPublisher(for: row), width: columnWidths.wPublisher)
                    .id("\(row.path)-publisher-\(metadataManager.getDisplayPublisher(for: row))")
                TableDivider()
                ColoredTypeCell(type: row.type, width: columnWidths.wType)
                TableDivider()
                TableCell(text: metadataManager.getDisplayStyle(for: row), width: columnWidths.wStyle)
                    .id("\(row.path)-style-\(metadataManager.getDisplayStyle(for: row))")
                TableDivider()
                TableCell(text: metadataManager.getDisplayVersion(for: row), width: columnWidths.wVersion)
                    .id("\(row.path)-version-\(metadataManager.getDisplayVersion(for: row))")
                TableDivider()
                TableCell(text: LicenseTypeHelper.getCachedLicenseType(for: row), width: columnWidths.wLicense)
                    .id("\(row.path)-license")
                TableDivider()
                TableCell(text: row.architectures, width: columnWidths.wArch)
                TableDivider()
                TableCell(text: row.dateString, width: columnWidths.wDate)
                TableDivider()
                TableCell(text: row.sizeString, width: columnWidths.wSize)
                TableDivider()
                TableCell(text: row.runtimeRequirement, width: columnWidths.wRequirement)
                TableDivider()
                TableCell(text: row.obsoleteText, width: columnWidths.wObsolete)
                TableDivider()
                TableCell(text: row.missingText, width: columnWidths.wMissing)
                TableDivider()
                TableCell(text: row.trackName ?? "", width: columnWidths.wTrack)
                TableDivider()
                NotesCell(
                    pluginPath: row.path,
                    width: columnWidths.wNotes,
                    notesManager: notesManager,
                    fontSize: prefs.scaledSize(13)
                )
                TableDivider()
                Text(row.path)
                    .font(.system(size: prefs.scaledSize(13)))
                    .padding(.leading, 6)
                    .frame(width: columnWidths.wPath, height: 32, alignment: .leading)
                    .help(row.path)
                Spacer(minLength: 0)
            }
            .frame(height: 32)
            .foregroundColor((row.missing || row.obsolete) ? Color.red : nil)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .font(.callout)
        .contentShape(Rectangle())
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
                    showAISuggestions = true
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
        .sheet(isPresented: $showAISuggestions) {
            AISuggestionsView(plugin: row, ownedPlugins: ownedPlugins)
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
}

private struct TableCell: View {
    let text: String
    let width: CGFloat
    var truncationMode: Text.TruncationMode = .tail
    var lineLimit: Int? = 1

    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        Text(text)
            .font(.system(size: prefs.scaledSize(13)))
            .lineLimit(lineLimit)
            .truncationMode(truncationMode)
            .padding(.leading, 6)
            .frame(width: width, height: 32, alignment: .leading)
    }
}

private struct ColoredTypeCell: View {
    let type: String
    let width: CGFloat

    @EnvironmentObject private var prefs: Preferences

    // Fixed badge width to match CLAP (the widest plugin type)
    private let badgeWidth: CGFloat = 52

    var body: some View {
        HStack(spacing: 4) {
            Text(type)
                .font(.system(size: prefs.scaledSize(12), weight: .semibold))
                .foregroundColor(colorForPluginType(type))
                .frame(width: badgeWidth, height: 20)  // Fixed uniform size
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colorForPluginType(type).opacity(0.2))
                )
        }
        .padding(.leading, 6)
        .frame(width: width, height: 32, alignment: .leading)
    }
}

private struct TableDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: 4, height: 32)
            .padding(.horizontal, 2)
    }
}

extension View {
    @ViewBuilder
    func applyIfAvailableMac14FocusDisabled() -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Simple Fading Scrollbar

private struct FadingScrollbarConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = ConfigView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class ConfigView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }

            // Find and configure the ScrollView with retries
            for delay in [0.0, 0.2, 0.5] {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self.findAndConfigure()
                }
            }
        }

        func findAndConfigure() {
            guard let contentView = window?.contentView else { return }

            // Search for ALL ScrollViews (horizontal and vertical)
            var queue: [NSView] = [contentView]
            var configured = 0

            while !queue.isEmpty {
                let view = queue.removeFirst()

                if let scrollView = view as? NSScrollView {
                    // Configure with overlay style (auto-fading) for both horizontal and vertical
                    scrollView.scrollerStyle = .overlay
                    scrollView.autohidesScrollers = true // Let macOS handle fade

                    // Keep whatever scrollers it has (horizontal or vertical)
                    // Just make them overlay style

                    configured += 1
                    print("✅ Configured fading scrollbar #\(configured)")
                }

                queue.append(contentsOf: view.subviews)
            }

            if configured > 0 {
                print("✅ Total: Configured \(configured) scrollbar(s)")
            }
        }
    }
}

// MARK: - Notes Cell

private struct NotesCell: View {
    let pluginPath: String
    let width: CGFloat
    @ObservedObject var notesManager: NotesManager
    let fontSize: CGFloat

    @State private var isEditing = false
    @State private var editingText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if isEditing {
                TextField("Add notes...", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: fontSize))
                    .padding(.leading, 6)
                    .frame(width: width, height: 32, alignment: .leading)
                    .focused($isFocused)
                    .onSubmit {
                        saveNote()
                    }
                    .onAppear {
                        isFocused = true
                    }
            } else {
                let note = notesManager.getNote(for: pluginPath)
                Text(note.isEmpty ? "" : note)
                    .font(.system(size: fontSize))
                    .foregroundColor(note.isEmpty ? .secondary.opacity(0.5) : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
                    .frame(width: width, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing()
                    }
            }
        }
        .onChange(of: isFocused) { focused in
            if !focused && isEditing {
                saveNote()
            }
        }
    }

    private func startEditing() {
        editingText = notesManager.getNote(for: pluginPath)
        isEditing = true
    }

    private func saveNote() {
        notesManager.setNote(for: pluginPath, note: editingText)
        isEditing = false
    }
}

// MARK: - Rating Cell

private struct RatingCell: View {
    let pluginName: String
    let pluginPublisher: String
    let pluginPath: String
    let allRows: [PluginItem]
    let width: CGFloat
    @ObservedObject var ratingsManager: RatingsManager
    let fontSize: CGFloat

    var body: some View {
        let currentRating = ratingsManager.getRating(forName: pluginName)

        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    // Get the current rating
                    let current = ratingsManager.getRating(forName: pluginName)
                    let newRating = (current == star) ? 0 : star

                    // Set rating using plugin name - all formats will share this rating
                    ratingsManager.setRating(forName: pluginName, rating: newRating)
                }) {
                    Image(systemName: star <= currentRating ? "star.fill" : "star")
                        .font(.system(size: fontSize - 2))
                        .foregroundColor(star <= currentRating ? .yellow : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("Rate \(star) star\(star == 1 ? "" : "s")")
            }
        }
        .padding(.leading, 6)
        .frame(width: width, height: 32, alignment: .leading)
    }
}

// MARK: - Metadata Editor Sheet

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

// MARK: - Tags Editor Sheet

private struct TagsEditorSheet: View {
    let plugin: PluginItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tagsManager = TagsManager.shared

    @State private var currentTags: Set<String> = []
    @State private var newTag: String = ""

    var suggestedTags: [String] {
        return tagsManager.getSuggestedTags(for: plugin).prefix(12).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manage Tags")
                .font(.title)
                .fontWeight(.bold)

            Text(plugin.name)
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            // Current Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Tags")
                    .font(.headline)

                if currentTags.isEmpty {
                    Text("No tags yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(currentTags).sorted(), id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                        .font(.caption)
                                    Button(action: {
                                        currentTags.remove(tag)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
            }

            Divider()

            // Add New Tag
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Tag")
                    .font(.headline)

                HStack {
                    TextField("Type tag name...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addNewTag()
                        }

                    Button("Add") {
                        addNewTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            // Suggested Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested Tags")
                    .font(.headline)

                Text("Click to add")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(suggestedTags, id: \.self) { tag in
                            Button(action: {
                                currentTags.insert(tag)
                            }) {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .disabled(currentTags.contains(tag))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }

            Spacer()

            HStack {
                Button("Clear All") {
                    currentTags.removeAll()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveTags()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600, height: 550)
        .onAppear {
            currentTags = tagsManager.getTags(for: plugin.path)
        }
    }

    private func addNewTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tag.isEmpty else { return }
        currentTags.insert(tag)
        newTag = ""
    }

    private func saveTags() {
        tagsManager.setTags(currentTags, for: plugin.path)
    }
}

#endif

