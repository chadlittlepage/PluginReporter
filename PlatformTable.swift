import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

// Helper to enable sorting on the Obsolete/Missing columns (String is Comparable; Bool is not)
extension PluginItem {
    var obsoleteText: String { obsolete ? "Yes" : "No" }
    var missingText: String { missing ? "Yes" : "No" }

    var versionSortKey: String {
        // Use a zero-padded numeric-aware key so 1.10 > 1.2
        let parts = version.split(separator: ".")
        return parts.map { part in
            // Keep numeric parts zero-padded, leave non-numeric as-is
            if let num = Int(part) {
                return String(format: "%05d", num)
            } else {
                return String(part)
            }
        }.joined(separator: ".")
    }

    var sizeBytesSortKey: Int {
        // Fast path: if sizeBytes is already available, use it directly
        return Int(sizeBytes)
    }

    var tableDateSortKey: Date {
        // Fast path: if date is available, use it directly
        if let existingDate = date { return existingDate }

        // Fallback: parse from string only when needed
        let candidates: [DateFormatter] = Self._tableDateFormatters
        for fmt in candidates {
            if let parsedDate = fmt.date(from: dateString) { return parsedDate }
        }
        if let iso = Self._tableISOFormatter.date(from: dateString) { return iso }
        return .distantPast
    }

    var sizeSortableString: String {
        String(format: "%015d B", sizeBytesSortKey)
    }

    var dateSortableString: String {
        // Parse into a Date and render as ISO-like string that sorts lexicographically
        let date: Date = {
            let candidates: [DateFormatter] = Self._tableDateFormatters
            for fmt in candidates { if let parsedDate = fmt.date(from: dateString) { return parsedDate } }
            if let iso = Self._tableISOFormatter.date(from: dateString) { return iso }
            return .distantPast
        }()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt.string(from: date)
    }

    private static var _tableDateFormatters: [DateFormatter] {
        var fmts: [DateFormatter] = []
        let f1 = DateFormatter(); f1.dateFormat = "yyyy-MM-dd HH:mm:ss"; fmts.append(f1)
        let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd"; fmts.append(f2)
        let f3 = DateFormatter(); f3.dateStyle = .medium; f3.timeStyle = .short; fmts.append(f3)
        let f4 = DateFormatter(); f4.dateStyle = .medium; f4.timeStyle = .none; fmts.append(f4)
        return fmts
    }

    private static let _tableISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}

struct PlatformTable: View {
    let rows: [PluginItem]
    let allPlugins: [PluginItem]  // ALL plugins for AI Suggestions
    @Binding var selection: [PluginItem]
    @Binding var sortStatus: String
    @Binding var showDetailPanel: Bool
    @Binding var detailPanelTab: DetailTab

    /// True while a scan is in progress. When false, the progress bar is hidden.
    @Binding var isScanning: Bool
    /// 0.0...1.0 progress for the current scan. Use any value outside this range for indeterminate.
    @Binding var scanProgress: Double

    /// Callback when plugins are deleted/uninstalled
    var onPluginsDeleted: (() -> Void)?

    #if os(macOS)
    private var macTable: some View {
        let _ = print("📊 [PlatformTable] Passing \(allPlugins.count) allPlugins to MacPluginTable")
        return MacPluginTable(
            rows: rows,
            allPlugins: allPlugins,
            selection: $selection,
            sortStatus: $sortStatus,
            showDetailPanel: $showDetailPanel,
            detailPanelTab: $detailPanelTab,
            onPluginsDeleted: onPluginsDeleted
        )
    }
    #endif

    init(
        rows: [PluginItem],
        allPlugins: [PluginItem] = [],  // Default to empty array
        selection: Binding<[PluginItem]>,
        sortStatus: Binding<String> = .constant(""),
        showDetailPanel: Binding<Bool> = .constant(false),
        detailPanelTab: Binding<DetailTab> = .constant(.metadata),
        isScanning: Binding<Bool> = .constant(false),
        scanProgress: Binding<Double> = .constant(0),
        onPluginsDeleted: (() -> Void)? = nil
    ) {
        self.rows = rows
        self.allPlugins = allPlugins
        self._selection = selection
        self._sortStatus = sortStatus
        self._showDetailPanel = showDetailPanel
        self._detailPanelTab = detailPanelTab
        self._isScanning = isScanning
        self._scanProgress = scanProgress
        self.onPluginsDeleted = onPluginsDeleted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            #if os(macOS)
            macTable
            #else
            List(rows, id: \.id) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name).font(.headline)
                        Spacer()
                        Text(item.type).foregroundStyle(.secondary).font(.subheadline)
                    }
                    HStack(spacing: 12) {
                        Text(item.publisher).foregroundStyle(.secondary)
                        Text(item.version).foregroundStyle(.secondary)
                        Text(item.preset).foregroundStyle(.secondary)
                    }.font(.footnote)
                    HStack(spacing: 12) {
                        Text(item.dateString).foregroundStyle(.secondary)
                        Text(item.sizeString).foregroundStyle(.secondary)
                        Text(item.runtimeRequirement).foregroundStyle(.secondary)
                        if item.obsolete { Text("Obsolete").foregroundStyle(.red) }
                    }.font(.footnote)
                    Text(item.path).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = [item] }
                #if canImport(UIKit)
                .contextMenu {
                    Button("Copy Path") {
                        UIPasteboard.general.string = i.path
                    }
                }
                #endif
            }
            #endif

            // Bottom-centered progress bar that appears while scanning
            if isScanning {
                Group {
                    if scanProgress.isFinite && scanProgress >= 0 && scanProgress <= 1 {
                        ProgressView(value: scanProgress) {
                            Text("Scanning…")
                        } currentValueLabel: {
                            Text(Int((scanProgress * 100).rounded()).formatted(.number))
                                .monospacedDigit()
                                .accessibilityHidden(true)
                        }
                    } else {
                        ProgressView("Scanning…")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityLabel("Scanning progress")
            }
        }
        .animation(.default, value: isScanning)
    }
}
