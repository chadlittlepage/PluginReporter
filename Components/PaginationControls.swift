//
//  PaginationControls.swift
//  Plugin Reporter
//
//  UI components for pagination controls (macOS and iOS)
//

import SwiftUI

// MARK: - macOS Pagination Controls

#if os(macOS)
struct MacPaginationControls: View {
    @ObservedObject var pagination: PaginationManager<PluginItem>
    @EnvironmentObject private var prefs: Preferences

    // Pagination background: black ONLY in Space appearance, grey otherwise
    private var paginationBackground: Color {
        if prefs.appearance == .space {
            return Color.black // 100% black in Space appearance only
        } else {
            return Color(NSColor.controlBackgroundColor) // Grey in light/dark modes
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Only show page info and navigation if there's more than 1 page
            if pagination.totalPages > 1 {
                // Page info
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true) // Decorative icon
                    Text(pagination.currentPageRange)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 130, alignment: .leading) // Fixed width to prevent shifting
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Showing items \(pagination.currentPageRange)")

                Divider()
                    .frame(height: 16)

                // Navigation buttons
                HStack(spacing: 4) {
                Button(action: {
                    // Check if Shift key is held
                    if NSEvent.modifierFlags.contains(.shift) {
                        // Shift + Click: Jump 10 pages backward
                        pagination.goToPage(max(0, pagination.currentPage - 10))
                    } else {
                        pagination.firstPage()
                    }
                }) {
                    Image(systemName: "chevron.left.2")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!pagination.canGoPrevious)
                .help("First page (Shift+Click: -10 pages)")
                .accessibilityLabel("Go to first page")
                .accessibilityHint("Shows items 1 through \(pagination.pageSize). Hold Shift to jump back 10 pages")

                Button(action: {
                    // Check if Shift key is held
                    if NSEvent.modifierFlags.contains(.shift) {
                        // Shift + Click: Jump 10 pages backward
                        pagination.goToPage(max(0, pagination.currentPage - 10))
                    } else {
                        pagination.previousPage()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!pagination.canGoPrevious)
                .help("Previous page (Shift+Click: -10 pages)")
                .accessibilityLabel("Go to previous page")
                .accessibilityHint("Shows \(pagination.pageSize) earlier items. Hold Shift to jump back 10 pages")

                // Page number input
                HStack(spacing: 2) {
                    Text("Page")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("\(pagination.currentPage + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .fontWeight(.medium)
                        .frame(minWidth: 40, alignment: .trailing) // Wider, right-aligned for stability

                    Text("of")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("\(pagination.totalPages)")
                        .font(.system(size: 11, design: .monospaced))
                        .fontWeight(.medium)
                        .frame(minWidth: 40, alignment: .leading) // Fixed width for stability
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Page \(pagination.currentPage + 1) of \(pagination.totalPages)")
                .accessibilityAddTraits(.updatesFrequently)

                Button(action: {
                    // Check if Shift key is held
                    if NSEvent.modifierFlags.contains(.shift) {
                        // Shift + Click: Jump 10 pages forward
                        pagination.goToPage(min(pagination.totalPages - 1, pagination.currentPage + 10))
                    } else {
                        pagination.nextPage()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!pagination.canGoNext)
                .help("Next page (Shift+Click: +10 pages)")
                .accessibilityLabel("Go to next page")
                .accessibilityHint("Shows \(pagination.pageSize) more items. Hold Shift to jump forward 10 pages")

                Button(action: {
                    // Check if Shift key is held
                    if NSEvent.modifierFlags.contains(.shift) {
                        // Shift + Click: Jump 10 pages forward
                        pagination.goToPage(min(pagination.totalPages - 1, pagination.currentPage + 10))
                    } else {
                        pagination.lastPage()
                    }
                }) {
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!pagination.canGoNext)
                .help("Last page (Shift+Click: +10 pages)")
                .accessibilityLabel("Go to last page")
                .accessibilityHint("Shows final page of items")
            }

                Divider()
                    .frame(height: 16)
            }

            // Page size selector (always visible, centered when alone)
            HStack(spacing: 4) {
                Text("Show:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Picker("", selection: $pagination.pageSize) {
                    ForEach(pagination.pageSizeOptions, id: \.self) { size in
                        Text(size == Int.max ? "INF" : "\(size)").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
                .font(.system(size: 11))
                .onChange(of: pagination.pageSize) { newValue in
                    pagination.setPageSize(newValue)
                }
                .accessibilityLabel("Items per page")
                .accessibilityValue(pagination.pageSize == Int.max ? "All items" : "\(pagination.pageSize) items")
                .accessibilityHint("Choose number of items to display per page")

                Text("per page")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true) // Redundant with picker label
            }

            // Performance info (debug mode only)
            #if DEBUG
            Spacer()
            Text(pagination.estimatedMemoryUsage)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
            #endif
        }
        .frame(maxWidth: .infinity) // Center the controls
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(paginationBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.secondary.opacity(0.2)),
            alignment: .top
        )
    }
}
#endif

// MARK: - iOS Pagination Controls

#if os(iOS)
struct iOSPaginationControls<Item: Identifiable>: View {
    @ObservedObject var pagination: PaginationManager<Item>
    @State private var showPageSizeSheet = false

    var body: some View {
        VStack(spacing: 8) {
            // Page info and navigation
            HStack {
                // First/Previous buttons
                HStack(spacing: 8) {
                    Button(action: { pagination.firstPage() }) {
                        Image(systemName: "chevron.left.2")
                            .font(.caption)
                    }
                    .disabled(!pagination.canGoPrevious)
                    .accessibilityLabel("Go to first page")
                    .accessibilityHint("Shows items 1 through \(pagination.pageSize)")

                    Button(action: { pagination.previousPage() }) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                    }
                    .disabled(!pagination.canGoPrevious)
                    .accessibilityLabel("Go to previous page")
                    .accessibilityHint("Shows \(pagination.pageSize) earlier items")
                }

                Spacer()

                // Page info
                VStack(spacing: 2) {
                    Text("Page \(pagination.currentPage + 1) of \(pagination.totalPages)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(pagination.currentPageRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Page \(pagination.currentPage + 1) of \(pagination.totalPages), showing items \(pagination.currentPageRange)")
                .accessibilityAddTraits(.updatesFrequently)

                Spacer()

                // Next/Last buttons
                HStack(spacing: 8) {
                    Button(action: { pagination.nextPage() }) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .disabled(!pagination.canGoNext)
                    .accessibilityLabel("Go to next page")
                    .accessibilityHint("Shows \(pagination.pageSize) more items")

                    Button(action: { pagination.lastPage() }) {
                        Image(systemName: "chevron.right.2")
                            .font(.caption)
                    }
                    .disabled(!pagination.canGoNext)
                    .accessibilityLabel("Go to last page")
                    .accessibilityHint("Shows final page of items")
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * pagination.progress, height: 4)
                }
            }
            .frame(height: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page progress")
            .accessibilityValue("\(Int(pagination.progress * 100)) percent through all pages")
            .accessibilityAddTraits(.updatesFrequently)

            // Page size button
            Button(action: { showPageSizeSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption2)
                    Text("\(pagination.pageSize) items per page")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .accessibilityLabel("Items per page")
            .accessibilityValue("\(pagination.pageSize) items")
            .accessibilityHint("Choose number of items to display per page")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .confirmationDialog("Items per page", isPresented: $showPageSizeSheet) {
            ForEach(pagination.pageSizeOptions, id: \.self) { size in
                Button("\(size) items") {
                    pagination.setPageSize(size)
                }
                .accessibilityLabel("\(size) items per page")
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
#endif

// MARK: - Pagination Status Badge

struct PaginationStatusBadge: View {
    let isEnabled: Bool
    let totalItems: Int

    var body: some View {
        if isEnabled {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                Text("Paginated")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.2))
            .foregroundColor(.accentColor)
            .cornerRadius(4)
        }
    }
}
