import SwiftUI
import Foundation


#if os(macOS)
import AppKit
#endif

// Helper to enable sorting on the Obsolete column (String is Comparable; Bool is not)
extension PluginItem {
    var obsoleteText: String { obsolete ? "Yes" : "No" }

    var versionSortKey: String {
        // Use a zero-padded numeric-aware key so 1.10 > 1.2
        let parts = version.split(separator: ".")
        return parts.map { part in
            // Keep numeric parts zero-padded, leave non-numeric as-is
            if let n = Int(part) {
                return String(format: "%05d", n)
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
        if let d = date { return d }

        // Fallback: parse from string only when needed
        let candidates: [DateFormatter] = Self._tableDateFormatters
        for fmt in candidates {
            if let d = fmt.date(from: dateString) { return d }
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
            for fmt in candidates { if let d = fmt.date(from: dateString) { return d } }
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
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return f
    }()
}

struct PlatformTable: View {
    let rows: [PluginItem]
    @Binding var selection: [PluginItem]
    @Binding var sortStatus: String

    /// True while a scan is in progress. When false, the progress bar is hidden.
    @Binding var isScanning: Bool
    /// 0.0...1.0 progress for the current scan. Use any value outside this range for indeterminate.
    @Binding var scanProgress: Double

    /// Callback when plugins are deleted/uninstalled
    var onPluginsDeleted: (() -> Void)? = nil

    #if os(macOS)
    private var macTable: some View {
        MacPluginTable(
            rows: rows,
            selection: $selection,
            sortStatus: $sortStatus,
            onPluginsDeleted: onPluginsDeleted
        )
    }
    #endif

    init(
        rows: [PluginItem],
        selection: Binding<[PluginItem]>,
        sortStatus: Binding<String> = .constant(""),
        isScanning: Binding<Bool> = .constant(false),
        scanProgress: Binding<Double> = .constant(0),
        onPluginsDeleted: (() -> Void)? = nil
    ) {
        self.rows = rows
        self._selection = selection
        self._sortStatus = sortStatus
        self._isScanning = isScanning
        self._scanProgress = scanProgress
        self.onPluginsDeleted = onPluginsDeleted
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            #if os(macOS)
            macTable
            #else
            List(rows, id: \.id) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(i.name).font(.headline)
                        Spacer()
                        Text(i.type).foregroundStyle(.secondary).font(.subheadline)
                    }
                    HStack(spacing: 12) {
                        Text(i.publisher).foregroundStyle(.secondary)
                        Text(i.version).foregroundStyle(.secondary)
                        Text(i.architectures).foregroundStyle(.secondary)
                    }.font(.footnote)
                    HStack(spacing: 12) {
                        Text(i.dateString).foregroundStyle(.secondary)
                        Text(i.sizeString).foregroundStyle(.secondary)
                        Text(i.runtimeRequirement).foregroundStyle(.secondary)
                        if i.obsolete { Text("Obsolete").foregroundStyle(.red) }
                    }.font(.footnote)
                    Text(i.path).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = [i] }
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

