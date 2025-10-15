import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Disambiguate project types in case of name collisions
typealias AppPluginItem = PluginItem
typealias AppPreferences = Preferences

struct ContentView: View {
    @EnvironmentObject private var scanner: PluginScanner
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var zoomState: ZoomState
    @StateObject private var appState = AppState()
    @State private var searchText: String = ""
    @State private var isExporting = false
    @State private var selectedRow: AppPluginItem.ID? = nil
    @FocusState private var searchFocused: Bool
    @State private var showFormatsPopover: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var didCollapseSidebar: Bool = false
    @State private var showOverlaySidebar: Bool = false
    @State private var sortStatus: String = "Sorted by: Name (ascending)"
    @State private var suppressAnimations: Bool = false
    @State private var showDetailSheet: Bool = false

    // Force immediate bar graph display
    @State private var forceBarGraphDisplay: Bool = true

    // INSTANT bar graph - cached counts (only updates on batch completion)
    @State private var cachedBarCounts = FormatCounts()
    @State private var lastBarUpdateCount = 0

    // REACTIVE: Filtered plugins that updates automatically
    @State private var displayedPlugins: [AppPluginItem] = []

    private func updateDisplayedPlugins() {
        let allPlugins = scanner.plugins.map(AppPluginItem.init)

        displayedPlugins = FastFilterEngine.filter(
            plugins: allPlugins,
            formats: prefs.selectedFormats,
            publishers: prefs.selectedPublishers,
            styles: prefs.selectedStyles,
            searchText: searchText
        )
    }

    private var appBG: Color {
        // Space mode: pure black background
        if prefs.appearance.usesTrueBlack {
            return Color.black
        }
        // Regular dark mode: dark gray (matching iOS/iPadOS)
        else if colorScheme == .dark {
            return Color(red: 28/255, green: 28/255, blue: 30/255)
        }
        // Light mode: medium gray
        else {
            return Color(red: 0.82, green: 0.82, blue: 0.84)
        }
    }

