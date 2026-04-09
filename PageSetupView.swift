//
//  PageSetupView.swift
//  PluginReporter
//
//  Custom Page Setup dialog with live preview and margin controls
//

#if os(macOS)
import SwiftUI
import AppKit

struct PageSetupView: View {
    @ObservedObject var preferences: Preferences
    @Environment(\.dismiss) private var dismiss

    let plugins: [PluginItem]  // Actual plugin data to preview

    @State private var previewText: String = ""
    @State private var availableWidth: CGFloat = 500
    @State private var marginsLocked: Bool = true
    @State private var topMargin: CGFloat = 36
    @State private var bottomMargin: CGFloat = 36
    @State private var leftMargin: CGFloat = 36
    @State private var rightMargin: CGFloat = 36
    @State private var isUpdatingMargins: Bool = false
    @State private var isGeneratingPreview: Bool = false  // Prevent concurrent updates

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Live Preview
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    GeometryReader { previewGeometry in
                        let availablePreviewWidth = previewGeometry.size.width - 32
                        let availablePreviewHeight = previewGeometry.size.height - 32
                        let previewScale = calculateScale(availableWidth: availablePreviewWidth, availableHeight: availablePreviewHeight)
                        let scaledPageWidth = (preferences.pdfLandscape ? preferences.pdfPage.sizePoints.height : preferences.pdfPage.sizePoints.width) * previewScale
                        let scaledPageHeight = (preferences.pdfLandscape ? preferences.pdfPage.sizePoints.width : preferences.pdfPage.sizePoints.height) * previewScale

                        ScrollView([.horizontal, .vertical]) {
                            ZStack(alignment: .topLeading) {
                                // Page background
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: scaledPageWidth, height: scaledPageHeight)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                                // Margin guides - blue rectangle showing content area
                                Rectangle()
                                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1, antialiased: true)
                                    .frame(
                                        width: scaledPageWidth - ((leftMargin + rightMargin) * previewScale), height: scaledPageHeight - ((topMargin + bottomMargin) * previewScale)
                                    )
                                    .offset(
                                        x: leftMargin * previewScale, y: topMargin * previewScale
                                    )

                                // Preview text
                                Text(previewText)
                                    .font(.system(size: preferences.pdfFontSize * previewScale, design: .monospaced))
                                    .foregroundColor(.black)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: true, vertical: true)  // Prevent text wrapping
                                    .frame(
                                        width: scaledPageWidth - ((leftMargin + rightMargin) * previewScale), height: scaledPageHeight - ((topMargin + bottomMargin) * previewScale), alignment: .topLeading
                                    )
                                    .clipped()  // Clip overflow instead of wrapping
                                    .offset(
                                        x: leftMargin * previewScale, y: topMargin * previewScale
                                    )
                            }
                            .frame(width: scaledPageWidth, height: scaledPageHeight)
                            .frame(minWidth: availablePreviewWidth, minHeight: availablePreviewHeight)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                    .padding(16)
                }
                .onAppear {
                    availableWidth = geometry.size.width - 32
                }
                .onChange(of: geometry.size) { newSize in
                    availableWidth = newSize.width - 32
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity)

            Divider()

            // Right side: Settings with fixed footer
            VStack(spacing: 0) {
                // Scrollable content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Page Setup")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Page Size
                        GroupBox(label: Text("Page Size").font(.headline)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Size", selection: $preferences.pdfPage) {
                                    ForEach(PDFExportOptions.Page.allCases) { page in
                                        Text(page.rawValue).tag(page)
                                    }
                                }
                                .pickerStyle(.radioGroup)

                                Toggle("Landscape Orientation", isOn: $preferences.pdfLandscape)

                                HStack {
                                    Text("Dimensions:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(pageDimensionsText)
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                            }
                            .padding(8)
                        }

                        // Margins
                        GroupBox(label: HStack {
                    Text("Margins").font(.headline)
                    Spacer()
                    Image(systemName: marginsLocked ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(marginsLocked ? .accentColor : .secondary)
                        .font(.title2)
                        .imageScale(.large)
                        .onTapGesture {
                            marginsLocked.toggle()
                        }
                        .help(marginsLocked ? "Click to unlock margins" : "Click to lock margins")
                }) {
                    VStack(spacing: 16) {
                        // Top Margin
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Top")
                                Spacer()
                                Text("\(Int(topMargin)) pt")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $topMargin, in: 12...108, step: 6)
                                .onChange(of: topMargin) { _ in
                                    guard !isUpdatingMargins else { return }
                                    if marginsLocked {
                                        isUpdatingMargins = true
                                        bottomMargin = topMargin
                                        leftMargin = topMargin
                                        rightMargin = topMargin
                                        isUpdatingMargins = false
                                    }
                                }
                        }

                        // Bottom Margin
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Bottom")
                                Spacer()
                                Text("\(Int(bottomMargin)) pt")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $bottomMargin, in: 12...108, step: 6)
                                .onChange(of: bottomMargin) { _ in
                                    guard !isUpdatingMargins else { return }
                                    if marginsLocked {
                                        isUpdatingMargins = true
                                        topMargin = bottomMargin
                                        leftMargin = bottomMargin
                                        rightMargin = bottomMargin
                                        isUpdatingMargins = false
                                    }
                                }
                        }

                        // Left Margin
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Left")
                                Spacer()
                                Text("\(Int(leftMargin)) pt")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $leftMargin, in: 12...108, step: 6)
                                .onChange(of: leftMargin) { _ in
                                    guard !isUpdatingMargins else { return }
                                    if marginsLocked {
                                        isUpdatingMargins = true
                                        topMargin = leftMargin
                                        bottomMargin = leftMargin
                                        rightMargin = leftMargin
                                        isUpdatingMargins = false
                                    }
                                }
                        }

                        // Right Margin
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Right")
                                Spacer()
                                Text("\(Int(rightMargin)) pt")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $rightMargin, in: 12...108, step: 6)
                                .onChange(of: rightMargin) { _ in
                                    guard !isUpdatingMargins else { return }
                                    if marginsLocked {
                                        isUpdatingMargins = true
                                        topMargin = rightMargin
                                        bottomMargin = rightMargin
                                        leftMargin = rightMargin
                                        isUpdatingMargins = false
                                    }
                                }
                        }

                        // Quick presets
                        HStack(spacing: 8) {
                            Text("Presets:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Narrow (18pt)") {
                                isUpdatingMargins = true
                                topMargin = 18
                                bottomMargin = 18
                                leftMargin = 18
                                rightMargin = 18
                                isUpdatingMargins = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            Button("Normal (36pt)") {
                                isUpdatingMargins = true
                                topMargin = 36
                                bottomMargin = 36
                                leftMargin = 36
                                rightMargin = 36
                                isUpdatingMargins = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            Button("Wide (72pt)") {
                                isUpdatingMargins = true
                                topMargin = 72
                                bottomMargin = 72
                                leftMargin = 72
                                rightMargin = 72
                                isUpdatingMargins = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal, 20)

                        // Font Size
                        GroupBox(label: Text("Font").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(preferences.pdfFontSize)) pt")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(preferences.pdfFontSize) }, set: { preferences.pdfFontSize = CGFloat($0) }
                        ), in: 5...14, step: 0.5)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 20)

                        // PDF Export Columns
                        GroupBox(label: Text("Export Columns").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select which columns to include")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {
                            ColumnToggleButton(label: "Rating", isOn: $preferences.pdfShowRating)
                            ColumnToggleButton(label: "Name", isOn: $preferences.pdfShowName)
                            ColumnToggleButton(label: "Publisher", isOn: $preferences.pdfShowPublisher)
                            ColumnToggleButton(label: "Type", isOn: $preferences.pdfShowType)
                            ColumnToggleButton(label: "Style", isOn: $preferences.pdfShowStyle)
                            ColumnToggleButton(label: "Version", isOn: $preferences.pdfShowVersion)
                            ColumnToggleButton(label: "License", isOn: $preferences.pdfShowLicense)
                            ColumnToggleButton(label: "Preset", isOn: $preferences.pdfShowArch)
                            ColumnToggleButton(label: "Date", isOn: $preferences.pdfShowDate)
                            ColumnToggleButton(label: "Size", isOn: $preferences.pdfShowSize)
                            ColumnToggleButton(label: "Requirement", isOn: $preferences.pdfShowRequirement)
                            ColumnToggleButton(label: "Obsolete", isOn: $preferences.pdfShowObsolete)
                            ColumnToggleButton(label: "Missing", isOn: $preferences.pdfShowMissing)
                            ColumnToggleButton(label: "Track", isOn: $preferences.pdfShowTrack)
                            ColumnToggleButton(label: "Notes", isOn: $preferences.pdfShowNotes)
                            ColumnToggleButton(label: "Path", isOn: $preferences.pdfShowPath)
                        }

                        HStack(spacing: 8) {
                            Button("Select All") {
                                preferences.pdfShowRating = true
                                preferences.pdfShowName = true
                                preferences.pdfShowPublisher = true
                                preferences.pdfShowType = true
                                preferences.pdfShowStyle = true
                                preferences.pdfShowVersion = true
                                preferences.pdfShowLicense = true
                                preferences.pdfShowArch = true
                                preferences.pdfShowDate = true
                                preferences.pdfShowSize = true
                                preferences.pdfShowRequirement = true
                                preferences.pdfShowObsolete = true
                                preferences.pdfShowMissing = true
                                preferences.pdfShowTrack = true
                                preferences.pdfShowNotes = true
                                preferences.pdfShowPath = true
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)

                            Button("Deselect All") {
                                preferences.pdfShowRating = false
                                preferences.pdfShowName = false
                                preferences.pdfShowPublisher = false
                                preferences.pdfShowType = false
                                preferences.pdfShowStyle = false
                                preferences.pdfShowVersion = false
                                preferences.pdfShowLicense = false
                                preferences.pdfShowArch = false
                                preferences.pdfShowDate = false
                                preferences.pdfShowSize = false
                                preferences.pdfShowRequirement = false
                                preferences.pdfShowObsolete = false
                                preferences.pdfShowMissing = false
                                preferences.pdfShowTrack = false
                                preferences.pdfShowNotes = false
                                preferences.pdfShowPath = false
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)

                            Spacer()
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal, 20)

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                // Fixed footer with buttons
                VStack(spacing: 0) {
                    Divider()

                    HStack(alignment: .center) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Spacer()

                        Button("OK") {
                            // Save the margin values to preferences
                            updatePreferencesMargin()

                            // Force UserDefaults to sync
                            UserDefaults.standard.synchronize()

                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .frame(height: 44)  // Fixed height for vertical centering
                    .padding(.horizontal, 20)
                    .background(Color(red: 36/255, green: 43/255, blue: 48/255))
                }
            }
            .frame(width: 380)
        }
        .frame(minWidth: 880, idealWidth: 1100, minHeight: 500, idealHeight: 800)
        .onAppear {
            // Initialize individual margins from preferences
            isUpdatingMargins = true
            topMargin = preferences.pdfTopMargin
            bottomMargin = preferences.pdfBottomMargin
            leftMargin = preferences.pdfLeftMargin
            rightMargin = preferences.pdfRightMargin
            isUpdatingMargins = false

            updatePreview()
        }
        .onChange(of: preferences.pdfPage) { _ in updatePreview() }
        .onChange(of: preferences.pdfLandscape) { _ in updatePreview() }
        .onChange(of: preferences.pdfFontSize) { _ in updatePreview() }
        .onChange(of: topMargin) { _ in updatePreview() }
        .onChange(of: bottomMargin) { _ in updatePreview() }
        .onChange(of: leftMargin) { _ in updatePreview() }
        .onChange(of: rightMargin) { _ in updatePreview() }
        // Column visibility changes
        .onChange(of: preferences.pdfShowRating) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowName) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowPublisher) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowType) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowStyle) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowVersion) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowLicense) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowArch) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowDate) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowSize) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowRequirement) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowObsolete) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowMissing) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowTrack) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowNotes) { _ in updatePreview() }
        .onChange(of: preferences.pdfShowPath) { _ in updatePreview() }
    }

    // MARK: - Helper Functions

    private func updatePreferencesMargin() {
        // Save individual margins to preferences
        preferences.pdfTopMargin = topMargin
        preferences.pdfBottomMargin = bottomMargin
        preferences.pdfLeftMargin = leftMargin
        preferences.pdfRightMargin = rightMargin
        // Also update legacy unified margin (average) for backward compatibility
        preferences.pdfMargin = (topMargin + bottomMargin + leftMargin + rightMargin) / 4
    }

    // MARK: - Computed Properties

    private func calculateScale(availableWidth: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let actualWidth = preferences.pdfLandscape ?
            preferences.pdfPage.sizePoints.height :
            preferences.pdfPage.sizePoints.width
        let actualHeight = preferences.pdfLandscape ?
            preferences.pdfPage.sizePoints.width :
            preferences.pdfPage.sizePoints.height

        let widthScale = availableWidth / actualWidth
        let heightScale = availableHeight / actualHeight

        // Use the smaller scale to fit within available space, allow up to 3x zoom
        return min(widthScale, heightScale, 3.0)
    }

    private var pageDimensionsText: String {
        let size = preferences.pdfPage.sizePoints
        let w = preferences.pdfLandscape ? size.height : size.width
        let h = preferences.pdfLandscape ? size.width : size.height
        return String(format: "%.0f × %.0f pt", w, h)
    }

    // MARK: - Preview Generation
    // (No longer needed - using actual plugin data)

    private func updatePreview() {
        // Prevent concurrent updates for performance
        guard !isGeneratingPreview else { return }
        isGeneratingPreview = true

        // Debounce: Update on next run loop to batch rapid changes
        DispatchQueue.main.async {
            // Calculate available width for text
            let size = self.preferences.pdfPage.sizePoints
            let pageWidth = self.preferences.pdfLandscape ? size.height : size.width
            let contentWidth = pageWidth - (self.leftMargin + self.rightMargin)

            // Calculate character capacity using ACTUAL font metrics
            let font = NSFont.monospacedSystemFont(ofSize: self.preferences.pdfFontSize, weight: .regular)
            let charWidth = font.maximumAdvancement.width
            let capacity = Int(contentWidth / charWidth)

            // Build preview text using actual plugin data (one page worth)
            let header = "Plugin Report (\(self.plugins.count) items)\n\n"
            let tableText = self.buildPreviewTable(
                capacity: capacity, topMargin: self.topMargin, bottomMargin: self.bottomMargin
            )
            self.previewText = header + tableText

            self.isGeneratingPreview = false
        }
    }

    private func buildPreviewTable(capacity: Int, topMargin: CGFloat, bottomMargin: CGFloat) -> String {
        // Get managers for rating, notes, and metadata (SAME as actual export)
        let ratingsManager = RatingsManager.shared
        let notesManager = NotesManager.shared
        let metadataManager = MetadataManager.shared

        // Define column information structure
        struct ColumnInfo {
            let header: String
            let maxDesired: Int
            let minimum: Int
            let extractor: (PluginItem, RatingsManager, NotesManager) -> String
        }

        // Build columns array based on preferences (MUST MATCH buildPrintTableText)
        var columns: [ColumnInfo] = []

        if preferences.pdfShowRating {
            columns.append(ColumnInfo(header: "Rating", maxDesired: 6, minimum: 4) { item, ratings, _ in
                let rating = ratings.getRating(for: item.path)
                return rating > 0 ? String(repeating: "★", count: rating) : ""
            })
        }
        if preferences.pdfShowName {
            columns.append(ColumnInfo(header: "Name", maxDesired: 35, minimum: 8) { item, _, _ in item.name })
        }
        if preferences.pdfShowPublisher {
            columns.append(ColumnInfo(header: "Publisher", maxDesired: 20, minimum: 6) { item, _, _ in metadataManager.getDisplayPublisher(for: item) })
        }
        if preferences.pdfShowType {
            columns.append(ColumnInfo(header: "Type", maxDesired: 5, minimum: 3) { item, _, _ in item.type })
        }
        if preferences.pdfShowStyle {
            columns.append(ColumnInfo(header: "Style", maxDesired: 15, minimum: 6) { item, _, _ in metadataManager.getDisplayStyle(for: item) })
        }
        if preferences.pdfShowVersion {
            columns.append(ColumnInfo(header: "Version", maxDesired: 12, minimum: 5) { item, _, _ in metadataManager.getDisplayVersion(for: item) })
        }
        if preferences.pdfShowLicense {
            columns.append(ColumnInfo(header: "License", maxDesired: 8, minimum: 5) { item, _, _ in getLicenseType(for: item) })
        }
        if preferences.pdfShowArch {
            columns.append(ColumnInfo(header: "Preset", maxDesired: 16, minimum: 8) { item, _, _ in item.preset })
        }
        if preferences.pdfShowDate {
            columns.append(ColumnInfo(header: "Date", maxDesired: 12, minimum: 8) { item, _, _ in item.dateString })
        }
        if preferences.pdfShowSize {
            columns.append(ColumnInfo(header: "Size", maxDesired: 10, minimum: 4) { item, _, _ in item.sizeString })
        }
        if preferences.pdfShowRequirement {
            columns.append(ColumnInfo(header: "Requirement", maxDesired: 16, minimum: 8) { item, _, _ in item.runtimeRequirement })
        }
        if preferences.pdfShowObsolete {
            columns.append(ColumnInfo(header: "Obsolete", maxDesired: 3, minimum: 1) { item, _, _ in item.obsolete ? "Y" : "N" })
        }
        if preferences.pdfShowMissing {
            columns.append(ColumnInfo(header: "Missing", maxDesired: 3, minimum: 1) { item, _, _ in item.missing ? "Y" : "N" })
        }
        if preferences.pdfShowTrack {
            columns.append(ColumnInfo(header: "Track", maxDesired: 18, minimum: 5) { item, _, _ in item.trackName ?? "" })
        }
        if preferences.pdfShowNotes {
            columns.append(ColumnInfo(header: "Notes", maxDesired: 20, minimum: 5) { item, _, notes in notes.getNote(for: item.path) })
        }
        if preferences.pdfShowPath {
            columns.append(ColumnInfo(header: "Path", maxDesired: 60, minimum: 10) { item, _, _ in item.path })
        }

        let columnCount = columns.count
        guard columnCount > 0 else {
            return "No columns selected for export"
        }

        let sep = "  "
        let sepWidth = (columnCount - 1) * sep.count

        // Extract headers and configuration
        let headers = columns.map { $0.header }
        let maxDesired = columns.map { $0.maxDesired }
        let minimums = columns.map { $0.minimum }

        // Column data extractor
        func cols(for item: PluginItem) -> [String] {
            return columns.map { $0.extractor(item, ratingsManager, notesManager) }
        }

        // PERFORMANCE: Measure content from larger sample (1000) for accurate column widths
        var maxLens = Array(repeating: 0, count: columnCount)
        for item in plugins.prefix(1000) {
            let c = cols(for: item)
            for i in 0..<columnCount { maxLens[i] = max(maxLens[i], c[i].count) }
        }

        // Calculate how many rows fit on one page for preview
        let pageHeight = preferences.pdfLandscape ? preferences.pdfPage.sizePoints.width : preferences.pdfPage.sizePoints.height
        let contentHeight = pageHeight - (topMargin + bottomMargin)
        let font = NSFont.monospacedSystemFont(ofSize: preferences.pdfFontSize, weight: .regular)
        let lineHeight = font.boundingRectForFont.height
        let headerLines = 3  // "Plugin Report (2643 items)" + blank line + header + separator
        let rowsPerPage = Int(contentHeight / lineHeight) - headerLines

        // Double the calculated rows to ensure we fill the page (with some overflow for safety)
        let previewCount = max(100, min(rowsPerPage * 2, plugins.count))

        // Preview sample: show enough to fill one page
        let previewPlugins = Array(plugins.prefix(previewCount))

        // Start with content-based widths, capped at max desired
        var widths: [Int] = maxLens.enumerated().map { idx, len in
            max(min(len, maxDesired[idx]), headers[idx].count, minimums[idx])
        }

        func totalWidth(_ w: [Int]) -> Int { w.reduce(0, +) + sepWidth }

        if capacity > 0 {
            // First, shrink to fit if needed
            if totalWidth(widths) > capacity {
                // Shrink all columns proportionally
                var guardCount = 10_000
                while totalWidth(widths) > capacity && guardCount > 0 {
                    var didReduce = false
                    for idx in 0..<columnCount {
                        if widths[idx] > minimums[idx] {
                            widths[idx] -= 1
                            didReduce = true
                            if totalWidth(widths) <= capacity { break }
                        }
                    }
                    if !didReduce { break }
                    guardCount -= 1
                }
            }

            // Then, expand to use available space
            // Phase 1: Expand columns up to their maxDesired width
            var guardCount = 10_000
            while totalWidth(widths) < capacity && guardCount > 0 {
                var didExpand = false
                for idx in 0..<columnCount {
                    if widths[idx] < maxDesired[idx] && widths[idx] < maxLens[idx] {
                        let available = capacity - totalWidth(widths)
                        if available > 0 {
                            widths[idx] += 1
                            didExpand = true
                            if totalWidth(widths) >= capacity { break }
                        }
                    }
                }
                if !didExpand { break }
                guardCount -= 1
            }

            // Phase 2: If there's still space, expand columns beyond maxDesired (prioritize wider columns)
            guardCount = 10_000
            while totalWidth(widths) < capacity && guardCount > 0 {
                var didExpand = false
                for idx in 0..<columnCount {
                    // Allow expansion beyond maxDesired if content needs it
                    if widths[idx] < maxLens[idx] {
                        let available = capacity - totalWidth(widths)
                        if available > 0 {
                            widths[idx] += 1
                            didExpand = true
                            if totalWidth(widths) >= capacity { break }
                        }
                    }
                }
                if !didExpand { break }
                guardCount -= 1
            }

            // Phase 3: Distribute remaining space to columns, with reasonable limits
            // Cap Name column at 30 chars to prevent excessive expansion in wide layouts
            let reasonableLimits = maxLens.enumerated().map { idx, maxLen in
                if headers[idx] == "Name" {
                    return min(maxLen, 30)
                }
                return maxLen
            }

            var guardCount3 = 10_000
            while totalWidth(widths) < capacity && guardCount3 > 0 {
                var didExpand = false

                // Find columns that still have content to show (using reasonable limits)
                var needyColumns: [(index: Int, need: Int)] = []
                for idx in 0..<columnCount {
                    let need = reasonableLimits[idx] - widths[idx]
                    if need > 0 {
                        needyColumns.append((idx, need))
                    }
                }

                // If no columns need more space, we're done
                if needyColumns.isEmpty { break }

                // Distribute remaining space among needy columns
                let remainingSpace = capacity - totalWidth(widths)
                if remainingSpace <= 0 { break }

                // Give each needy column 1 character worth of space in rotation
                for (idx, _) in needyColumns {
                    if totalWidth(widths) >= capacity { break }
                    widths[idx] += 1
                    didExpand = true
                }

                if !didExpand { break }
                guardCount3 -= 1
            }
        }

        // Pad/clip helper
        func pad(_ s: String, _ n: Int) -> String {
            if s.count == n { return s }
            if s.count < n { return s + String(repeating: " ", count: n - s.count) }
            return String(s.prefix(max(0, n - 1))) + "…"
        }

        // Build output using only preview sample for performance
        let headerLine = zip(headers, widths).map { pad($0, $1) }.joined(separator: sep)
        let rule = String(repeating: "—", count: min(headerLine.count, max(capacity, headerLine.count)))

        var body = ""
        for item in previewPlugins {
            let c = cols(for: item)
            let line = zip(c, widths).map { pad($0, $1) }.joined(separator: sep)
            body += line + "\n"
        }

        // Add indicator if there are more plugins
        if plugins.count > previewPlugins.count {
            body += "\n... and \(plugins.count - previewPlugins.count) more plugins\n"
        }

        return "\(headerLine)\n\(rule)\n\(body)"
    }
}

#Preview {
    PageSetupView(
        preferences: Preferences(), plugins: [
            PluginItem(
                id: UUID(), name: "Sample Plugin", publisher: "Sample Publisher", version: "1.0.0", type: "AU", style: "Effect", architectures: "Universal", date: Date(), sizeBytes: 1_000_000, path: "/Library/Audio/Plug-Ins/Components/Sample.component", runtimeRequirement: "Universal", obsolete: false
            )
        ]
    )
}
#endif