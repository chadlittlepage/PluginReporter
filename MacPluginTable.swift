import SwiftUI
import Foundation
#if os(macOS)
import AppKit

struct VersionCell: View {
    let version: String
    var body: some View { Text(version) }
}

struct DateCell: View {
    let text: String
    var body: some View { Text(text) }
}

struct SizeCell: View {
    let text: String
    var body: some View { Text(text) }
}

@MainActor struct MacPluginTable: View {
    let rows: [PluginItem]
    @Binding var selection: [PluginItem]
    @Binding var sortStatus: String

    @State private var macSelection = Set<UUID>()
    @State private var lastAnchorIndex: Int? = nil
    @State private var lastEdgeIndex: Int? = nil  // Track the moving edge separately
    @State private var lastScrollTime: Date = .distantPast
//    @State private var sortOrder: [SortDescriptor<PluginItem>] = []

    // SPEED: Cache sorted rows to avoid re-sorting on every render
    @State private var cachedDisplayedRows: [PluginItem] = []
    @State private var lastManualSortKey: SortKey? = nil
    @State private var lastManualAscending: Bool = true
    @State private var lastRowsCount: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var prefs: Preferences

    // MARK: Resizable column widths - Set to match user's preferred layout
    @State private var wName: CGFloat = 190        // Wider for plugin names
    @State private var wPublisher: CGFloat = 120   // Good for most publisher names
    @State private var wType: CGFloat = 60         // Narrower since types are short
    @State private var wStyle: CGFloat = 100       // For plugin category/style
    @State private var wVersion: CGFloat = 80      // Adequate for version numbers
    @State private var wArch: CGFloat = 120        // Good for "Apple, Intel 64" etc
    @State private var wDate: CGFloat = 100        // Sufficient for dates
    @State private var wSize: CGFloat = 70         // Narrower for file sizes
    @State private var wRequirement: CGFloat = 110 // Good for "Universal" etc
    @State private var wObsolete: CGFloat = 70     // Narrow for Yes/No
    @State private var wPath: CGFloat = 300        // Narrower so vertical scrollbar sits near regular columns
    private let dividerWidth: CGFloat = 1
    private let minColWidth: CGFloat = 30          // Allow columns to squeeze much narrower