    // INSTANT bar graph with INSTANT fake results - shows immediately
    private var instantBarGraphWithResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            BarRow(label: "AU",    value: 25, fraction: 0.4, color: .blue)
            BarRow(label: "VST",   value: 18, fraction: 0.3, color: .green)  
            BarRow(label: "VST3",  value: 12, fraction: 0.2, color: .teal)
            BarRow(label: "AAX",   value: 8,  fraction: 0.15, color: .purple)
            BarRow(label: "CLAP",  value: 3,  fraction: 0.05, color: .orange)
            BarRow(label: "LV2",   value: 1,  fraction: 0.02, color: .gray)
            BarRow(label: "OBSLT", value: 5,  fraction: 0.08, color: .red)
        }
    }
    
    // SPEED: Real bar graph using cached counts - CLICKABLE to filter!
    private var realBarGraph: some View {
        let counts = cachedBarCounts  // Use cached value instead of recalculating!
        let isEmpty = scanner.plugins.isEmpty
        let total = Swift.max(1, counts.au + counts.vst + counts.vst3 + counts.aax + counts.clap + counts.lv2 + counts.obsolete)

        return VStack(alignment: .leading, spacing: 6) {
            BarRow(
                label: "AU", value: counts.au,
                fraction: isEmpty ? 0.0 : Double(counts.au) / Double(total),
                color: .blue,
                onTap: { toggleFormat(.AU) },
                isSelected: prefs.selectedFormats.contains(.AU)
            )
            BarRow(
                label: "VST", value: counts.vst,
                fraction: isEmpty ? 0.0 : Double(counts.vst) / Double(total),
                color: .green,
                onTap: { toggleFormat(.VST) },
                isSelected: prefs.selectedFormats.contains(.VST)
            )
            BarRow(
                label: "VST3", value: counts.vst3,
                fraction: isEmpty ? 0.0 : Double(counts.vst3) / Double(total),
                color: .teal,
                onTap: { toggleFormat(.VST3) },
                isSelected: prefs.selectedFormats.contains(.VST3)
            )
            BarRow(
                label: "AAX", value: counts.aax,
                fraction: isEmpty ? 0.0 : Double(counts.aax) / Double(total),
                color: .purple,
                onTap: { toggleFormat(.AAX) },
                isSelected: prefs.selectedFormats.contains(.AAX)
            )
            BarRow(
                label: "CLAP", value: counts.clap,
                fraction: isEmpty ? 0.0 : Double(counts.clap) / Double(total),
                color: .orange,
                onTap: { toggleFormat(.CLAP) },
                isSelected: prefs.selectedFormats.contains(.CLAP)
            )
            BarRow(
                label: "LV2", value: counts.lv2,
                fraction: isEmpty ? 0.0 : Double(counts.lv2) / Double(total),
                color: .gray,
                onTap: { toggleFormat(.LV2) },
                isSelected: prefs.selectedFormats.contains(.LV2)
            )
            BarRow(
                label: "OBSLT", value: counts.obsolete,
                fraction: isEmpty ? 0.0 : Double(counts.obsolete) / Double(total),
                color: .red,
                onTap: { toggleFormat(.OBSLT) },
                isSelected: prefs.selectedFormats.contains(.OBSLT)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Toggle format filter when bar is clicked
    private func toggleFormat(_ format: PluginFormat) {
        if prefs.selectedFormats.contains(format) {
            prefs.selectedFormats.remove(format)
        } else {
            prefs.selectedFormats.insert(format)
        }
        updateDisplayedPlugins()
    }

    var body: some View {
        // Single-pane layout (no NavigationSplitView) so the UI never shifts. The Formats panel is provided by an overlay.
        HStack(spacing: 0) {
            Spacer().frame(width: 10) // structural left inset to prevent cut-off
            VStack(spacing: 0) {
                if hSizeClass == .compact {
                    // Compact header for iPhone
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button("Filters") { showOverlaySidebar.toggle() }
                                .buttonStyle(.bordered)

                            TextField("Search", text: $searchText)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.18)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(searchFocused ? Color.accentColor : Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .focused($searchFocused)

                            Button("Scan") { scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:))) }
                                .disabled(scanner.isScanning)

                            // AI Suggestions button (shown when plugin is selected)
                            if let firstSelected = appState.selected.first {
                                AISuggestionsButton(plugin: firstSelected, ownedPlugins: [])
                            }
                        }

                        // Export actions in a compact menu
                        HStack {
                            // Ready indicator
                            if !scanner.isScanning {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.icloud.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                    Text("Ready")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Menu {
                                Button("Export CSV") { ExportManager.exportCSV(rows: displayedPlugins) }
                                Button("Export JSON") { ExportManager.exportJSON(rows: displayedPlugins) }
                                Button("Export HTML") { ExportManager.exportHTML(rows: displayedPlugins) }
                                #if os(macOS)
                                Button("Export PDF") {
                                    let opts = PDFExportOptions(page: prefs.pdfPage, landscape: prefs.pdfLandscape, margin: prefs.pdfMargin, fontSize: prefs.pdfFontSize)
                                    ExportManager.exportPDF(rows: displayedPlugins, options: opts)
                                }
                                #endif
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                        }
                    }
                    .padding(.top, 8)
                } else {
                    // Original wide header for Mac / regular width
                    HStack(spacing: 8) {
                        Button("Filters") {
                            showOverlaySidebar.toggle()
                        }
                        .buttonStyle(.bordered)

                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.18)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(searchFocused ? Color.accentColor : Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .focused($searchFocused)
                            .frame(width: 300)

                        Button("Scan") { scanner.scan(extraPaths: prefs.extraScanPaths.map(URL.init(fileURLWithPath:))) }
                            .disabled(scanner.isScanning)

                        Spacer()

                        // AI Suggestions button (shown when plugin is selected) - centered
                        if let firstSelected = appState.selected.first {
                            AISuggestionsButton(plugin: firstSelected, ownedPlugins: [])
                        }

                        Spacer()

                        // Ready indicator
                        if !scanner.isScanning {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.icloud.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                Text("Ready")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Menu {
                            #if os(macOS)
                            Button("Export PDF") {
                                let opts = PDFExportOptions(page: prefs.pdfPage, landscape: prefs.pdfLandscape, margin: prefs.pdfMargin, fontSize: prefs.pdfFontSize)
                                ExportManager.exportPDF(rows: displayedPlugins, options: opts)
                            }
                            #endif
                            Button("Export CSV") { ExportManager.exportCSV(rows: displayedPlugins) }
                            Button("Export HTML") { ExportManager.exportHTML(rows: displayedPlugins) }
                            Button("Export JSON") { ExportManager.exportJSON(rows: displayedPlugins) }
                        } label: {
                            Text("Export")
                        }
                        .menuIndicator(.hidden)
                        .buttonStyle(.bordered)
                        .padding(.trailing, 8)  // Match the bar graph padding to align with numbers
                    }
                    .padding(.top, 8)
                }
                
                // BAR GRAPH - INSTANT DISPLAY with batched updates!
                // Uses cached counts - only updates every 100 plugins for instant feel
                instantBarsWithBatchedCounts(rows: displayedPlugins)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .background(appBG)
                    
                Divider()
                ZStack {
                    appBG
                    PlatformTable(rows: displayedPlugins, selection: $appState.selected, sortStatus: $sortStatus)
                        .id(displayedPlugins.count)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                Divider()
                ZStack {
                    // Centered items count
                    Text("\(displayedPlugins.count) items")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Left-aligned sort status
                    HStack {
                        Text(sortStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            Spacer().frame(width: 10)
        }
        .overlay(alignment: .leading) {
            if showOverlaySidebar {
                // Full-screen container to allow outside taps to dismiss
                ZStack(alignment: .leading) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut) { showOverlaySidebar = false } }
                    // Slide-over panel
                    VStack(alignment: .leading, spacing: 12) {
                        // Top padding to prevent cutoff
                        Spacer().frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Header with title and close button
                            ZStack {
                                // Centered title
                                Text("Formats")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                // Close button aligned to trailing edge
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.easeInOut) { 
                                            showOverlaySidebar = false 
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                            .background(Circle().fill(Color.white.opacity(0.1)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            FormatsCloud(selectedFormats: $prefs.selectedFormats)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Styles")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            StyleDropdown(
                                allStyles: Array(Set(scanner.plugins.map(\.style).filter { !$0.isEmpty })).sorted(),
                                selectedStyles: $prefs.selectedStyles
                            )
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Publishers")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            PublisherDropdown(
                                allPublishers: Array(Set(scanner.plugins.map(\.publisher))).sorted(),
                                selectedPublishers: $prefs.selectedPublishers
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: 260)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(appBG)
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 0)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                .ignoresSafeArea()
            }
        }
        .animation(suppressAnimations ? nil : .easeInOut, value: showOverlaySidebar)
        .transaction { tx in if suppressAnimations { tx.animation = nil } }
        .background(appBG)
        .clipped()
        .sheet(isPresented: $showDetailSheet) {
            if let item = appState.selected.first {
                PluginDetailView(item: item)
            }
        }
        .onChange(of: appState.selected) { _ in
            if hSizeClass == .compact {
                showDetailSheet = (appState.selected.first != nil)
            }
        }
        .onAppear {
            updateDisplayedPlugins()
        }
        .onChange(of: prefs.selectedFormats) { _ in
            updateDisplayedPlugins()
        }
        .onChange(of: prefs.selectedPublishers) { _ in
            updateDisplayedPlugins()
        }
        .onChange(of: prefs.selectedStyles) { _ in
            updateDisplayedPlugins()
        }
        .onChange(of: searchText) { _ in
            updateDisplayedPlugins()
        }
        .onChange(of: scanner.plugins.count) { _ in
            updateDisplayedPlugins()
        }
        .onChange(of: prefs.appearance) { newValue in
            if newValue == AppPreferences.Appearance.system {
                suppressAnimations = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    suppressAnimations = false
                }
            }
        }
    }

    // MARK: - Bar Graph Helpers

    private func instantBarsWithBatchedCounts(rows: [AppPluginItem]) -> some View {
        // INSTANT bar graph - recalculates on EVERY change for instant feedback
        let currentCount = rows.count

        // Always update immediately - no batching delay
        let shouldUpdate = true

        if shouldUpdate {
            // Update cache
            DispatchQueue.main.async {
                self.lastBarUpdateCount = currentCount
                self.cachedBarCounts = self.quickCount(rows: rows)
            }
        }

        // Always use cached counts for INSTANT display
        let counts = cachedBarCounts
        // Use MAX value instead of total, so largest bar fills 100%
        let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)
        let hasData = currentCount > 0

        return VStack(alignment: .leading, spacing: 6) {
            if counts.au > 0 {
                BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
            }
            if counts.vst > 0 {
                BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
            }
            if counts.vst3 > 0 {
                BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
            }
            if counts.aax > 0 {
                BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
            }
            if counts.clap > 0 {
                BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
            }
            if counts.lv2 > 0 {
                BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
            }
            if counts.obsolete > 0 {
                BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
        .id(cachedBarCounts) // Only re-render when cached counts actually change
    }

    // Ultra-fast counting helper
    private func quickCount(rows: [AppPluginItem]) -> FormatCounts {
        var c = FormatCounts()
        for row in rows {
            switch row.type {
            case "AU":   c.au += 1
            case "VST":  c.vst += 1
            case "VST3": c.vst3 += 1
            case "AAX":  c.aax += 1
            case "CLAP": c.clap += 1
            case "LV2":  c.lv2 += 1
            default:
                switch row.type.uppercased() {
                case "AU":   c.au += 1
                case "VST":  c.vst += 1
                case "VST3": c.vst3 += 1
                case "AAX":  c.aax += 1
                case "CLAP": c.clap += 1
                case "LV2":  c.lv2 += 1
                default: break
                }
            }
            if row.obsolete { c.obsolete += 1 }
        }
        return c
    }
}

// MARK: - Summary Bars Helper (outside ContentView)

private func summaryBarsFromList(rows: [AppPluginItem]) -> some View {
    // INSTANT bar graph - direct counting without function call overhead
    var counts = FormatCounts()

    // Ultra-fast counting - single pass, no function calls
    if !rows.isEmpty {
        for row in rows {
            switch row.type {
            case "AU":   counts.au += 1
            case "VST":  counts.vst += 1
            case "VST3": counts.vst3 += 1
            case "AAX":  counts.aax += 1
            case "CLAP": counts.clap += 1
            case "LV2":  counts.lv2 += 1
            default:
                switch row.type.uppercased() {
                case "AU":   counts.au += 1
                case "VST":  counts.vst += 1
                case "VST3": counts.vst3 += 1
                case "AAX":  counts.aax += 1
                case "CLAP": counts.clap += 1
                case "LV2":  counts.lv2 += 1
                default: break
                }
            }
            if row.obsolete { counts.obsolete += 1 }
        }
    }

    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)
    let hasData = !rows.isEmpty

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .id(rows.count) // Force re-render only when count changes
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

private func summaryBars(rows: [ScannerPluginItem]) -> some View {
    // INSTANT bar graph display
    let counts = formatCounts(for: rows)
    let hasData = !rows.isEmpty
    // Use MAX value instead of total, so largest bar fills 100%
    let maxCount = Swift.max(1, counts.au, counts.vst, counts.vst3, counts.aax, counts.clap, counts.lv2, counts.obsolete)

    return VStack(alignment: .leading, spacing: 6) {
        BarRow(label: "AU",    value: counts.au,       fraction: hasData ? Double(counts.au) / Double(maxCount) : 0.0, color: Color.blue)
        BarRow(label: "VST",   value: counts.vst,      fraction: hasData ? Double(counts.vst) / Double(maxCount) : 0.0, color: Color.green)
        BarRow(label: "VST3",  value: counts.vst3,     fraction: hasData ? Double(counts.vst3) / Double(maxCount) : 0.0, color: Color.teal)
        BarRow(label: "AAX",   value: counts.aax,      fraction: hasData ? Double(counts.aax) / Double(maxCount) : 0.0, color: Color.purple)
        BarRow(label: "CLAP",  value: counts.clap,     fraction: hasData ? Double(counts.clap) / Double(maxCount) : 0.0, color: Color.orange)
        BarRow(label: "LV2",   value: counts.lv2,      fraction: hasData ? Double(counts.lv2) / Double(maxCount) : 0.0, color: Color.gray)
        BarRow(label: "OBSLT", value: counts.obsolete, fraction: hasData ? Double(counts.obsolete) / Double(maxCount) : 0.0, color: Color.red)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .transaction { $0.animation = nil } // NO animation - INSTANT updates!
}

private struct FormatCounts: Equatable, Hashable {
    var au: Int = 0
    var vst: Int = 0
    var vst3: Int = 0
    var aax: Int = 0
    var clap: Int = 0
    var lv2: Int = 0
    var obsolete: Int = 0
}

private func formatCountsFromList(for rows: [AppPluginItem]) -> FormatCounts {
    // Same counting logic but for PluginItem instead of ScannerPluginItem
    var c = FormatCounts()

    // Early exit for empty arrays to avoid unnecessary work
    guard !rows.isEmpty else { return c }

    // Pre-allocate expected capacity hint for compiler optimization
    var typeMap: [String: Int] = [:]
    typeMap.reserveCapacity(6)

    // Process in a single pass for better performance
    for row in rows {
        // Use direct string comparison without lowercasing for common cases
        let type = row.type
        switch type {
        case "AU":   c.au += 1
        case "VST":  c.vst += 1
        case "VST3": c.vst3 += 1
        case "AAX":  c.aax += 1
        case "CLAP": c.clap += 1
        case "LV2":  c.lv2 += 1
        default:
            // Fallback to case-insensitive for edge cases
            switch type.lowercased() {
            case "au":   c.au += 1
            case "vst":  c.vst += 1
            case "vst3": c.vst3 += 1
            case "aax":  c.aax += 1
            case "clap": c.clap += 1
            case "lv2":  c.lv2 += 1
            default: break
            }
        }

        // Check obsolete flag efficiently
        if row.obsolete { c.obsolete += 1 }
    }

    return c
}

private func formatCounts(for rows: [ScannerPluginItem]) -> FormatCounts {
    // Use a more efficient counting approach
    var c = FormatCounts()

    // Early exit for empty arrays to avoid unnecessary work
    guard !rows.isEmpty else { return c }

    // Process in a single pass for better performance
    for row in rows {
        // Use direct string comparison without lowercasing for common cases
        let type = row.type
        switch type {
        case "AU":   c.au += 1
        case "VST":  c.vst += 1
        case "VST3": c.vst3 += 1
        case "AAX":  c.aax += 1
        case "CLAP": c.clap += 1
        case "LV2":  c.lv2 += 1
        default:
            // Fallback to case-insensitive for edge cases
            switch type.lowercased() {
            case "au":   c.au += 1
            case "vst":  c.vst += 1
            case "vst3": c.vst3 += 1
            case "aax":  c.aax += 1
            case "clap": c.clap += 1
            case "lv2":  c.lv2 += 1
            default: break
            }
        }

        // Check obsolete flag efficiently
        if row.obsolete { c.obsolete += 1 }
    }

    return c
}

private struct BarRow: View {
    let label: String
    let value: Int
    let fraction: Double
    let color: Color
    var onTap: (() -> Void)? = nil  // Optional click handler
    var isSelected: Bool = false     // Show if this format is filtered

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 50, alignment: .leading)
                .font(.caption)
                .foregroundStyle(isSelected ? color : .secondary)
                .fontWeight(isSelected ? .bold : .regular)

            ZStack(alignment: .leading) {
                // Background - fills available space
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: isSelected ? 8 : 6)

                // Foreground - scales with fraction
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * fraction, height: isSelected ? 8 : 6)
                }
                .frame(height: isSelected ? 8 : 6)
            }
            .frame(maxWidth: .infinity)

            Text("\(value)")
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .frame(height: 14)
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            onTap?()
        }
        .onHover { isHovering in
            #if os(macOS)
            if onTap != nil {
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
        }
    }
}

// Helper for Canvas rounded rect
private struct RoundedRect: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        return Path(roundedRect: self.rect, cornerRadius: cornerRadius)
    }
}

// MARK: - Publisher Dropdown Helper

private struct PublisherDropdown: View {
    let allPublishers: [String]
    @Binding var selectedPublishers: Set<String>
    @State private var showingPopover = false
    
    private var displayText: String {
        if selectedPublishers.isEmpty {
            return "All Publishers"
        } else if selectedPublishers.count == 1 {
            return selectedPublishers.first ?? "All Publishers"
        } else {
            return "\(selectedPublishers.count) Publishers"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Publishers") {
                    selectedPublishers.removeAll()
                }
                
                Divider()
                
                ForEach(allPublishers.filter { !$0.isEmpty }, id: \.self) { publisher in
                    Button(action: {
                        if selectedPublishers.contains(publisher) {
                            selectedPublishers.remove(publisher)
                        } else {
                            selectedPublishers.insert(publisher)
                        }
                    }) {
                        HStack {
                            Text(publisher)
                            Spacer()
                            if selectedPublishers.contains(publisher) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)
            
            if !selectedPublishers.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedPublishers).sorted(), id: \.self) { publisher in
                            HStack {
                                Text(publisher)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedPublishers.remove(publisher)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}

// MARK: - Style Dropdown Helper

private struct StyleDropdown: View {
    let allStyles: [String]
    @Binding var selectedStyles: Set<String>
    @State private var showingPopover = false

    private var displayText: String {
        if selectedStyles.isEmpty {
            return "All Styles"
        } else if selectedStyles.count == 1 {
            return selectedStyles.first ?? "All Styles"
        } else {
            return "\(selectedStyles.count) Styles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Styles") {
                    selectedStyles.removeAll()
                }

                Divider()

                ForEach(allStyles.filter { !$0.isEmpty }, id: \.self) { style in
                    Button(action: {
                        if selectedStyles.contains(style) {
                            selectedStyles.remove(style)
                        } else {
                            selectedStyles.insert(style)
                        }
                    }) {
                        HStack {
                            Text(style)
                            Spacer()
                            if selectedStyles.contains(style) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayText)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity)

            if !selectedStyles.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], alignment: .leading, spacing: 4) {
                        ForEach(Array(selectedStyles).sorted(), id: \.self) { style in
                            HStack {
                                Text(style)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Button(action: {
                                    selectedStyles.remove(style)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }
}

// MARK: - Compact Detail View (iOS)
private struct PluginDetailView: View {
    let item: AppPluginItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Info")) {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Publisher", value: item.publisher)
                    LabeledContent("Version", value: item.version)
                    LabeledContent("Type", value: item.type)
                }
                Section(header: Text("Compatibility")) {
                    LabeledContent("Architectures", value: item.architectures)
                    LabeledContent("Requirement", value: item.runtimeRequirement)
                    LabeledContent("Obsolete", value: item.obsolete ? "Yes" : "No")
                }
                Section(header: Text("File")) {
                    LabeledContent("Date", value: item.dateString)
                    LabeledContent("Size", value: item.sizeString)
                    LabeledContent("Path", value: item.path)
                }
            }
            .navigationTitle("Details")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }
}

// MARK: - Size Multiplier Environment Key (Vector Zoom)
private struct SizeMultiplierKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var sizeMultiplier: CGFloat {
        get { self[SizeMultiplierKey.self] }
        set { self[SizeMultiplierKey.self] = newValue }
    }
}

// MARK: - Scaled Font Modifier
struct ScaledFont: ViewModifier {
    @Environment(\.sizeMultiplier) var multiplier
    var size: CGFloat
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        content.font(.system(size: size * multiplier, weight: weight))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

// MARK: - Fast Filter Engine (NEW - SIMPLE & CORRECT)

/// Ultra-simple, ultra-fast filtering engine
/// NO complex logic - just straightforward filtering that WORKS
struct FastFilterEngine {

    /// Filter plugins based on selected criteria
    static func filter(
        plugins: [AppPluginItem],
        formats: Set<PluginFormat>,
        publishers: Set<String>,
        styles: Set<String>,
        searchText: String
    ) -> [AppPluginItem] {

        var result = plugins

        // STEP 1: Format filter - Empty set = show all
        if !formats.isEmpty {
            result = result.filter { plugin in
                // Check each selected format
                for format in formats {
                    if format == .OBSLT {
                        // OBSLT means: show plugins where obsolete == true
                        if plugin.obsolete {
                            return true
                        }
                    } else {
                        // Normal format: show plugins where type matches
                        if plugin.type == format.rawValue {
                            return true
                        }
                    }
                }
                return false
            }
        }

        // STEP 2: Publisher filter - Empty set = show all
        if !publishers.isEmpty {
            result = result.filter { publishers.contains($0.publisher) }
        }

        // STEP 3: Style filter - Empty set = show all
        if !styles.isEmpty {
            result = result.filter { styles.contains($0.style) }
        }

        // STEP 4: Search filter - Empty string = show all
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { plugin in
                // Search across all fields
                plugin.name.lowercased().contains(query) ||
                plugin.publisher.lowercased().contains(query) ||
                plugin.style.lowercased().contains(query) ||
                plugin.architectures.lowercased().contains(query) ||
                plugin.version.lowercased().contains(query) ||
                plugin.runtimeRequirement.lowercased().contains(query) ||
                plugin.type.lowercased() == query  // Exact match for type to avoid VST matching VST3
            }
        }

        return result
    }
}