    // MARK: Header background color to match search field
    private var headerBackgroundColor: Color {
        // Space mode: match iOS/iPadOS dark gray
        if prefs.appearance.usesTrueBlack {
            return Color(red: 28/255, green: 28/255, blue: 30/255)
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
    enum SortKey: String, CaseIterable, Identifiable { case name, publisher, type, style, version, arch, date, size, requirement, obsolete, path; var id: String { rawValue } }
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

    private func defaultSorted(_ input: [PluginItem]) -> [PluginItem] {
        return input.sorted { (a: PluginItem, b: PluginItem) -> Bool in
            if a.name != b.name { return a.name < b.name }
            return a.versionSortKey < b.versionSortKey
        }
    }

    private func applySort(_ input: [PluginItem], using order: [SortDescriptor<PluginItem>]) -> [PluginItem] {
        return input.sorted(using: order)
    }
    
    private func applyPrettySort(_ input: [PluginItem], using order: [SortDescriptor<PluginItem>]) -> [PluginItem] {
        guard !order.isEmpty else { return defaultSorted(input) }
        return input.sorted(using: order)
    }
    
    private func sortRows(_ input: [PluginItem], by order: [SortDescriptor<PluginItem>]) -> [PluginItem] {
        guard let first = order.first else { return defaultSorted(input) }
        let d = String(describing: first).lowercased()
        let ascending = !d.contains("reverse")
        if d.contains("datestring") {
            return input.sorted { a, b in ascending ? (a.tableDateSortKey < b.tableDateSortKey) : (a.tableDateSortKey > b.tableDateSortKey) }
        } else if d.contains("sizestring") {
            return input.sorted { a, b in ascending ? (a.sizeBytesSortKey < b.sizeBytesSortKey) : (a.sizeBytesSortKey > b.sizeBytesSortKey) }
        } else if d.contains("version") { // covers both version and versionSortKey
            return input.sorted { a, b in ascending ? (a.versionSortKey < b.versionSortKey) : (a.versionSortKey > b.versionSortKey) }
        } else {
            return input.sorted(using: order)
        }
    }
    
    private func revealInFinder(ids: Set<UUID>) {
        #if os(macOS)
        let urls = rows.filter { ids.contains($0.id) }.map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        #endif
    }
    
    private func makeSortStatus() -> String {
        let column: String
        switch manualSortKey {
        case .name: column = "Name"
        case .publisher: column = "Publisher"
        case .type: column = "Type"
        case .style: column = "Style"
        case .version: column = "Version"
        case .arch: column = "Arch"
        case .date: column = "Date"
        case .size: column = "Size"
        case .requirement: column = "Requirement"
        case .obsolete: column = "Obsolete"
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
        switch manualSortKey {
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
        case .path:
            sorted = rows.sorted { manualAscending ? ($0.path < $1.path) : ($0.path > $1.path) }
        }
        cachedDisplayedRows = sorted
        lastManualSortKey = manualSortKey
        lastManualAscending = manualAscending
        lastRowsCount = rows.count
    }

    // SPEED: Check if sort parameters changed
    private func sortChanged() -> Bool {
        manualSortKey != lastManualSortKey ||
        manualAscending != lastManualAscending ||
        rows.count != lastRowsCount
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
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Single clickable header row with arrows
                    HStack(spacing: 0) {
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

                    MacSortHeaderButton(title: "Path", active: manualSortKey == .path, ascending: manualSortKey == .path ? manualAscending : true, width: wPath, height: headerHeight) {
                        if manualSortKey == .path { manualAscending.toggle() } else { manualSortKey = .path; manualAscending = true }
                        sortStatus = makeSortStatus()
                    }
                        // No divider after last column
                        Spacer(minLength: 0)
                    }
                    .frame(height: headerHeight)
                    .background(headerBackgroundColor)

                    Divider()

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(displayedRows.enumerated()), id: \.element.id) { idx, row in
                                let zebra = idx % 2 == 0  // Enable zebra for both light and dark mode
                                OptimizedTableRow(
                                    row: row,
                                    columnWidths: ColumnWidths(
                                        wName: wName, wPublisher: wPublisher, wType: wType,
                                        wStyle: wStyle, wVersion: wVersion, wArch: wArch,
                                        wDate: wDate, wSize: wSize, wRequirement: wRequirement,
                                        wObsolete: wObsolete, wPath: wPath
                                    ),
                                    isSelected: macSelection.contains(row.id),
                                    zebra: zebra,
                                    onTap: {
                                        handleRowClick(row)
                                    },
                                    ownedPlugins: [],  // SPEED: AI service doesn't need all 2643 plugins!
                                    prefs: prefs
                                )
                            }
                        }
                    }
                    .focusable(true)
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
            .onChange(of: macSelection) { (ids: Set<UUID>) in
                selection = rows.filter { ids.contains($0.id) }
            }
            .onChange(of: selection) { (sel: [PluginItem]) in
                macSelection = Set(sel.map(\.id))
            }
            .onChange(of: manualSortKey) { _ in
                if sortChanged() {
                    computeDisplayedRows()
                }
            }
            .onChange(of: manualAscending) { _ in
                if sortChanged() {
                    computeDisplayedRows()
                }
            }
            .onChange(of: rows.count) { _ in
                computeDisplayedRows()
            }
            .onChange(of: rows) { _ in
                // Recompute whenever rows array changes at all
                computeDisplayedRows()
            }
            .onAppear {
                if cachedDisplayedRows.isEmpty {
                    computeDisplayedRows()
                }
                sortStatus = makeSortStatus()
                updatePathWidth()
            }
            .onChange(of: prefs.uiFontSizeOffset) { _ in
                updatePathWidth()
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .contextMenu(forSelectionType: UUID.self) { (selection: Set<UUID>) in
                Button("Show in Finder") {
                    revealInFinder(ids: selection.isEmpty ? macSelection : selection)
                }
            }
            }  // Close horizontal ScrollView
            .background(FadingScrollbarConfigurator())
        }  // Close outer VStack
    }  // Close body

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
    let wName: CGFloat
    let wPublisher: CGFloat
    let wType: CGFloat
    let wStyle: CGFloat
    let wVersion: CGFloat
    let wArch: CGFloat
    let wDate: CGFloat
    let wSize: CGFloat
    let wRequirement: CGFloat
    let wObsolete: CGFloat
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

    @Environment(\.colorScheme) private var colorScheme
    @State private var showAISuggestions = false

    private var zebraColor: Color {
        if colorScheme == .dark {
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
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background layer - completely separate from content
            Rectangle()
                .fill(
                    isSelected
                    ? Color.accentColor.opacity(0.15)
                    : (zebra ? zebraColor : Color.clear)
                )
                .frame(height: 32)

            // Content layer
            HStack(spacing: 0) {
                TableCell(text: row.name, width: columnWidths.wName)
                TableDivider()
                TableCell(text: row.publisher, width: columnWidths.wPublisher)
                TableDivider()
                ColoredTypeCell(type: row.type, width: columnWidths.wType)
                TableDivider()
                TableCell(text: row.style, width: columnWidths.wStyle)
                TableDivider()
                TableCell(text: row.version, width: columnWidths.wVersion)
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
                Text(row.path)
                    .font(.system(size: prefs.scaledSize(13)))
                    .padding(.leading, 6)
                    .frame(width: columnWidths.wPath, height: 32, alignment: .leading)
                    .help(row.path)
                Spacer(minLength: 0)
            }
            .frame(height: 32)
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .font(.callout)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        #if os(macOS)
        .contextMenu {
            Button("AI Suggestions") {
                showAISuggestions = true
            }
            Divider()
            Button("Check for Update") {
                checkForUpdate(plugin: row)
            }
            Divider()
            Button("Show in Finder") {
                let url = URL(fileURLWithPath: row.path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .sheet(isPresented: $showAISuggestions) {
            AISuggestionsView(plugin: row, ownedPlugins: ownedPlugins)
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

private extension View {
    @ViewBuilder
    func applyIfAvailableMac14FocusDisabled() -> some View {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled(true)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
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


#endif

